import SwiftUI

/// This preference belongs to the main lyric list. The overlay positions its
/// visible text as a separate group and does not use this anchor.
enum MainLyricPosition: String, CaseIterable, Identifiable {
    case center, upper, custom
    var id: String { rawValue }
    var title: String {
        switch self { case .center: "居中"; case .upper: "上方"; case .custom: "自定义" }
    }

    static let customRange: ClosedRange<Double> = 5...95
    static let defaultCustomPercent = 30.0
    static func normalizedPercent(_ value: Double) -> Double {
        guard value.isFinite else { return defaultCustomPercent }
        return min(customRange.upperBound, max(customRange.lowerBound, value)).rounded()
    }

    func placement(customPercent: Double = defaultCustomPercent) -> MainLyricPlacement {
        let fraction: Double
        switch self {
        case .center: fraction = 0.5
        case .upper: fraction = 0.3
        case .custom: fraction = Self.normalizedPercent(customPercent) / 100
        }
        return .init(fraction: fraction)
    }

    init(savedValue: String?) { self = Self(rawValue: savedValue ?? "") ?? .center }
}

/// One resolved geometry value drives the padding, scroll anchor and edge
/// fades. Changing a custom percentage therefore also retargets the same cue.
struct MainLyricPlacement: Equatable {
    let fraction: Double
    var anchor: UnitPoint { .init(x: 0.5, y: fraction) }
    var topFadeEnd: Double { min(0.13, fraction / 2) }
    var bottomFadeStart: Double { 1 - min(0.17, (1 - fraction) / 2) }

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
        SettingRow(title: "主窗口当前歌词位置", detail: "选择居中、上方（30%）或自定义位置。仅影响主窗口。") {
            Picker("主窗口当前歌词位置", selection: $preferences.mainLyricPosition) {
                ForEach(MainLyricPosition.allCases) { Text($0.title).tag($0) }
            }.labelsHidden().frame(width: 110)
        }
        if preferences.mainLyricPosition == .custom {
            SettingRow(title: "距歌词区域顶部", detail: "5%–95%，数值越小越靠上。调整后立即保存；切回预设仍会保留此数值。") {
                HStack(spacing: 8) {
                    Slider(value: $preferences.mainLyricCustomPercent, in: MainLyricPosition.customRange, step: 1)
                        .accessibilityLabel("当前歌词位置百分比").frame(width: 120)
                    TextField("百分比", value: $preferences.mainLyricCustomPercent,
                              format: .number.precision(.fractionLength(0)))
                        .textFieldStyle(.roundedBorder).frame(width: 48)
                        .accessibilityLabel("当前歌词位置数值")
                    Text("%").foregroundStyle(.secondary)
                }
            }
        }
    }
}
