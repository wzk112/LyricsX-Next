import SwiftUI

struct OverlayTextSpacing: Codable, Equatable {
    var primaryLineSpacing = 0.0
    var translationLineSpacing = 0.0
    var automaticGaps = true
    var primaryGap = 12.0
    var secondaryGap = 8.0

    func normalized() -> Self {
        func clamp(_ value: Double, _ maximum: Double, fallback: Double = 0) -> Double {
            value.isFinite ? min(maximum, max(0, value)).rounded() : fallback
        }
        var result = self
        result.primaryLineSpacing = clamp(primaryLineSpacing, 24)
        result.translationLineSpacing = clamp(translationLineSpacing, 18)
        result.primaryGap = clamp(primaryGap, 40, fallback: 12)
        result.secondaryGap = clamp(secondaryGap, 32, fallback: 8)
        return result
    }
    static func load(_ data: Data?) -> Self {
        guard let data, let value = try? JSONDecoder().decode(Self.self, from: data) else { return .init() }
        return value.normalized()
    }
}

struct OverlayTextSpacingSettings: View {
    @Bindable var preferences: Preferences
    var body: some View {
        SettingSlider(title: "原文换行行距", detail: "仅调整悬浮窗原文换成两行时的间距；下一句预览按字号同比缩放。",
                      value: $preferences.overlayTextSpacing.primaryLineSpacing, range: 0...24)
        SettingSlider(title: "翻译换行行距", detail: "仅调整两行译文之间的间距，单行译文不增加留白。",
                      value: $preferences.overlayTextSpacing.translationLineSpacing, range: 0...18)
        SettingToggle(title: "段间距跟随字号", detail: "保持原来的自动间距。关闭后可单独调整下方两个段间距。",
                      value: $preferences.overlayTextSpacing.automaticGaps)
        SettingSlider(title: "原文与辅助行间距", detail: "原文与翻译或下一句之间的距离；自动高度下没有辅助内容时不留空。",
                      value: $preferences.overlayTextSpacing.primaryGap, range: 0...40)
            .disabled(preferences.overlayTextSpacing.automaticGaps)
        SettingSlider(title: "翻译与下一句间距", detail: "仅在同时显示翻译和下一句时生效。",
                      value: $preferences.overlayTextSpacing.secondaryGap, range: 0...32)
            .disabled(preferences.overlayTextSpacing.automaticGaps)
        SettingRow(title: "恢复默认间距", detail: "恢复默认行距和跟随字号的段间距，不改变字体、字号或歌词位置。") {
            Button("恢复默认间距") { preferences.overlayTextSpacing = .init() }
        }
    }
}
