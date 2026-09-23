import AppKit
import SwiftUI
import LyricsXCore

enum HDRBrightness {
    static let range = 1.0...4.0
    static func clamped(_ value: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : 1
    }
    static func parsed(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "×", with: "").replacingOccurrences(of: ",", with: ".")),
            value.isFinite else { return nil }
        return (clamped(value) * 10).rounded() / 10
    }
    static func label(_ value: Double) -> String { String(format: "%.1f×", value) }
}

/// A still held-note frame uses the production HDR renderer. Unlike the
/// ordinary glow chooser, changing this control changes the actual emitter.
/// Display availability is sampled only while this setting is on screen.
struct HDRBrightnessControl: View {
    @Binding var value: Double
    @State private var draft = ""
    @State private var error: String?
    @State private var visible = false
    @State private var displays: [HDRDisplayCapability] = []
    @FocusState private var editing: Bool
    private static let sample = LyricLine(id: 0, time: 0, text: "让光停留", words: [
        .init(text: "让", start: 0, end: 0.3), .init(text: "光", start: 0.3, end: 3),
        .init(text: "停留", start: 3, end: 4)
    ])

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("HDR 亮度倍数").font(.body.weight(.medium))
                Spacer()
                TextField("亮度倍数", text: $draft)
                    .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                    .monospacedDigit().frame(width: 64).focused($editing)
                    .onSubmit(commit).accessibilityLabel("HDR 亮度倍数，1 到 4")
                Text("×").foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { HDRBrightness.clamped(value) }, set: {
                value = $0; draft = String(format: "%.1f", $0); error = nil
            }), in: HDRBrightness.range, step: 0.1)
                .accessibilityLabel("HDR 亮度倍数")
            HStack {
                Text("1.0× · 普通白色")
                Spacer()
                Text("4.0×")
            }.font(.caption).foregroundStyle(.secondary).monospacedDigit()
            if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(displays) { display in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(display.name).font(.caption.weight(.medium))
                        Text(display.supported
                            ? "当前可用 \(HDRBrightness.label(display.currentHeadroom)) · 屏幕上限 \(HDRBrightness.label(display.renderHeadroom))"
                            : "此屏幕使用普通亮度（1.0×）")
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        if value > display.renderHeadroom {
                            Text("在此屏幕上，目标限制为 \(HDRBrightness.label(display.renderHeadroom))。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                swatch(brightness: 1, title: "普通亮度 · 1.0×")
                swatch(brightness: value, title: "设定目标 · \(HDRBrightness.label(value))")
            }
            .hdrDisplayScope(requested: visible && value > 1, visible: visible)
            Text("预览停在同一个长音时刻，调节即可对比。1× 以普通白色为基准；屏幕当前可用亮度会随系统状态变化，超过时由系统限制。不会改变屏幕亮度设置。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(14)
            .onAppear {
                draft = String(format: "%.1f", value)
                displays = NSScreen.screens.map(HDRDisplayCapability.init(screen:))
            }
            .onChange(of: value) { _, new in if !editing { draft = String(format: "%.1f", new) } }
            .onChange(of: editing) { _, focused in if !focused { commit() } }
            .onScrollVisibilityChange(threshold: 0.1) { visible = $0 }
            .onDisappear { visible = false }
            .task(id: visible) {
                guard visible else { return }
                repeat {
                    if NSApp.isActive {
                        let next = NSScreen.screens.map(HDRDisplayCapability.init(screen:))
                        if next != displays { displays = next }
                    }
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                } while !Task.isCancelled
            }
    }

    private func commit() {
        guard let parsed = HDRBrightness.parsed(draft) else {
            error = "请输入 1.0 到 4.0 之间的数字。"
            draft = String(format: "%.1f", value)
            return
        }
        value = parsed
        draft = String(format: "%.1f", parsed)
        error = nil
    }

    private func swatch(brightness: Double, title: String) -> some View {
        VStack(spacing: 7) {
            WordHighlight(line: Self.sample, time: 1.6, active: true, text: Self.sample.text,
                effects: .init(lift: false, hdr: brightness > 1, hdrBrightness: brightness, compactHalo: true))
                .font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 80)
                .background(Color(red: 0.06, green: 0.08, blue: 0.12), in: .rect(cornerRadius: 12))
            Text(title).font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }.frame(maxWidth: .infinity)
    }
}
