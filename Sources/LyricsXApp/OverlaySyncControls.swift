import SwiftUI
import AppKit
import LyricsXCore

enum OverlayControlLayout {
    static let width: CGFloat = 166
    static let height: CGFloat = 34
    static let rightInset: CGFloat = 14
    static let topInset: CGFloat = 8
    static let headerReservation: CGFloat = width - 8
}

/// A control opened for one document cannot act on the next playback item.
struct OverlayOffsetTarget: Equatable {
    let trackRevision: UInt64
    let documentID: UUID
    @MainActor init?(session: LyricsSession) {
        guard session.track != nil, !session.documentIsPlaceholder, let document = session.document,
              document.isSynced, !document.isInstrumental else { return nil }
        trackRevision = session.trackRevision
        documentID = document.id
    }
    @MainActor func matches(_ session: LyricsSession) -> Bool {
        session.trackRevision == trackRevision && session.document?.id == documentID
            && session.document?.isSynced == true && !session.documentIsPlaceholder
            && session.document?.isInstrumental == false
    }
}

struct OverlayOffsetEditor: View {
    let model: AppModel
    let target: OverlayOffsetTarget
    var close: () -> Void = {}
    var width: CGFloat = 306
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("歌词同步").font(.headline)
                Spacer()
                Button(action: close) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).help("关闭歌词同步调节").keyboardShortcut(.cancelAction)
            }
            Text(String(format: "当前偏移 %+.1f 秒", Double(model.session.document?.offsetMilliseconds ?? 0) / 1000))
                .monospacedDigit().font(.callout)
                .contentTransition(.numericText())
                .animation(systemReduceMotion || model.preferences.reduceMotion ? nil : .easeInOut(duration: 0.18),
                    value: model.session.document?.offsetMilliseconds)
            HStack {
                Button("延后 0.1 秒") { adjust(-100) }
                Button("提前 0.1 秒") { adjust(100) }
                Spacer(minLength: 0)
                Button("重置") {
                    guard target.matches(model.session) else { return }
                    model.session.resetOffset()
                }
            }.controlSize(.small).disabled(!target.matches(model.session))
            Text("正值让歌词提前；只调整当前歌曲的歌词，不改变播放进度。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(24).frame(width: width, height: 156)
    }
    private func adjust(_ milliseconds: Int) {
        guard target.matches(model.session) else { return }
        model.session.adjustOffset(by: milliseconds)
    }
}

/// Match the lyric panel's native optical surface and continuous corners.
/// The editor sits outside that panel, so their refraction never stacks.
@MainActor final class OverlayOffsetSurface: NSView {
    private let background = NSVisualEffectView()
    private let shade = NSView()
    init(model: AppModel, target: OverlayOffsetTarget, size: NSSize, close: @escaping () -> Void) {
        super.init(frame: NSRect(origin: .zero, size: size))
        background.frame = bounds.insetBy(dx: 6, dy: 6)
        background.autoresizingMask = [.width, .height]
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerCurve = .continuous
        background.layer?.masksToBounds = true
        addSubview(background)
        shade.frame = background.bounds
        shade.autoresizingMask = [.width, .height]
        shade.wantsLayer = true
        background.addSubview(shade)
        let host = NSHostingView(rootView: OverlayThemedRoot(preferences: model.preferences,
            content: OverlayOffsetEditor(model: model, target: target, close: close, width: size.width - 12)))
        host.frame = bounds.insetBy(dx: 6, dy: 6)
        host.autoresizingMask = [.width, .height]
        addSubview(host)
        configure(model.preferences)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(_ preferences: Preferences) {
        // Interactive text needs a stable, blurred backdrop, independent of
        // the lyric window's experimental clear/refraction setting.
        let light = preferences.overlayEffectiveTheme.resolvedScheme == .light
        background.appearance = preferences.overlayEffectiveTheme.appearance
        background.layer?.cornerRadius = preferences.overlayAppearance == .glass ? 32 : 24
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        shade.layer?.backgroundColor = NSColor(white: light ? 0.94 : 0.12,
            alpha: reduced ? 1 : 0.65).cgColor
        background.layer?.borderColor = NSColor.white.withAlphaComponent(light ? 0.4 : 0.16).cgColor
        background.layer?.borderWidth = 0.5
    }
}

struct OverlayControlButtonStyle: ButtonStyle {
    let reducedMotion: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reducedMotion ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(reducedMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
