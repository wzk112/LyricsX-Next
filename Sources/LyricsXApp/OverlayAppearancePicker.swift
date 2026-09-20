import SwiftUI

struct OverlayAppearancePicker: View {
    @Binding var selection: OverlayAppearance
    let transparency: Double
    let glassFrostAmount: Double
    let readingFrostAmount: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("悬浮窗样式").font(.body.weight(.medium))
            HStack(alignment: .top, spacing: 12) {
                ForEach(OverlayAppearance.allCases) { appearance in
                    SettingsIllustratedChoice(title: appearance.title, detail: appearance.detail,
                        selected: selection == appearance, action: { selection = appearance }) {
                        ZStack {
                            LinearGradient(colors: [.blue.opacity(0.65), .cyan.opacity(0.6), .orange.opacity(0.55)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                            HStack(spacing: 14) {
                                ForEach(0..<5) { _ in Rectangle().fill(.white.opacity(0.22)).frame(width: 12) }
                            }.rotationEffect(.degrees(25))
                            OverlayMaterialPreview(appearance: appearance, transparency: transparency,
                                frostAmount: appearance == .glass ? glassFrostAmount : readingFrostAmount)
                            VStack(spacing: 9) {
                                Text("当前歌词").font(.system(size: 20, weight: .semibold))
                                Text("翻译 / 下一句").font(.system(size: 12, weight: .medium))
                            }.foregroundStyle(.white).shadow(color: .black.opacity(0.85), radius: 2, y: 1)
                        }.frame(height: 108).clipShape(.rect(cornerRadius: 24))
                    }
                }
            }
            Text("点击图例切换。预览使用相同背景；实际效果会随悬浮窗后方内容变化。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(16)
    }
}

struct OverlayMaterialPreview: NSViewRepresentable {
    let appearance: OverlayAppearance
    let transparency: Double
    let frostAmount: Double
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func makeNSView(context: Context) -> OverlayGlassBackground { OverlayGlassBackground() }
    func updateNSView(_ view: OverlayGlassBackground, context: Context) {
        view.configure(appearance: appearance, transparency: transparency, frostAmount: frostAmount,
                       reduceTransparency: reduceTransparency, reduceMotion: true)
    }
}
