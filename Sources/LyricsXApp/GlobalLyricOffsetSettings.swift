import SwiftUI
import LyricsXCore

struct GlobalLyricOffsetSettings: View {
    @Bindable var preferences: Preferences
    private var seconds: Binding<Double> {
        Binding(get: { Double(preferences.globalOffsetMilliseconds) / 1000 }, set: { value in
            guard value.isFinite else { return }
            preferences.globalOffsetMilliseconds = Int((min(300, max(-300, value)) * 1000).rounded())
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("通用歌词偏移").font(.body.weight(.medium))
            Text("适用于所有歌曲和播放器，与每首歌的偏移相加。正值提前，负值延后。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                TextField("通用歌词偏移（秒）", value: seconds,
                    format: .number.precision(.fractionLength(1...3)))
                    .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                    .monospacedDigit().frame(width: 100)
                    .accessibilityIdentifier("globalLyricOffsetSeconds")
                Text("秒").foregroundStyle(.secondary)
                Stepper("每次调整 0.1 秒", value: seconds, in: -300...300, step: 0.1)
                    .labelsHidden().accessibilityLabel("调整通用歌词偏移")
                Spacer(minLength: 0)
                Button("重置通用偏移") { preferences.globalOffsetMilliseconds = 0 }
                    .disabled(preferences.globalOffsetMilliseconds == 0)
            }
            Text("只保存到本机设置，不改写歌词文件或播放器进度。重置后仍保留各歌曲的偏移。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(16)
    }
}
