import SwiftUI

/// This preference belongs to the main lyric list. The overlay positions its
/// visible text as a separate group and does not use this anchor.
enum MainLyricPosition: String, CaseIterable, Identifiable {
    case center, upper
    var id: String { rawValue }
    var title: String { self == .center ? "居中" : "上方" }
    var fraction: Double { self == .center ? 0.5 : 0.3 }
    var anchor: UnitPoint { .init(x: 0.5, y: fraction) }

    init(savedValue: String?) { self = Self(rawValue: savedValue ?? "") ?? .center }

    func insets(viewportHeight: Double) -> (top: Double, bottom: Double) {
        let height = viewportHeight.isFinite ? max(0, viewportHeight) : 0
        // Supply enough scroll range for the first and last rows too. Using
        // equal padding (or 38% on both ends) clamps an upper destination near
        // the last row, making it slide back down toward the bottom.
        return (height * fraction, height * (1 - fraction))
    }
}

struct MainLyricPositionSettings: View {
    @Bindable var preferences: Preferences
    var body: some View {
        SettingRow(title: "主窗口当前歌词位置", detail: "选择当前播放句在歌词区域中的位置；上方会留出更多空间预览后续歌词。仅影响主窗口。") {
            Picker("主窗口当前歌词位置", selection: $preferences.mainLyricPosition) {
                ForEach(MainLyricPosition.allCases) { Text($0.title).tag($0) }
            }.labelsHidden().frame(width: 110)
        }
    }
}
