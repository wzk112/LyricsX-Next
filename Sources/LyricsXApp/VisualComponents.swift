import SwiftUI
import LyricsXCore

struct AmbientBackground: View {
    var artwork: NSImage?
    var reduced = false
    @Environment(\.accessibilityReduceMotion) private var systemReduced
    @Environment(\.colorScheme) private var colorScheme
    @State private var backdrop: CGImage?
    @State private var renderedArtwork: ObjectIdentifier?
    var body: some View {
        GeometryReader { geometry in
            let key = artwork.map { AmbientArtworkKey(artwork: $0, size: geometry.size) }
            ZStack {
                LinearGradient(colors: colorScheme == .dark ? [Color(white: 0.12), Color(white: 0.045)] : [Color(white: 0.98), Color(white: 0.91)], startPoint: .topLeading, endPoint: .bottomTrailing)
                if let backdrop {
                    Image(decorative: backdrop, scale: 1).resizable().opacity(colorScheme == .dark ? 0.52 : 0.20)
                        .id(ObjectIdentifier(backdrop)).transition(.opacity)
                }
                LinearGradient(colors: colorScheme == .dark ? [.black.opacity(0.01), .black.opacity(0.18)] : [.white.opacity(0.06), .white.opacity(0.25)], startPoint: .top, endPoint: .bottom)
            }.clipped().task(id: key) {
                // Keep the previous pixels while metadata is temporarily missing
                // or the replacement blur is being prepared. Never flash a flat fill.
                if let artwork, let key,
                   let source = artwork.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    if renderedArtwork == ObjectIdentifier(artwork) {
                        do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                    }
                    let result = await AmbientArtworkRenderer.shared.render(source, key: key)
                    guard !Task.isCancelled, let result else { return }
                    withAnimation(reduced || systemReduced ? nil : .easeInOut(duration: 0.65)) { backdrop = result }
                    renderedArtwork = ObjectIdentifier(artwork)
                } else {
                    do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                    guard !Task.isCancelled else { return }
                    withAnimation(reduced || systemReduced ? nil : .easeInOut(duration: 0.65)) { backdrop = nil }
                    renderedArtwork = nil
                }
            }
        }.ignoresSafeArea().allowsHitTesting(false)
    }
}

struct ArtworkBlurTransition: ViewModifier {
    var blur: Double
    var opacity: Double
    func body(content: Content) -> some View { content.blur(radius: blur).opacity(opacity) }
}
extension AnyTransition {
    static var artworkBlur: AnyTransition {
        .modifier(active: ArtworkBlurTransition(blur: 7, opacity: 0), identity: ArtworkBlurTransition(blur: 0, opacity: 1))
    }
}

private struct CoverRequest: Equatable {
    let image: ObjectIdentifier?
    let animated: Bool
}
struct CoverArtwork: View {
    let artwork: NSImage?
    var demo = false
    var animated = false
    @Environment(\.accessibilityReduceMotion) private var systemReduced
    @State private var displayed: NSImage?
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size.width
            ZStack {
                if let image = animated ? displayed : artwork {
                    Image(nsImage: image).resizable().scaledToFill()
                        .id(ObjectIdentifier(image)).transition(animated && !systemReduced ? .artworkBlur : .identity)
                } else if demo {
                    LinearGradient(colors: [Color(red: 0.19, green: 0.10, blue: 0.24), Color(red: 0.55, green: 0.20, blue: 0.24), Color(red: 0.1, green: 0.09, blue: 0.21)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.74, blue: 0.48), Color(red: 0.97, green: 0.37, blue: 0.42)], startPoint: .top, endPoint: .bottom))
                        .frame(width: size * 0.44, height: size * 0.44).blur(radius: 0.5).offset(y: -size * 0.07)
                    ForEach(0..<18, id: \.self) { index in
                        Ellipse().stroke(.white.opacity(0.10), lineWidth: 0.5)
                            .frame(width: size * (0.65 + Double(index) * 0.07), height: size * (0.24 + Double(index) * 0.04))
                            .rotationEffect(.degrees(-22)).offset(x: size * 0.12, y: size * 0.12)
                    }
                    Rectangle().fill(LinearGradient(colors: [.clear, Color(red: 0.11, green: 0.09, blue: 0.2)], startPoint: .top, endPoint: .bottom)).frame(height: size * 0.7).offset(y: size * 0.33)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(demo ? "LYRICSX STUDIO" : "LYRICSX").font(.system(size: size * 0.027, weight: .medium, design: .monospaced)).tracking(2.6)
                            Spacer()
                            Image(systemName: "waveform").font(.system(size: size * 0.035))
                        }
                        Spacer()
                        Text(demo ? "夜航" : "声之所至").font(.system(size: size * 0.135, weight: .ultraLight)).tracking(8)
                        Text(demo ? "N I G H T F A L L" : "E V E R Y  W O R D").font(.system(size: size * 0.029, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                    }.padding(size * 0.085).frame(width: size, height: size).foregroundStyle(.white)
                } else {
                    Color(white: 0.13)
                    Image(systemName: "music.note").font(.system(size: size * 0.26, weight: .light)).foregroundStyle(.white.opacity(0.35))
                }
            }.frame(width: proxy.size.width, height: proxy.size.height).clipped()
                .clipShape(.rect(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.14), lineWidth: 0.7))
        }.aspectRatio(1, contentMode: .fit)
            .task(id: CoverRequest(image: artwork.map(ObjectIdentifier.init), animated: animated)) {
                guard animated else { displayed = artwork; return }
                if artwork == nil, displayed != nil {
                    do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                }
                guard !Task.isCancelled else { return }
                withAnimation(systemReduced ? nil : .timingCurve(0.22, 0, 0.18, 1, duration: 0.55)) { displayed = artwork }
            }
    }
}

// Only the active, word-timed row observes the playback position.
struct LiveLyricText: View {
    @Environment(\.lyricViewportVisible) private var viewportVisible
    let session: LyricsSession
    let line: LyricLine
    let document: LyricsDocument
    let active: Bool
    var rendering: () -> Bool = { true }
    let text: String
    var effects = LyricEmphasisOptions()
    var arrival: LyricLinePresentation?
    var body: some View {
        if line.hasWordTiming || arrival != nil {
            // Keep this view identity when a row becomes current. Only active
            // rows observe the session clock; others use the native draw path.
            let visible = active && viewportVisible && rendering()
            let time = active ? document.lyricTime(for: visible ? session.position : session.presentationPosition()) : 0
            LyricRenderTimeline(running: visible && session.isPlaying && LyricRenderTimelineActivity.needsFrames(line: line, time: time, arrival: arrival),
                                sampledTime: time, preciseTime: { document.lyricTime(for: session.presentationPosition()) },
                                continueFrames: { LyricRenderTimelineActivity.needsFrames(line: line,
                                    time: document.lyricTime(for: session.presentationPosition()), arrival: arrival) }) { frameTime in
                WordHighlight(line: line, time: frameTime, active: active, text: text, effects: effects, arrival: arrival)
                    .transaction { $0.animation = nil; $0.disablesAnimations = true }
            }
        } else { Text(text) }
    }
}

/// Only the currently drawn lyric gets display-rate updates. Sliders, artwork,
/// searching, and the session's line lookup keep their independent lower rate.
struct LyricRenderTimeline<Content: View>: View {
    let running: Bool
    let sampledTime: Double
    let preciseTime: () -> Double
    var continueFrames: () -> Bool = { true }
    @ViewBuilder let content: (Double) -> Content
    @State private var frameTarget: Double?

    var body: some View {
        let time = running
            ? DisplayFrameTime.sample(preciseTime(), target: frameTarget, now: ProcessInfo.processInfo.systemUptime)
            : sampledTime
        content(time)
            .background(LyricFrameSource(running: running && continueFrames()) { frameTarget = $0 }.frame(width: 0, height: 0))
            .onChange(of: running) { _, _ in frameTarget = nil }
    }
}

enum LyricRenderTimelineActivity {
    static func needsFrames(line: LyricLine, time: Double, arrival: LyricLinePresentation?) -> Bool {
        if line.words.contains(where: { $0.end > time && $0.start <= time + 0.1 }) { return true }
        return arrival.map { $0.stablePrefixCount < line.text.count && time < $0.start + $0.duration } ?? false
    }
}

struct SymbolButton: View {
    let symbol: String
    let help: String
    var active = false
    var inactiveOpacity = 0.6
    var ink: Color = .white
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 15, weight: .medium)).frame(width: 30, height: 30) }
            .buttonStyle(.plain).foregroundStyle(active ? ink : ink.opacity(inactiveOpacity))
            .background(active ? ink.opacity(0.1) : .clear, in: .circle)
            .contentShape(.circle).help(help).accessibilityLabel(help)
    }
}

struct PlayingIndicator: View {
    let playing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !playing || reduceMotion)) { context in
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<4) { index in
                    let value = barHeight(at: context.date, index: index)
                    Capsule().fill(.foreground).frame(width: 2.5, height: value)
                }
            }.frame(width: 20, height: 18)
        }.accessibilityLabel(playing ? "正在播放" : "已暂停")
    }
    private func barHeight(at date: Date, index: Int) -> Double {
        guard playing && !reduceMotion else { return 5.5 }
        let phase = date.timeIntervalSinceReferenceDate * 4 + Double(index) * 1.4
        return 4 + abs(sin(phase)) * 10
    }
}

func timeString(_ value: Double) -> String {
    let seconds = Int(max(0, value.isFinite ? value : 0))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}
