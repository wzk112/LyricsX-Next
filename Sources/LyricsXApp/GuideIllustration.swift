import SwiftUI
import LyricsXCore

/// Isolated examples use the app's word renderer and materials. Controls only
/// change the example; they never select real lyrics or save user preferences.
struct GuideIllustration: View {
    let kind: String
    var appReduced = false
    @State private var visible = false
    @State private var inViewport = false
    @State private var anchor = ProcessInfo.processInfo.systemUptime
    @State private var appearance: OverlayAppearance = .glass
    @State private var fontName = ""
    @State private var palette = 0
    @Environment(\.accessibilityReduceMotion) private var reduced
    private let line = LyricLine(id: 0, time: 0, text: "让歌词随音乐流动", words: [
        .init(text: "让歌词", start: 0, end: 1.2), .init(text: "随", start: 1.2, end: 3.8),
        .init(text: "音乐", start: 3.8, end: 5), .init(text: "流动", start: 5, end: 6.5)])
    private static let palettes: [(name: String, sung: String, unsung: String, secondary: String)] = [
        ("粉紫", "FFD0EC", "857BA7", "D9CAEF"),
        ("青橙", "8CE9F0", "C88A57", "BDE7E4"),
        ("暖金", "FFE9B0", "B19173", "E8D8C9")]
    private var colors: LyricWordColors {
        let p = Self.palettes[palette]
        return .init(sung: LyricTypography.color(p.sung), unsung: LyricTypography.color(p.unsung), plain: LyricTypography.color(p.sung))
    }
    private var colored: Bool { ["colors", "wordColors", "theme"].contains(kind) }
    var body: some View {
        ZStack {
            Color.black
            LinearGradient(colors: kind == "theme" ? [colors.unsung.opacity(0.8), colors.sung.opacity(0.35)] :
                [Color(red: 0.12, green: 0.25, blue: 0.35), Color(red: 0.32, green: 0.2, blue: 0.36)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            if kind == "search" {
                GuideSearchIllustration().padding(14)
            } else if ["library", "privacy", "settings", "guide"].contains(kind) {
                navigationExample
            } else {
                lyricExample
            }
        }.foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
            .environment(\.lyricFrameRateLimit, 30)
            .background(WindowVisibilityReader { visible = $0 })
            .onScrollVisibilityChange(threshold: 0.1) { inViewport = $0 }
            .onDisappear { visible = false }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("功能示意预览，不会控制播放器或修改设置")
    }
    private var lyricExample: some View {
        VStack(spacing: 10) {
            if kind == "style" {
                Picker("材质示例", selection: $appearance) {
                    ForEach(OverlayAppearance.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).frame(maxWidth: 330)
            } else if kind == "font" {
                Picker("字体示例", selection: $fontName) {
                    Text("系统字体").tag("")
                    Text("Georgia").tag("Georgia")
                    Text("Menlo").tag("Menlo")
                }.pickerStyle(.segmented).frame(maxWidth: 340)
            } else if colored {
                HStack(spacing: 10) {
                    Text(kind == "theme" ? "封面示意" : "试试配色").font(.caption)
                    ForEach(Self.palettes.indices, id: \.self) { index in
                        let p = Self.palettes[index]
                        Button { palette = index } label: {
                            LinearGradient(colors: [LyricTypography.color(p.sung), LyricTypography.color(p.unsung)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                                .frame(width: 35, height: 23).clipShape(.rect(cornerRadius: 5))
                                .overlay { if palette == index { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.black) } }
                        }.buttonStyle(.plain).accessibilityLabel(p.name + (kind == "theme" ? "封面示例" : "配色示例"))
                    }
                }
            }
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: kind == "theme" ? "photo" : "music.note")
                    Text(kind == "font" ? "Aa · 字体排版示例" : "LyricsX Next · 演示歌词")
                    Spacer()
                }.font(.caption).foregroundStyle(.white.opacity(0.75))
                if kind == "font" {
                    Text("Lyrics · 歌词随音乐流动")
                        .font(LyricTypography(fontName: fontName).font(size: 25))
                        .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                } else {
                    LyricRenderTimeline(running: visible && inViewport && !reduced && !appReduced, sampledTime: 2.3,
                        preciseTime: { (ProcessInfo.processInfo.systemUptime - anchor).truncatingRemainder(dividingBy: 7.5) }) { time in
                        WordHighlight(line: line, time: time, active: true,
                            text: kind == "conversion" ? "讓歌詞隨音樂流動" : line.text,
                            effects: .init(glow: kind == "effects", reduced: reduced || appReduced))
                            .environment(\.lyricWordColors, colored ? colors : nil)
                            .font(.system(size: 26, weight: .semibold))
                            .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    }
                }
                if kind == "wordColors" {
                    HStack(spacing: 24) {
                        Label { Text("已唱到") } icon: { Circle().fill(colors.sung).frame(width: 9, height: 9) }
                        Label { Text("未唱到") } icon: { Circle().fill(colors.unsung).frame(width: 9, height: 9) }
                    }.font(.caption)
                } else {
                    Text(kind == "conversion" ? "简繁转换 · 保留逐字进度" : kind == "timing" ? "− 0.1 s     同步偏移     + 0.1 s" : "翻译 / 下一句 · 辅助文字示例")
                        .font(.callout).foregroundStyle(colored ? LyricTypography.color(Self.palettes[palette].secondary) : .white.opacity(0.8))
                }
            }.padding(14).background {
                if kind == "overlay" || kind == "style" {
                    OverlayMaterialPreview(appearance: appearance, transparency: 0.35, frostAmount: 0.5)
                    Color.black.opacity(0.35)
                } else {
                    Color.black.opacity(0.72)
                }
            }.clipShape(.rect(cornerRadius: 18))
        }.padding(12)
    }
    private var navigationExample: some View {
        let labels = kind == "library" ? ["导入歌词", "保留时间", "本地资料库"] :
            kind == "guide" ? ["首次使用", "本次更新", "关于 · 重看"] :
            kind == "settings" ? ["常用设置", "动态预览", "开发者选项"] : ["设置", "本地保存", "关于"]
        let symbols = kind == "library" ? ["doc.text", "clock", "books.vertical"] :
            kind == "guide" ? ["book.closed", "sparkles", "info.circle"] : ["slider.horizontal.3", "eye", "curlybraces"]
        return HStack(spacing: 14) {
            ForEach(labels.indices, id: \.self) { index in
                VStack(spacing: 14) {
                    Image(systemName: symbols[index]).font(.system(size: 30, weight: .light))
                    Text(labels[index]).font(.caption)
                }.frame(maxWidth: .infinity).frame(height: 100)
                    .background(.white.opacity(0.09), in: .rect(cornerRadius: 16))
            }
        }.padding(18)
    }
}

private struct GuideSearchIllustration: View {
    @State private var preview: Int?
    @State private var applied: Int?
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 9) {
                Label("搜索结果", systemImage: "magnifyingglass").font(.caption)
                ForEach(0..<2) { index in
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(index == 0 ? "版本 A · 双语" : "版本 B · 逐字")
                            if applied == index { Text("已应用").foregroundStyle(.mint) }
                        }.font(.caption)
                        Spacer(minLength: 0)
                        Button("预览") { preview = index }.controlSize(.small)
                    }.padding(8).background(.white.opacity(preview == index ? 0.22 : 0.08), in: .rect(cornerRadius: 8))
                }
            }.frame(maxWidth: .infinity)
            VStack(spacing: 9) {
                Text(preview == nil ? "先点左侧预览" : "歌词预览").font(.caption).foregroundStyle(.white.opacity(0.7))
                Text(preview == nil ? "选好后再应用" : preview == 0 ? "歌词与音乐同步" : "每个字，清楚呈现")
                    .font(.callout.weight(.semibold)).multilineTextAlignment(.center)
                if preview == 0 { Text("Lyrics in sync").font(.caption2).foregroundStyle(.white.opacity(0.7)) }
                Button(applied != nil && applied == preview ? "已应用" : "应用当前歌词") { applied = preview }
                    .controlSize(.small).disabled(preview == nil || applied == preview)
                Text("这里只是示例").font(.caption2).foregroundStyle(.white.opacity(0.6))
            }.frame(maxWidth: .infinity).padding(12)
                .background(.black.opacity(0.25), in: .rect(cornerRadius: 12))
        }
    }
}
