import SwiftUI
import LyricsXCore

private struct LyricViewportVisibleKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var lyricViewportVisible: Bool {
        get { self[LyricViewportVisibleKey.self] }
        set { self[LyricViewportVisibleKey.self] = newValue }
    }
}

/// A line change and a browsing/visibility callback can arrive together. Only
/// one of them should retarget the scroll, and a seek must not sweep through
/// unmaterialized lazy rows on its way to the destination.
struct MainLyricFollowState {
    struct Request: Equatable {
        let index: Int?
        let duration: Double?
    }
    private var initialized = false
    private var index: Int?

    mutating func request(index next: Int?, lines: [LyricLine], animated: Bool, force: Bool = false) -> Request? {
        guard force || !initialized || next != index else { return nil }
        let sequential = initialized && index != nil && next == index.map { $0 + 1 }
        initialized = true
        index = next
        let duration = animated && sequential && !force ? LyricMotion.followResponse(lines: lines, index: next) : nil
        return Request(index: next, duration: duration)
    }
}

/// Distant rows have the same visual state. Their numeric distance changing on
/// every cue must not start another blur animation for every cached lazy row.
struct MainLyricRowAppearance: Equatable {
    let active: Bool
    let scale: Double
    let blur: Double
    let primaryOpacity: Double
    let translationOpacity: Double

    init(index: Int, current: Int?, browsing: Bool, reduced: Bool) {
        active = index == current
        let distance = min(3, abs(index - (current ?? 0)))
        scale = active ? 1 : 0.96
        blur = reduced || browsing || active ? 0 : min(2.05, Double(distance) * 0.7)
        primaryOpacity = active ? 1 : browsing ? 0.55 : distance <= 1 ? 0.25 : 0.15
        translationOpacity = active ? 0.65 : 0.25
    }
}

struct MainLyricRowMotion: ViewModifier {
    let appearance: MainLyricRowAppearance
    let duration: Double
    let reduced: Bool
    @State private var onScreen = false

    func body(content: Content) -> some View {
        content
            .environment(\.lyricViewportVisible, onScreen)
            .scaleEffect(appearance.scale, anchor: .leading)
            .blur(radius: appearance.blur)
            .animation(reduced || !onScreen ? nil : .timingCurve(0.22, 0, 0.18, 1, duration: duration), value: appearance)
            .transaction { transaction in
                // ScrollPosition's animation belongs to the scroll offset,
                // not to a newly materialized row's size or initial placement.
                transaction.animation = nil
                if reduced || !onScreen { transaction.disablesAnimations = true }
            }
            .onScrollVisibilityChange(threshold: 0.01) { onScreen = $0 }
    }
}
