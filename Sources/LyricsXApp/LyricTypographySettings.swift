import SwiftUI
import AppKit
import LyricsXCore

struct LyricTypographySettings: View {
    @Bindable var preferences: Preferences
    @State private var previewWidth = 460.0
    private static let fonts = NSFontManager.shared.availableFonts.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    private static let fontTitles = Dictionary(uniqueKeysWithValues: fonts.map { ($0, NSFont(name: $0, size: 13)?.displayName ?? $0) })
    private static let sample = LyricsDocument(lines: [
        .init(id: 0, time: 0, text: "让文字按你的习惯显示 · Your lyrics",
              translation: "字体与颜色会同时应用到主窗口和悬浮窗"),
        .init(id: 1, time: 10, text: "这是下一句的显示预览")])

    var body: some View {
        SettingsCard(title: "字体与颜色 · 实时预览") {
            SettingRow(title: "歌词字体", detail: "使用此 Mac 已安装的字体。保持设置字号，自动适配行高；原文、翻译和下一句的字号仍可分别设置。", impact: "缺少字符会使用系统后备字体；卸载所选字体后自动回退到系统字体。") {
                Picker("歌词字体", selection: $preferences.lyricFontName) {
                    Text("系统字体").tag("")
                    if !preferences.lyricFontName.isEmpty && !Self.fonts.contains(preferences.lyricFontName) {
                        Text("\(preferences.lyricFontName)（未安装）").tag(preferences.lyricFontName)
                    }
                    ForEach(Self.fonts, id: \.self) { name in
                        Text(Self.fontTitles[name] ?? name).tag(name)
                    }
                }.labelsHidden().frame(width: 220)
            }
            SettingToggle(title: "跟随封面主题色", detail: "从当前封面提取配色，并按界面深浅调整对比度。已唱、未唱和翻译保持区分。", impact: "无封面时使用中性配色。自动配色优先于手动配色；关闭即可恢复原来的颜色。复杂背景仍建议使用磨砂阅读。", value: $preferences.followArtworkColors)
            Label("玻璃悬浮窗中手动改色会关闭「自动优化歌词颜色」。重新开启仍保留手动颜色，供主窗口和磨砂阅读使用。跟随封面主题色开启时仍以封面配色为准。", systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16)
            if preferences.followArtworkColors {
                HStack(spacing: 12) {
                    ForEach(Array([preferences.artworkTheme?.accent ?? "BFC7D5", preferences.typography.primaryHex,
                             preferences.artworkTheme?.unsung ?? "757575"].enumerated()), id: \.offset) { item in
                        RoundedRectangle(cornerRadius: 8).fill(LyricTypography.color(item.element)).frame(width: 40, height: 30)
                    }
                    Text(preferences.artworkTheme == nil ? "等待封面 · 中性配色" : "封面主题 / 已唱 / 未唱")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(16)
                WordColorPreview(preferences: preferences).padding(16)
            }
            Group {
            SettingRow(title: "当前歌词颜色", detail: "逐字进度保留明暗变化，长音保留辉光。") {
                ColorPicker("当前歌词颜色", selection: Binding(get: { preferences.typography.primary }, set: {
                    preferences.setManualLyricColor(LyricTypography.hex($0), for: .primary)
                }), supportsOpacity: false).labelsHidden()
            }
            SettingRow(title: "翻译与下一句颜色", detail: "独立设置辅助文字颜色。", impact: "过暗的颜色可能在深色背景上难以阅读，可在下方预览检查。") {
                ColorPicker("辅助文字颜色", selection: Binding(get: { preferences.typography.secondary }, set: {
                    preferences.setManualLyricColor(LyricTypography.hex($0), for: .secondary)
                }), supportsOpacity: false).labelsHidden()
            }
            SettingRow(title: "逐字独立配色", detail: "分别设置已唱到和未唱到部分的颜色，同时用于主窗口和悬浮窗。", impact: "只对带逐字时间的当前歌词生效；关闭后恢复原来的明暗高亮。") {
                Toggle("逐字独立配色", isOn: $preferences.separateWordColors).labelsHidden()
            }
            }.disabled(preferences.followArtworkColors)
            if preferences.separateWordColors && !preferences.followArtworkColors {
                SettingRow(title: "已唱到的颜色", detail: "进度经过的文字，以及正在唱的文字中已高亮的部分。") {
                    ColorPicker("已唱到的颜色", selection: Binding(get: { LyricTypography.color(preferences.sungWordColor) }, set: {
                        preferences.setManualLyricColor(LyricTypography.hex($0), for: .sung)
                    }), supportsOpacity: false).labelsHidden()
                }
                SettingRow(title: "未唱到的颜色", detail: "当前句中尚未唱到的文字，不会再额外调暗。") {
                    ColorPicker("未唱到的颜色", selection: Binding(get: { LyricTypography.color(preferences.unsungWordColor) }, set: {
                        preferences.setManualLyricColor(LyricTypography.hex($0), for: .unsung)
                    }), supportsOpacity: false).labelsHidden()
                }
                WordColorPreview(preferences: preferences).padding(16)
            }
            GeometryReader { geometry in
                let width = max(200, geometry.size.width - 32)
                OverlayLyricsContent(preferences: preferences, document: Self.sample, index: 0,
                    lyricTime: { 2 }, playing: false, visible: true, adaptiveCanvasWidth: width)
                    .padding(16)
                    .onAppear { previewWidth = width }
                    .onChange(of: width) { _, value in previewWidth = value }
            }.frame(height: OverlayTextMeasure.height(document: Self.sample, index: 0,
                    preferences: preferences, maximumWidth: previewWidth + 60) - OverlayLayoutMetrics.chromeHeight + 32)
                .background(.black.opacity(0.85), in: .rect(cornerRadius: 18))
                .environment(\.colorScheme, .dark)
                .padding(16)
            HStack {
                Text("预览使用实际歌词绘制方式；修改后立即生效并保存。").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("恢复字体与颜色") {
                    preferences.lyricFontName = ""
                    preferences.lyricPrimaryColor = "FFFFFF"
                    preferences.lyricSecondaryColor = "FFFFFF"
                    preferences.followArtworkColors = false
                    preferences.separateWordColors = false
                    preferences.sungWordColor = "FFFFFF"
                    preferences.unsungWordColor = "757575"
                }
            }.padding(16)
        }
    }
}

private struct WordColorPreview: View {
    let preferences: Preferences
    @State private var visible = false
    @State private var anchor = ProcessInfo.processInfo.systemUptime
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let line = LyricLine(id: 0, time: 0, text: "逐字颜色 · Color preview", words: [
        .init(text: "逐字", start: 0, end: 1.5), .init(text: "颜色 · ", start: 1.5, end: 3),
        .init(text: "Color ", start: 3, end: 4.5), .init(text: "preview", start: 4.5, end: 6)])
    var body: some View {
        LyricRenderTimeline(running: visible && !reduceMotion && !preferences.reduceMotion, sampledTime: 2.2,
            preciseTime: { (ProcessInfo.processInfo.systemUptime - anchor).truncatingRemainder(dividingBy: 7) }) { time in
            WordHighlight(line: Self.line, time: time, active: true, text: Self.line.text,
                effects: .init(lift: false, glow: false, hdr: false))
                .environment(\.lyricWordColors, preferences.typography.wordColors)
                .font(preferences.typography.font(size: 26))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 90).padding(16)
                .background(.black.opacity(0.85), in: .rect(cornerRadius: 18))
                .environment(\.colorScheme, .dark)
        }
        .environment(\.lyricFrameRateLimit, 30)
        .onScrollVisibilityChange(threshold: 0.1) { visible = $0 }
        .onDisappear { visible = false }
        .accessibilityLabel("逐字配色动态预览")
    }
}
