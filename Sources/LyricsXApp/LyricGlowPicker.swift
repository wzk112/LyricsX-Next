import SwiftUI
import LyricsXCore

/// Both choices share one visible-only clock and the production renderer.
struct LyricGlowPicker: View {
    @Binding var enabled: Bool
    var reduced = false
    var lift = true
    @State private var visible = false
    @State private var anchor = ProcessInfo.processInfo.systemUptime
    @Environment(\.accessibilityReduceMotion) private var systemReduced

    private static let sample = LyricLine(id: 0, time: 0, text: "让光停留", words: [
        .init(text: "让", start: 0, end: 0.3),
        .init(text: "光", start: 0.3, end: 3),
        .init(text: "停留", start: 3, end: 4)
    ])

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LyricRenderTimeline(running: visible && !reduced && !systemReduced, sampledTime: 1.6,
                preciseTime: { (ProcessInfo.processInfo.systemUptime - anchor).truncatingRemainder(dividingBy: 5) }) { time in
            HStack(alignment: .top, spacing: 12) {
                ForEach([false, true], id: \.self) { glow in
                    SettingsIllustratedChoice(title: glow ? "开启" : "关闭",
                        detail: glow ? "慢唱和长音渐进发光，短音保持清晰。" : "保留逐字提亮，文字周围不加光晕。",
                        selected: enabled == glow, action: { enabled = glow }) {
                        ZStack {
                            LinearGradient(colors: [Color(red: 0.06, green: 0.11, blue: 0.17),
                                Color(red: 0.14, green: 0.10, blue: 0.18)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                            WordHighlight(line: Self.sample, time: time, active: true, text: Self.sample.text,
                                effects: .init(lift: lift, glow: glow, hdr: false))
                                .font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 14)
                        }.frame(height: 108).clipShape(.rect(cornerRadius: 24))
                    }.accessibilityLabel("长音辉光：" + (glow ? "开启" : "关闭"))
                }
            }
            }
            .environment(\.lyricFrameRateLimit, 60)
            .onScrollVisibilityChange(threshold: 0.1) { visible = $0 }
            .onDisappear { visible = false }
            Text("点击图例切换，同时应用于主窗口和悬浮窗。预览仅在可见时播放，使用普通亮度。")
                .font(.caption).foregroundStyle(.secondary)
            Label("需要歌词自带逐字时间；辉光会增加少量图形绘制开销。减少动态效果开启时暂停辉光。", systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(16)
    }
}
