import AppKit
import Accelerate
import CoreAudio
import AudioToolbox
import QuartzCore

/// The waveform owns its own native surface and clock. It never publishes audio
/// frames into the lyric session, observation graph, or window sizing loop.
enum OverlayWaveformStyle: String, CaseIterable, Identifiable {
    case monochrome, artwork
    var id: String { rawValue }
    var title: String { self == .monochrome ? "白色" : "封面彩色" }
}

enum OverlayWaveformLayout {
    static let additionalHeight: CGFloat = 24
    static let reclaimedContentHeight: CGFloat = 22
    static func contentHeight(base: CGFloat, enabled: Bool) -> CGFloat {
        enabled ? max(0, base - reclaimedContentHeight) : base
    }
    static func totalHeight(content: CGFloat, enabled: Bool) -> CGFloat {
        contentHeight(base: content, enabled: enabled) + (enabled ? additionalHeight : 0)
    }
}

enum OverlayWaveformGeometry {
    static func baseline(height: CGFloat) -> CGFloat { min(2.5, max(0, height / 2)) }
    static func amplitude(for band: Float, height: CGFloat) -> CGFloat {
        // The 18pt surface starts at the glass inset (y=6). Reserve room for
        // the backing stroke and its antialiasing at either extreme.
        let ceiling = max(0, height - baseline(height: height) - 1.5)
        return min(ceiling, sqrt(max(0, CGFloat(band))) * 17)
    }

    static func points(for bands: [Float], width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard !bands.isEmpty, width > 8, height > 0 else { return [] }
        let inset: CGFloat = 4
        let step = (width - inset * 2) / CGFloat(max(1, bands.count - 1))
        return bands.indices.map { index in
            CGPoint(x: inset + CGFloat(index) * step,
                    y: baseline(height: height) + amplitude(for: bands[index], height: height))
        }
    }
}

enum OverlayWaveformEdgeFade {
    static let clearEdge: CGFloat = 5
    // Five fixed stops approximate smoothstep without redrawing the mask on
    // audio/display ticks. Both sides use identical opacity in reverse.
    static let alphas: [CGFloat] = [0, 0, 0.15625, 0.5, 0.84375, 1,
                                   1, 0.84375, 0.5, 0.15625, 0, 0]
    static func fadeWidth(width: CGFloat) -> CGFloat {
        guard width > 10 else { return 0 }
        return min(min(80, max(32, width * 0.10)), (width - 10) * 0.2)
    }
    static func locations(width: CGFloat) -> [NSNumber] {
        guard width > 0 else { return Array(repeating: 0, count: 6) + Array(repeating: 1, count: 6) }
        let clear = min(clearEdge, width / 2)
        let fade = fadeWidth(width: width)
        let left: [CGFloat] = [0, clear, clear + fade * 0.25,
            clear + fade * 0.5, clear + fade * 0.75, clear + fade]
        return (left + left.reversed().map { width - $0 }).map { NSNumber(value: Double($0 / width)) }
    }
}

enum OverlayWaveformCaptureGate {
    static func allows(enabled: Bool, visible: Bool, playing: Bool,
                       reducedMotion: Bool, bundleID: String?) -> Bool {
        enabled && visible && playing && !reducedMotion && !(bundleID ?? "").isEmpty
    }
}

enum WaveformCaptureFailure: Equatable {
    case setup
    case noPCM
}

/// A silent player can recover at a discrete playback boundary. Permission
/// and device setup failures stay blocked until the user retries or toggles
/// the feature, so observation updates cannot repeatedly prompt for access.
struct WaveformRetryPolicy {
    private var blockedSource: String?
    private var failure: WaveformCaptureFailure?
    private var previousPlaying = false
    private var previousSource: String?
    private var previousTrackRevision: UInt64?

    mutating func observe(enabled: Bool, playing: Bool, source: String?, trackRevision: UInt64 = 0) {
        if !enabled { clear() }
        else if failure == .noPCM,
                (playing && !previousPlaying || source != previousSource
                    || trackRevision != previousTrackRevision) { clear() }
        previousPlaying = playing
        previousSource = source
        previousTrackRevision = trackRevision
    }
    mutating func failed(source: String?, reason: WaveformCaptureFailure) {
        blockedSource = source
        failure = reason
    }
    mutating func wake() { if failure == .noPCM { clear() } }
    mutating func manualRetry() { clear() }
    func allows(source: String?) -> Bool {
        if failure == .setup { return false }
        return blockedSource != source || failure == nil
    }
    private mutating func clear() { blockedSource = nil; failure = nil }
}

/// A fixed-size, lossy transfer from the Core Audio callback to the UI clock.
/// try() is deliberate: the real-time callback must never wait for rendering.
final class WaveformSampleRing: @unchecked Sendable {
    private let lock = NSLock()
    private var left = [Float](repeating: 0, count: 8192)
    private var right = [Float](repeating: 0, count: 8192)
    private var head = 0
    private var count = 0
    private var writes: UInt64 = 0
    func appendInterleaved(_ pointer: UnsafePointer<Float>, frames: Int) {
        guard lock.try() else { return }
        defer { lock.unlock() }
        for index in 0..<frames {
            left[head] = pointer[index * 2]
            right[head] = pointer[index * 2 + 1]
            head = (head + 1) % left.count
            count = min(left.count, count + 1)
        }
        writes &+= UInt64(frames)
    }
    func appendPlanar(_ leftPointer: UnsafePointer<Float>, _ rightPointer: UnsafePointer<Float>, frames: Int) {
        guard lock.try() else { return }
        defer { lock.unlock() }
        for index in 0..<frames {
            left[head] = leftPointer[index]
            right[head] = rightPointer[index]
            head = (head + 1) % left.count
            count = min(left.count, count + 1)
        }
        writes &+= UInt64(frames)
    }
    func latest(_ length: Int) -> (left: [Float], right: [Float], writes: UInt64)? {
        lock.lock()
        defer { lock.unlock() }
        guard count >= length else { return nil }
        let start = (head - length + left.count) % left.count
        return ((0..<length).map { left[(start + $0) % left.count] },
            (0..<length).map { right[(start + $0) % right.count] }, writes)
    }
    #if DEBUG
    func totalWrites() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        return writes
    }
    #endif
}

/// One 2048-sample Hann/DFT analysis every ~16 ms. Logarithmic bands make
/// bass, voice, and high harmonics visible without tracking any lyric state.
final class WaveformSpectrumAnalyzer {
    static let sampleCount = 2048
    static let bandCount = 24
    private let setup: vDSP_DFT_Setup?
    private let window: [Float]
    init() {
        setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(Self.sampleCount), .FORWARD)
        window = (0..<Self.sampleCount).map { index in
            Float(0.5 - 0.5 * cos(2 * .pi * Double(index) / Double(Self.sampleCount - 1)))
        }
    }
    deinit { if let setup { vDSP_DFT_DestroySetup(setup) } }
    func bands(left: [Float], right: [Float], sampleRate: Double) -> [Float] {
        guard let setup, left.count == Self.sampleCount, right.count == Self.sampleCount, sampleRate > 0 else {
            return [Float](repeating: 0, count: Self.bandCount)
        }
        let imaginary = [Float](repeating: 0, count: Self.sampleCount)
        func transform(_ samples: [Float]) -> ([Float], [Float]) {
            var input = [Float](repeating: 0, count: Self.sampleCount)
            vDSP_vmul(samples, 1, window, 1, &input, 1, vDSP_Length(Self.sampleCount))
            var real = [Float](repeating: 0, count: Self.sampleCount)
            var imaginaryOutput = [Float](repeating: 0, count: Self.sampleCount)
            vDSP_DFT_Execute(setup, input, imaginary, &real, &imaginaryOutput)
            return (real, imaginaryOutput)
        }
        let (leftReal, leftImaginary) = transform(left)
        let (rightReal, rightImaginary) = transform(right)
        let nyquist = sampleRate / 2
        return (0..<Self.bandCount).map { band in
            let lower = 45.0 * pow(13_000.0 / 45.0, Double(band) / Double(Self.bandCount))
            let upper = 45.0 * pow(13_000.0 / 45.0, Double(band + 1) / Double(Self.bandCount))
            let first = max(1, min(Self.sampleCount / 2 - 1, Int(lower * Double(Self.sampleCount) / sampleRate)))
            let last = max(first, min(Self.sampleCount / 2 - 1, Int(min(upper, nyquist) * Double(Self.sampleCount) / sampleRate)))
            let peak = (first...last).reduce(Float(0)) { result, index in
                let l = hypot(leftReal[index], leftImaginary[index])
                let r = hypot(rightReal[index], rightImaginary[index])
                return max(result, hypot(l, r) * 0.70710678)
            }
            // Stable logarithmic compression; silence remains exactly zero.
            return min(1, log1p(peak / 10) / 4)
        }
    }
}

/// A private, unmuted tap scoped to one player's bundle ID. Any failure leaves
/// the waveform silent; there is deliberately no system-wide fallback.
final class PlayerAudioWaveformTap {
    let bundleID: String
    let ring: WaveformSampleRing
    private(set) var sampleRate: Double = 48_000
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var started = false
    init(bundleID: String, ring: WaveformSampleRing) {
        self.bundleID = bundleID; self.ring = ring
    }
    func start() -> Bool {
        guard !bundleID.isEmpty else { return false }
        let description = CATapDescription()
        description.name = "LyricsX Next Current Player Waveform"
        description.bundleIDs = [bundleID]
        description.isExclusive = false
        description.isPrivate = true
        description.muteBehavior = .unmuted
        description.isMixdown = true
        description.isMono = false
        description.isProcessRestoreEnabled = true
        guard AudioHardwareCreateProcessTap(description, &tapID) == noErr else { return false }
        defer { if !started { stop() } }
        var uidAddress = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var tapUID: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.stride)
        guard withUnsafeMutablePointer(to: &tapUID, {
            AudioObjectGetPropertyData(tapID, &uidAddress, 0, nil, &uidSize, $0)
        }) == noErr else { return false }
        var address = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format) == noErr,
              format.mFormatID == kAudioFormatLinearPCM,
              format.mBitsPerChannel == 32,
              format.mChannelsPerFrame == 2,
              format.mFormatFlags & kAudioFormatFlagIsFloat != 0 else { return false }
        sampleRate = format.mSampleRate
        let properties: [String: Any] = [
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceNameKey: "LyricsX Next Waveform",
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: tapUID]]
        ]
        guard AudioHardwareCreateAggregateDevice(properties as CFDictionary, &aggregateID) == noErr else { return false }
        // The sole input stream must preserve the tap's stereo Float32 layout.
        // Reject an unexpected aggregate format instead of decoding arbitrary
        // device bytes as floats in the real-time callback.
        var streamsAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        var streamsSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(aggregateID, &streamsAddress, 0, nil, &streamsSize) == noErr,
              streamsSize >= UInt32(MemoryLayout<AudioObjectID>.size) else { return false }
        var streams = [AudioObjectID](repeating: kAudioObjectUnknown,
            count: Int(streamsSize) / MemoryLayout<AudioObjectID>.size)
        let streamsStatus = streams.withUnsafeMutableBufferPointer { pointer in
            AudioObjectGetPropertyData(aggregateID, &streamsAddress, 0, nil, &streamsSize, pointer.baseAddress!)
        }
        guard streamsStatus == noErr, let streamID = streams.first else { return false }
        var streamAddress = AudioObjectPropertyAddress(mSelector: kAudioStreamPropertyVirtualFormat,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var streamFormat = AudioStreamBasicDescription()
        var streamSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioObjectGetPropertyData(streamID, &streamAddress, 0, nil, &streamSize, &streamFormat) == noErr,
              streamFormat.mFormatID == kAudioFormatLinearPCM,
              streamFormat.mBitsPerChannel == 32,
              streamFormat.mChannelsPerFrame == 2,
              streamFormat.mFormatFlags & kAudioFormatFlagIsFloat != 0 else { return false }
        sampleRate = streamFormat.mSampleRate
        let sampleRing = ring
        let planar = streamFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
        guard AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, nil, { _, input, _, _, _ in
            let list = input.pointee
            if planar {
                guard list.mNumberBuffers == 2 else { return }
                let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
                let first = buffers[0], second = buffers[1]
                guard first.mNumberChannels == 1, second.mNumberChannels == 1,
                      let a = first.mData, let b = second.mData else { return }
                let count = min(Int(first.mDataByteSize), Int(second.mDataByteSize)) / MemoryLayout<Float>.size
                sampleRing.appendPlanar(a.assumingMemoryBound(to: Float.self),
                    b.assumingMemoryBound(to: Float.self), frames: count)
            } else {
                guard list.mNumberBuffers == 1 else { return }
                let buffer = list.mBuffers
                guard buffer.mNumberChannels == 2, let data = buffer.mData else { return }
                let count = Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * 2)
                sampleRing.appendInterleaved(data.assumingMemoryBound(to: Float.self), frames: count)
            }
        }) == noErr else { return false }
        guard AudioDeviceStart(aggregateID, ioProcID) == noErr else { return false }
        started = true
        return true
    }
    func stop() {
        if started, let ioProcID { AudioDeviceStop(aggregateID, ioProcID) }
        started = false
        if let ioProcID { AudioDeviceDestroyIOProcID(aggregateID, ioProcID); self.ioProcID = nil }
        if aggregateID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregateID); aggregateID = kAudioObjectUnknown }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID); tapID = kAudioObjectUnknown }
    }
    deinit { stop() }
}

/// All Core Audio lifecycle operations and FFT work run on this one queue.
/// The main thread only takes a 24-value snapshot; the audio callback only
/// appends to its preallocated ring and never waits for analysis.
final class WaveformCaptureWorker: @unchecked Sendable {
    enum State: Equatable { case starting, live, unavailable(WaveformCaptureFailure) }
    private let queue = DispatchQueue(label: "LyricsX.WaveformAnalysis", qos: .utility)
    private let lock = NSLock()
    private let bundleID: String
    private let ring = WaveformSampleRing()
    private var analyzer: WaveformSpectrumAnalyzer?
    private var tap: PlayerAudioWaveformTap?
    private var timer: DispatchSourceTimer?
    private var latest = [Float](repeating: 0, count: WaveformSpectrumAnalyzer.bandCount)
    private var state: State = .starting
    private var cancelled = false
    private var lastPCMTime = 0.0
    private var lastWrites: UInt64 = 0
    #if DEBUG
    private let diagnosticsEnabled = ProcessInfo.processInfo.environment["LYRICSX_WAVEFORM_DIAGNOSTICS"] == "1"
    private var lastDiagnosticTime = 0.0
    private var diagnosticPeak: Float = 0
    private var diagnosticBandMax: Float = 0
    private var diagnosticPreviousWrites: UInt64 = 0
    #endif
    init(bundleID: String) { self.bundleID = bundleID }
    func start() {
        queue.async { [self] in
            guard !isCancelled else { return }
            let newTap = PlayerAudioWaveformTap(bundleID: bundleID, ring: ring)
            guard newTap.start(), !isCancelled else {
                newTap.stop(); setState(.unavailable(.setup)); return
            }
            tap = newTap
            analyzer = WaveformSpectrumAnalyzer()
            lastPCMTime = ProcessInfo.processInfo.systemUptime
            #if DEBUG
            lastDiagnosticTime = lastPCMTime
            #endif
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(3))
            timer.setEventHandler { [self] in analyze() }
            self.timer = timer
            timer.resume()
        }
    }
    func stop() {
        lock.lock(); cancelled = true; lock.unlock()
        queue.async { [self] in
            timer?.cancel(); timer = nil
            tap?.stop(); tap = nil
            analyzer = nil
        }
    }
    func snapshot() -> (State, [Float]) {
        lock.lock(); defer { lock.unlock() }
        return (state, latest)
    }
    private var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }
    private func setState(_ newState: State, bands: [Float]? = nil) {
        lock.lock()
        state = newState
        if let bands { latest = bands }
        lock.unlock()
    }
    private func analyze() {
        guard !isCancelled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let frame = ring.latest(WaveformSpectrumAnalyzer.sampleCount),
           frame.writes != lastWrites, let tap, let analyzer {
            lastWrites = frame.writes
            lastPCMTime = now
            let bands = analyzer.bands(left: frame.left, right: frame.right, sampleRate: tap.sampleRate)
            setState(.live, bands: bands)
            #if DEBUG
            if diagnosticsEnabled {
                let leftPeak = frame.left.reduce(Float(0)) { max($0, abs($1)) }
                let rightPeak = frame.right.reduce(Float(0)) { max($0, abs($1)) }
                diagnosticPeak = max(diagnosticPeak, max(leftPeak, rightPeak))
                diagnosticBandMax = max(diagnosticBandMax, bands.max() ?? 0)
            }
            #endif
        } else if now - lastPCMTime > 3 {
            timer?.cancel(); timer = nil
            tap?.stop(); tap = nil
            analyzer = nil
            setState(.unavailable(.noPCM))
        }
        #if DEBUG
        if diagnosticsEnabled && now - lastDiagnosticTime >= 1 {
            let writes = ring.totalWrites()
            NSLog("LyricsX waveform diagnostic writes=\(writes) deltaWrites=\(writes &- diagnosticPreviousWrites) samplePeak=\(String(format: "%.7f", Double(diagnosticPeak))) bandMax=\(String(format: "%.5f", Double(diagnosticBandMax)))")
            diagnosticPreviousWrites = writes
            diagnosticPeak = 0
            diagnosticBandMax = 0
            lastDiagnosticTime = now
        }
        #endif
    }
}

@MainActor
final class OverlayWaveformView: NSView {
    private let spectrumContainer = CALayer()
    private let edgeMask = CAGradientLayer()
    private let underlay = CAShapeLayer()
    private let stroke = CAShapeLayer()
    private let gradient = CAGradientLayer()
    private let gradientMask = CAShapeLayer()
    private let clock = LyricFrameView(frame: .zero)
    private var smoothed = [Float](repeating: 0, count: WaveformSpectrumAnalyzer.bandCount)
    private var drawnBands: [Float]?
    private var drawnSize = CGSize.zero
    private var drawnStyle: OverlayWaveformStyle?
    private var worker: WaveformCaptureWorker?
    private var sourceID: String?
    private var lastFrame = 0.0
    private var isActive = false
    private var startedAt = 0.0
    private var retryPolicy = WaveformRetryPolicy()
    private var lastReportedState: WaveformCaptureWorker.State?
    var onStatusChange: ((String) -> Void)?
    private var style: OverlayWaveformStyle = .monochrome
    private var lightGlass = false
    private var theme: ArtworkTheme = .neutral
    private var maskSize = CGSize.zero
    #if DEBUG
    private let viewDiagnosticsEnabled = ProcessInfo.processInfo.environment["LYRICSX_WAVEFORM_DIAGNOSTICS"] == "1"
    private var viewDiagnosticTimer: Timer?
    private var displayTicks = 0
    #endif
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        edgeMask.colors = OverlayWaveformEdgeFade.alphas.map {
            NSColor.black.withAlphaComponent($0).cgColor
        }
        edgeMask.startPoint = CGPoint(x: 0, y: 0.5)
        edgeMask.endPoint = CGPoint(x: 1, y: 0.5)
        spectrumContainer.mask = edgeMask
        underlay.fillColor = NSColor.clear.cgColor
        underlay.strokeColor = NSColor.black.withAlphaComponent(0.2).cgColor
        underlay.lineWidth = 1.6
        stroke.fillColor = NSColor.clear.cgColor
        stroke.strokeColor = NSColor.white.cgColor
        stroke.lineWidth = 1.5
        gradientMask.fillColor = NSColor.clear.cgColor
        gradientMask.strokeColor = NSColor.white.cgColor
        gradientMask.lineWidth = 1.6
        gradient.mask = gradientMask
        layer?.addSublayer(spectrumContainer)
        spectrumContainer.addSublayer(underlay)
        spectrumContainer.addSublayer(stroke)
        spectrumContainer.addSublayer(gradient)
        clock.frameCallback = { [weak self] time in self?.tick(at: time) }
        addSubview(clock)
        isHidden = true
    }
    /// Stop capture at fade start while the compositor keeps the last path
    /// visible for the few remaining frames of the window transition.
    func freezeVisualForFade(enabled: Bool, playing: Bool, source: String?, trackRevision: UInt64) {
        retryPolicy.observe(enabled: enabled, playing: playing, source: source,
            trackRevision: trackRevision)
        guard isActive || worker != nil || clock.running else { return }
        isActive = false; sourceID = nil
        clock.running = false
        worker?.stop(); worker = nil
        lastFrame = 0
        #if DEBUG
        viewDiagnosticTimer?.invalidate(); viewDiagnosticTimer = nil
        displayTicks = 0
        #endif
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        spectrumContainer.frame = bounds
        for shape in [underlay, stroke, gradient, gradientMask] { shape.frame = bounds }
        if maskSize != bounds.size {
            maskSize = bounds.size
            edgeMask.frame = bounds
            edgeMask.locations = OverlayWaveformEdgeFade.locations(width: bounds.width)
        }
        CATransaction.commit()
        drawBands()
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    func configure(enabled: Bool, visible: Bool, playing: Bool, reducedMotion: Bool,
                   bundleID: String?, style: OverlayWaveformStyle, lightGlass: Bool,
                   theme: ArtworkTheme?, frameRateLimit: Int, trackRevision: UInt64 = 0) {
        let newTheme = theme ?? .neutral
        let paletteChanged = self.style != style || self.lightGlass != lightGlass || self.theme != newTheme
        self.style = style; self.lightGlass = lightGlass; self.theme = newTheme
        if paletteChanged { updatePalette() }
        clock.frameRateLimit = frameRateLimit
        let eligible = OverlayWaveformCaptureGate.allows(enabled: enabled, visible: visible,
            playing: playing, reducedMotion: reducedMotion, bundleID: bundleID)
        retryPolicy.observe(enabled: enabled, playing: playing, source: bundleID,
            trackRevision: trackRevision)
        if !eligible {
            stop()
            return
        }
        guard retryPolicy.allows(source: bundleID) else { return }
        isHidden = false
        drawBands()
        if !isActive || sourceID != bundleID {
            stop()
            isHidden = false
            isActive = true
            startedAt = ProcessInfo.processInfo.systemUptime
            sourceID = bundleID
            let worker = WaveformCaptureWorker(bundleID: bundleID!)
            self.worker = worker
            onStatusChange?("正在连接当前播放器音频…")
            lastReportedState = .starting
            #if DEBUG
            startViewDiagnostics()
            #endif
            worker.start()
            clock.running = true
        }
    }
    func stop() {
        #if DEBUG
        viewDiagnosticTimer?.invalidate(); viewDiagnosticTimer = nil
        displayTicks = 0
        #endif
        guard isActive || worker != nil || clock.running else { isHidden = true; return }
        isActive = false; sourceID = nil
        clock.running = false
        worker?.stop(); worker = nil
        smoothed = [Float](repeating: 0, count: WaveformSpectrumAnalyzer.bandCount)
        lastFrame = 0
        isHidden = true
    }
    func retry() {
        retryPolicy.manualRetry()
        stop()
    }
    func wakeForRecovery() { retryPolicy.wake() }
    private func tick(at time: Double) {
        #if DEBUG
        displayTicks += 1
        #endif
        guard isActive else { return }
        let (state, measured) = worker?.snapshot() ?? (.unavailable(.setup), [])
        if state == .starting && time - startedAt > 10 {
            retryPolicy.failed(source: sourceID, reason: .setup)
            stop()
            onStatusChange?("音频采集未开始；请检查系统音频录制权限后重试。")
            return
        }
        if case .unavailable(let reason) = state {
            retryPolicy.failed(source: sourceID, reason: reason)
            stop()
            onStatusChange?(reason == .noPCM
                ? "当前播放器暂时没有可捕获音频；播放恢复、切歌或唤醒时会重试。"
                : "音频采集未获准或设备创建失败；请检查权限后重试。")
            return
        }
        let delta = lastFrame > 0 ? max(0, min(0.1, time - lastFrame)) : 1.0 / 60
        lastFrame = time
        if state == .live, lastReportedState != .live {
            onStatusChange?(""); lastReportedState = .live
        }
        for index in smoothed.indices {
            let target = state == .live ? measured[index] : 0
            let tau = target > smoothed[index] ? 0.075 : 0.22
            let factor = Float(1 - exp(-delta / tau))
            smoothed[index] += (target - smoothed[index]) * factor
        }
        drawBands()
    }
    #if DEBUG
    private func startViewDiagnostics() {
        guard viewDiagnosticsEnabled, viewDiagnosticTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reportViewDiagnostics() }
        }
        viewDiagnosticTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func reportViewDiagnostics() {
        let state: String
        switch worker?.snapshot().0 {
        case .starting: state = "starting"
        case .live: state = "live"
        case .unavailable(.setup): state = "setup-failed"
        case .unavailable(.noPCM): state = "no-pcm"
        case nil: state = "none"
        }
        let peak = smoothed.max() ?? 0
        NSLog("LyricsX waveform view ticks=\(displayTicks) state=\(state) smoothedMax=\(String(format: "%.5f", Double(peak))) hidden=\(isHidden) windowVisible=\(window?.isVisible == true) frame=\(NSStringFromRect(frame)) clockDelivering=\(clock.deliveringFrames) requestedFPS=\(clock.requestedFrameRate)")
        displayTicks = 0
    }
    #endif
    private func drawBands() {
        // Capture/status delivery continues during silence; identical pixels
        // do not need a new path or three compositor layer updates.
        guard drawnBands != smoothed || drawnSize != bounds.size || drawnStyle != style else { return }
        let points = OverlayWaveformGeometry.points(for: smoothed,
            width: bounds.width, height: bounds.height)
        guard !points.isEmpty else { return }
        drawnBands = smoothed
        drawnSize = bounds.size
        drawnStyle = style
        // The bands are ordered low to high frequency, left to right. The
        // curve has one contour; silence remains a fixed horizontal baseline.
        func appendContour(_ points: [CGPoint], to path: CGMutablePath) {
            guard let first = points.first, let last = points.last else { return }
            path.move(to: first)
            for index in 1..<points.count {
                let previous = points[index - 1], current = points[index]
                let midpoint = CGPoint(x: (previous.x + current.x) / 2,
                    y: (previous.y + current.y) / 2)
                path.addQuadCurve(to: midpoint, control: previous)
            }
            path.addQuadCurve(to: last, control: last)
        }
        let contour = CGMutablePath()
        appendContour(points, to: contour)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        underlay.path = contour; stroke.path = contour; gradientMask.path = contour
        // The backing shares precisely the same path as the white/color ink.
        underlay.isHidden = false
        stroke.isHidden = style != .monochrome
        gradient.isHidden = style != .artwork
        CATransaction.commit()
    }
    private func updatePalette() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        // Matching widths keep the backing and white ink one visible stroke
        // on bright glass instead of two dark rails around a white center.
        let edgeAlpha: CGFloat = lightGlass ? (style == .monochrome ? 0.56 : 0.26) : 0.14
        underlay.strokeColor = NSColor.black.withAlphaComponent(edgeAlpha).cgColor
        stroke.strokeColor = NSColor.white.withAlphaComponent(
            lightGlass && style == .monochrome ? 0.55 : 1).cgColor
        gradient.colors = theme.waveformColors.map { Self.color($0).cgColor }
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        CATransaction.commit()
    }
    private static func color(_ hex: String) -> NSColor {
        guard let number = UInt32(hex, radix: 16) else { return .white }
        return NSColor(calibratedRed: CGFloat((number >> 16) & 255) / 255,
            green: CGFloat((number >> 8) & 255) / 255, blue: CGFloat(number & 255) / 255, alpha: 1)
    }
    #if DEBUG
    /// Native visual QA only; never substitutes generated data for live audio.
    func injectTestBands(_ bands: [Float], style: OverlayWaveformStyle, lightGlass: Bool, theme: ArtworkTheme) {
        stop()
        self.style = style; self.lightGlass = lightGlass; self.theme = theme
        updatePalette()
        smoothed = Array(bands.prefix(WaveformSpectrumAnalyzer.bandCount))
        smoothed += [Float](repeating: 0, count: max(0, WaveformSpectrumAnalyzer.bandCount - smoothed.count))
        isHidden = false
        drawBands()
    }
    #endif
}
