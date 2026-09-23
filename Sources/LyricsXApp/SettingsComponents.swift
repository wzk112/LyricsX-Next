import SwiftUI

struct SettingsIllustratedChoice<Preview: View>: View {
    let title: String
    let detail: String
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let preview: () -> Preview

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                preview().accessibilityHidden(true)
                HStack {
                    Text(title).font(.body.weight(.medium))
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Color.accentColor : .secondary)
                }
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(10).frame(maxWidth: .infinity, alignment: .topLeading)
                .background(selected ? Color.accentColor.opacity(0.07) : .clear, in: .rect(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.accentColor : .secondary.opacity(0.2), lineWidth: 1) }
                .contentShape(.rect(cornerRadius: 16))
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityHint(detail)
            .accessibilityValue(selected ? "已选择" : "未选择")
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary).padding(.leading, 2)
            VStack(alignment: .leading, spacing: 0) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.separator.opacity(0.35), lineWidth: 0.5).allowsHitTesting(false) }
        }
    }
}

struct SettingRow<Control: View>: View {
    let title: String
    let detail: String
    var impact: String? = nil
    @ViewBuilder let control: () -> Control
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 18) {
                Text(title).font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                control().fixedSize(horizontal: true, vertical: false)
            }
            Text(detail).font(.callout).foregroundStyle(.secondary).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            if let impact {
                Label(impact, systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(14)
    }
}

struct SettingToggle: View {
    let title: String
    let detail: String
    var impact: String? = nil
    @Binding var value: Bool
    var body: some View {
        SettingRow(title: title, detail: detail, impact: impact) {
            Toggle(title, isOn: $value).labelsHidden().toggleStyle(.switch).controlSize(.small)
                .accessibilityLabel(title).accessibilityHint(detail)
        }
    }
}

struct SettingSlider: View {
    let title: String
    let detail: String
    var impact: String? = nil
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step = 1.0
    var suffix = "pt"
    var multiplier = 1.0
    var decimals = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingRow(title: title, detail: detail, impact: impact) {
                Text(String(format: "%.*f", decimals, value * multiplier) + " " + suffix)
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step).accessibilityLabel(title).accessibilityHint(detail)
                .padding(.horizontal, 14).padding(.bottom, 14)
        }
    }
}
