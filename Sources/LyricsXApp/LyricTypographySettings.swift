import SwiftUI
import AppKit
import LyricsXCore

struct LyricTypographySettings: View {
    @Bindable var preferences: Preferences
    @State private var previewWidth = 460.0
    private static let fonts = NSFontManager.shared.availableFonts.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    private static let sample = LyricsDocument(lines: [
        .init(id: 0, time: 0, text: "让文字按你的习惯显示 · Your lyrics",
              translation: "字体与颜色会同时应用到主窗口和悬浮窗"),
        .init(id: 1, time: 10, text: "这是下一句的显示预览")])

    var body: some View {
        SettingsCard(title: "字体与颜色 · 实时预览") {
            SettingRow(title: "歌词字体", detail: "使用此 Mac 已安装的字体。原文、翻译和下一句共用字体，字号仍可分别设置。", impact: "缺少字符会使用系统后备字体；卸载所选字体后自动回退到系统字体。") {
                Picker("歌词字体", selection: $preferences.lyricFontName) {
                    Text("系统字体").tag("")
                    if !preferences.lyricFontName.isEmpty && !Self.fonts.contains(preferences.lyricFontName) {
                        Text("\(preferences.lyricFontName)（未安装）").tag(preferences.lyricFontName)
                    }
                    ForEach(Self.fonts, id: \.self) { name in
                        Text(NSFont(name: name, size: 13)?.displayName ?? name).tag(name)
                    }
                }.labelsHidden().frame(width: 220)
            }
            SettingRow(title: "当前歌词颜色", detail: "逐字进度保留明暗变化，长音保留辉光。") {
                ColorPicker("当前歌词颜色", selection: Binding(get: { preferences.typography.primary }, set: {
                    preferences.lyricPrimaryColor = LyricTypography.hex($0)
                }), supportsOpacity: false).labelsHidden()
            }
            SettingRow(title: "翻译与下一句颜色", detail: "独立设置辅助文字颜色。", impact: "过暗的颜色可能在深色背景上难以阅读，可在下方预览检查。") {
                ColorPicker("辅助文字颜色", selection: Binding(get: { preferences.typography.secondary }, set: {
                    preferences.lyricSecondaryColor = LyricTypography.hex($0)
                }), supportsOpacity: false).labelsHidden()
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
                .padding(16)
            HStack {
                Text("预览使用实际歌词绘制方式；修改后立即生效并保存。").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("恢复字体与颜色") {
                    preferences.lyricFontName = ""
                    preferences.lyricPrimaryColor = "FFFFFF"
                    preferences.lyricSecondaryColor = "FFFFFF"
                }
            }.padding(16)
        }
    }
}
