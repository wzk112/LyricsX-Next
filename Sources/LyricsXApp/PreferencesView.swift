import SwiftUI
import ServiceManagement
import LyricsXServices

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "通用", player = "播放器", overlay = "悬浮窗", lyrics = "歌词"
    case effects = "动效", sources = "搜索", developer = "开发者选项", about = "关于"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .player: "play.circle"
        case .overlay: "rectangle.on.rectangle"
        case .lyrics: "text.quote"
        case .effects: "sparkles"
        case .sources: "magnifyingglass"
        case .developer: "curlybraces"
        case .about: "info.circle"
        }
    }
    var summary: String {
        switch self {
        case .general: "启动方式、Dock 与菜单栏。"
        case .player: "选择播放状态的读取来源。"
        case .overlay: "调整桌面歌词的尺寸、背景与操作方式。"
        case .lyrics: "文字、翻译与辅助行的显示方式。"
        case .effects: "换句、逐字和长音的视觉效果。"
        case .sources: "选择歌词来源与版本偏好。"
        case .developer: "歌词文件、访问令牌和批量数据操作。"
        case .about: "版本、开源项目与许可。"
        }
    }
}

struct PreferencesView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var selection: SettingsSection? = .general
    @State private var token = ""
    @State private var tokenMessage = ""
    @State private var loginChangePending = false
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var settingsError: String?
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency

    init(model: AppModel, initialSection: SettingsSection = .general) {
        self.model = model
        _selection = State(initialValue: initialSection)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach(SettingsSection.allCases.filter { $0 != .developer && $0 != .about }) { section in
                        Label(section.rawValue, systemImage: section.symbol).tag(section)
                            .padding(.vertical, 4)
                    }
                }
                Section {
                    Label(SettingsSection.developer.rawValue, systemImage: SettingsSection.developer.symbol).tag(SettingsSection.developer)
                    Label(SettingsSection.about.rawValue, systemImage: SettingsSection.about.symbol).tag(SettingsSection.about)
                }
            }.listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 165, ideal: 180, max: 210)
        } detail: {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text((selection ?? .general).rawValue).font(.title2.bold())
                        Text((selection ?? .general).summary).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
                }.padding(24)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) { settingsContent }
                        .frame(maxWidth: 680, alignment: .leading)
                        .padding(24).frame(maxWidth: .infinity)
                }.id(selection).scrollBounceBehavior(.basedOnSize)
            }.background(.background)
        }
        .navigationTitle("设置")
        .frame(minWidth: 760, idealWidth: 880, minHeight: 580, idealHeight: 700)
        .task { model.displays.refresh(); refreshLoginStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refreshLoginStatus() }
        .alert("设置未能保存", isPresented: Binding(get: { settingsError != nil }, set: { if !$0 { settingsError = nil } })) {
            Button("好") { settingsError = nil }
        } message: { Text(settingsError ?? "") }
    }

    @ViewBuilder private var settingsContent: some View {
        switch selection ?? .general {
        case .general: generalSettings
        case .player: playerSettings
        case .overlay: overlaySettings
        case .lyrics: lyricSettings
        case .effects: effectSettings
        case .sources: sourceSettings
        case .developer: developerSettings
        case .about: aboutSettings
        }
    }

    private var generalSettings: some View {
        @Bindable var p = model.preferences
        return Group {
            SettingsCard(title: "应用入口") {
                SettingToggle(title: "在 Dock 中显示", detail: "显示屏幕底部的 LyricsX Next 图标。关闭后仍可用 ⌥⌘O 打开主窗口。", value: $p.showDockIcon)
                Divider().padding(.horizontal, 16)
                SettingToggle(title: "菜单栏图标", detail: "在屏幕顶部保留播放器、歌词搜索和设置入口。", value: $p.showMenuBarIcon)
                SettingToggle(title: "菜单栏歌词", detail: "在屏幕顶部显示当前一句；长句会截短，完整歌词不受影响。", value: $p.showMenubarLyrics)
                SettingToggle(title: "合并图标与歌词", detail: "让两者共用一个菜单栏位置，减少横向占用。", value: $p.combinedMenubarLyrics)
                    .disabled(!p.showMenuBarIcon || !p.showMenubarLyrics)
            }
            SettingsCard(title: "启动") {
                SettingToggle(title: "登录时启动", detail: "登录 macOS 后自动运行 LyricsX Next。", impact: "会在后台读取播放状态；可随时关闭。", value: Binding(
                    get: { p.launchAtLogin || loginStatus == .requiresApproval }, set: { enabled in
                        guard !loginChangePending else { return }
                        loginChangePending = true
                        Task {
                            defer { loginChangePending = false; refreshLoginStatus() }
                            do {
                                if enabled { try SMAppService.mainApp.register() }
                                else { try await SMAppService.mainApp.unregister() }
                            } catch { settingsError = error.localizedDescription }
                        }
                    })).disabled(loginChangePending)
                if loginStatus == .requiresApproval {
                    SettingRow(title: "等待系统允许", detail: "请在系统设置的登录项中允许 LyricsX Next 后台启动。") {
                        Button("打开系统设置") { SMAppService.openSystemSettingsLoginItems() }
                    }
                }
            }
            SettingsCard(title: "快捷键") {
                SettingRow(title: "悬浮歌词", detail: "显示或隐藏桌面上的悬浮窗。") { Text("⌥⌘L").monospaced() }
                SettingRow(title: "主窗口", detail: "隐藏 Dock 或菜单栏后也可使用。") { Text("⌥⌘O").monospaced() }
                SettingRow(title: "搜索歌词", detail: "在 LyricsX Next 内打开当前歌曲的版本搜索。") { Text("⌘F").monospaced() }
            }
        }
    }

    private var playerSettings: some View {
        @Bindable var p = model.preferences
        return SettingsCard(title: "连接播放器") {
            SettingRow(title: "读取来源", detail: "自动识别 Apple Music、Spotify、网易云、QQ 音乐及系统标记为音乐类的应用，排除浏览器。其他播放器需向系统提供播放状态；指定模式只跟随所选应用。", impact: "首次连接可能需要在 macOS 中允许自动化访问。") {
                Picker("读取来源", selection: $p.playerMode) {
                    ForEach(PlayerMode.allCases) { Text($0.title).tag($0) }
                }.labelsHidden().frame(width: 160)
            }.onChange(of: p.playerMode) { _, value in model.bridge.mode = value }
            SettingRow(title: "重新连接", detail: "在播放信息长时间不更新时重新建立连接。", impact: "读取状态可能短暂刷新，不会切歌或修改音乐资料库。") {
                Button("重新连接") { model.bridge.restart() }
            }
            if let error = model.playerError {
                Label(error, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange).padding(16)
            }
        }
    }

    private var overlaySettings: some View {
        @Bindable var p = model.preferences
        return Group {
            SettingsCard(title: "操作") {
                SettingToggle(title: "显示悬浮窗", detail: "将当前歌词或歌曲信息放在其他窗口之上。", value: Binding(get: { p.overlayVisible }, set: { model.setOverlayVisible($0) }))
                SettingToggle(title: "锁定位置", detail: "防止误拖动。悬浮窗控制条上仍可解锁；解锁后恢复拖动。", value: Binding(get: { p.overlayLocked }, set: { model.setOverlayLocked($0) }))
                SettingToggle(title: "点击穿透", detail: "点击歌词区域会操作后面的应用，控制条仍可使用。", impact: "开启时会锁定位置；解锁会同时关闭穿透。", value: Binding(get: { p.overlayClickThrough }, set: { model.setOverlayClickThrough($0) }))
                SettingToggle(title: "鼠标经过时隐藏", detail: p.overlayLocked ? "鼠标经过歌词会暂时隐藏内容，离开后恢复。" : "需要先锁定位置；解锁时暂不生效，保留你的选择。", value: $p.hideOverlayOnHover)
                SettingToggle(title: "暂停时隐藏", detail: "暂停音乐时隐藏悬浮窗，继续播放后恢复。", value: $p.hideWhenPaused)
            }
            SettingsCard(title: "外观") {
                if systemReduceTransparency {
                    Label("系统已开启降低透明度，当前使用实色背景；下方数值会保留。", systemImage: "info.circle")
                        .font(.callout).foregroundStyle(.secondary).padding(16)
                }
                OverlayAppearancePicker(selection: $p.overlayAppearance, transparency: p.overlayTransparency,
                    glassFrostAmount: p.overlayGlassFrostAmount, readingFrostAmount: p.overlayReadingFrostAmount)
                SettingSlider(title: "透明度", detail: "数值越高越通透，越低越容易看清歌词；图例与悬浮窗同步变化。", impact: "范围 20–80%。高透明度在浅色或复杂背景上会降低对比度；可选择磨砂阅读。系统“降低透明度”开启时使用实色背景。", value: $p.overlayTransparency, range: OverlayAppearance.transparencyRange, step: 0.02, suffix: "%", multiplier: 100).disabled(systemReduceTransparency)
                SettingSlider(title: "磨砂程度", detail: "柔化后方文字与图案，歌词文字保持清晰。两种样式分别记住调节值。", impact: "数值越高，背景细节越少；0% 仍保留材质自带的柔化效果。系统“降低透明度”开启时此调节不生效。", value: $p.overlayFrostAmount, range: OverlayAppearance.frostRange, step: 0.02, suffix: "%", multiplier: 100).disabled(systemReduceTransparency)
            }
            SettingsCard(title: "尺寸") {
                SettingToggle(title: "自动调整高度", detail: "宽度固定，只随当前歌词换行调整高度；顶部位置保持不变。", value: $p.overlayAdaptiveSize)
                SettingSlider(title: "窗口宽度", detail: p.overlayAdaptiveSize ? "当前固定为 \(Int(p.overlayLayoutWidth)) pt。关闭自动高度后可手动修改。" : "同时调整歌词与歌曲信息卡片的可用宽度。", value: $p.overlayWidth, range: 320...1000, step: 20)
                    .disabled(p.overlayAdaptiveSize)
            }
        }
    }

    private var lyricSettings: some View {
        @Bindable var p = model.preferences
        return Group {
            LyricTypographySettings(preferences: p)
            SettingsCard(title: "文字") {
                SettingToggle(title: "显示翻译", detail: "在有翻译的歌词中显示译文，同时影响主窗口和悬浮窗。", value: $p.showTranslation)
                SettingRow(title: "中文显示", detail: "只转换界面中的简繁体，不改写原歌词文件。") {
                    Picker("中文显示", selection: $p.conversion) {
                        ForEach(["原文", "简体", "繁體"], id: \.self) { Text($0) }
                    }.labelsHidden().frame(width: 110)
                }
                SettingSlider(title: "主窗口歌词字号", detail: "调整应用内原文的大小，长句自动换行。", value: $p.mainLyricFontSize, range: 20...42)
                if p.showTranslation { SettingSlider(title: "主窗口翻译字号", detail: "独立调整应用内译文大小。", value: $p.mainTranslationFontSize, range: 11...24) }
            }
            SettingsCard(title: "悬浮窗文字") {
                SettingSlider(title: "当前句字号", detail: "调整主歌词大小，辅助行保留独立字号。", value: $p.fontSize, range: 18...42)
                SettingRow(title: "辅助内容", detail: "“翻译或下一句”优先显示译文，没有译文时显示下一句；“仅翻译”不会回退。") {
                    Picker("辅助内容", selection: $p.overlaySecondaryMode) {
                        ForEach(OverlaySecondaryMode.allCases) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(width: 150)
                }
                if p.showTranslation && p.overlaySecondaryMode.supportsTranslation { SettingSlider(title: "翻译字号", detail: "调整悬浮窗译文大小，长译文最多显示两行。", value: $p.translationFontSize, range: 10...24) }
                if p.overlaySecondaryMode.supportsNext { SettingSlider(title: "下一句字号", detail: "调整下一句预览大小，换句时会放大并上移为当前句。", value: $p.nextLineFontSize, range: 10...24) }
            }
            SettingsCard(title: "同步") {
                SettingRow(title: "歌词时间偏移", detail: "在主窗口底部或菜单栏调整。正值提前显示，负值延后显示。", impact: "偏移会保存回当前歌词文件，下次播放继续沿用。") { EmptyView() }
            }
        }
    }

    private var effectSettings: some View {
        @Bindable var p = model.preferences
        return Group {
            SettingsCard(title: "动态效果") {
                if systemReduceMotion {
                    Label("macOS 已开启减少动态效果，应用内动效暂时受系统设置限制。", systemImage: "info.circle")
                        .font(.callout).foregroundStyle(.secondary).padding(16)
                }
                SettingToggle(title: "减少动态效果", detail: "关闭位移、回弹、模糊和辉光，保留歌词同步提亮。", impact: "也会遵循 macOS 的减少动态效果设置。", value: $p.reduceMotion)
                SettingToggle(title: "逐字轻微放大", detail: "演唱中的词柔和放大并轻微上浮，未唱部分保持接近原字号。", impact: "需要歌词自带逐字时间；开启动效会增加少量绘制开销。", value: $p.lyricWordLift)
                    .disabled(p.reduceMotion || systemReduceMotion)
                SettingRow(title: "预览动效", detail: "使用独立演示歌词查看普通逐字、长音和高速增量效果。", impact: "不会控制播放器或写入歌词缓存。") {
                    Button("打开预览") { openWindow(id: "preview") }
                }
            }
            SettingsCard(title: "长音辉光") {
                LyricGlowPicker(enabled: $p.lyricGlow, reduced: p.reduceMotion || systemReduceMotion)
                    .disabled(p.reduceMotion || systemReduceMotion)
            }
            if p.lyricGlow && !p.reduceMotion && !systemReduceMotion { hdrSettings }
        }
    }

    private var hdrSettings: some View {
        @Bindable var p = model.preferences
        let unavailable = !p.lyricGlow || p.reduceMotion || systemReduceMotion
        return SettingsCard(title: "HDR / EDR 辉光") {
            SettingToggle(title: "HDR 辉光增强", detail: "默认开启，按所在屏幕能力增强长音辉光。普通屏幕自动使用普通亮度。需先开启长音辉光。", impact: "高亮效果可能更刺眼并增加能耗；实际亮度由屏幕和系统决定。", value: $p.lyricHDR)
                .disabled(unavailable)
            if p.lyricHDR {
            SettingSlider(title: "HDR 亮度", detail: "设置辉光的目标强度，自动限制在所在屏幕的能力内。不会改变屏幕亮度设置。", value: $p.lyricHDRBrightness, range: 1...4, step: 0.1, suffix: "×", decimals: 1)
                .disabled(unavailable)
            }
        }
    }

    private var sourceSettings: some View {
        @Bindable var p = model.preferences
        return Group {
            SettingsCard(title: "选择版本") {
                SettingToggle(title: "双语优先", detail: "优先带翻译的版本；没有双语版本时尝试逐字歌词。", value: $p.preferBilingual)
                SettingToggle(title: "逐字优先", detail: "优先带逐字时间的版本；没有逐字版本时尝试双语歌词。两项都开时，先逐字、后双语。", value: $p.preferWordTiming)
                SettingToggle(title: "严格匹配", detail: "开启时更重视歌名的准确匹配；关闭后允许可信的别名、音译和标题变体。", impact: "过严可能漏掉版本，放宽后需要留意同名歌曲或翻唱。", value: $p.strictLyricsMatching)
                SettingRow(title: "完整搜索", detail: "可在搜索窗口临时开启，默认关闭。会搜索更多别名和版本。", impact: "开启后结果更多，最长可能等待 40 秒。") {
                    Button("打开搜索") { openWindow(id: "main"); model.showSearch = true }
                }
            }
            SettingsCard(title: "来源顺序") {
                Text("越靠上越优先。拖动手柄或使用箭头排序，关闭的来源不参与搜索。联网时会向启用的来源发送歌名、歌手和时长。")
                    .font(.callout).foregroundStyle(.secondary).padding(16)
                ForEach(p.sourceOrder, id: \.self) { source in sourceRow(source, prefs: p) }
                SettingRow(title: "恢复默认顺序", detail: "只恢复来源排序，保留各来源开关和版本偏好。") {
                    Button("恢复顺序") { p.sourceOrder = SourceConfiguration.defaultOrder }
                }
            }
            SettingsCard(title: "当前歌曲") {
                SettingRow(title: "按当前偏好重新搜索", detail: "优先级从下一次搜索生效；现有缓存仍会优先复用。", impact: "重新搜索并应用版本后，会更新当前歌曲的缓存文件。") {
                    Button("重新搜索") { model.refreshLyrics() }.disabled(model.session.track == nil || model.lyricsBlocked)
                }
            }
        }
    }

    private var developerSettings: some View {
        @Bindable var p = model.preferences
        return Group {
            SettingsCard(title: "渲染与功耗") {
                SettingRow(title: "悬浮窗帧率", detail: "智能节能在系统低电量模式或明显发热时限制为 60 帧，恢复后跟随屏幕。也可固定 60 帧。所有动效都会保留。", impact: "高刷新率屏幕下，60 帧的运动细腻度会有所降低。实际 GPU 占用还受玻璃背景与其他窗口影响。") {
                    Picker("悬浮窗帧率", selection: $p.overlayFrameRate) {
                        ForEach(OverlayFrameRate.allCases) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(width: 140)
                }
            }
            SettingsCard(title: "歌词文件夹") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前路径").font(.body.weight(.medium))
                    Text(p.directory.path).font(.callout).foregroundStyle(.secondary).textSelection(.enabled).lineLimit(4).truncationMode(.middle)
                }.padding(16)
                SettingRow(title: "更换缓存文件夹", detail: "复用已有 LRC / LRCX 文件，新下载默认保存为 LRCX。", impact: "只切换读写位置，不搬迁或删除原文件；空文件夹会重新下载歌词。") {
                    Button("选择…") { model.chooseCacheDirectory() }
                }
                SettingRow(title: "在 Finder 中打开", detail: "查看、备份或手动编辑歌词文件。", impact: "手动删除的文件无法由 LyricsX 自动恢复。") {
                    Button("打开文件夹") { NSWorkspace.shared.open(p.directory) }
                }
            }
            SettingsCard(title: "导入与导出") {
                SettingRow(title: "导入当前歌曲歌词", detail: "为正在播放的歌曲选择 LRC、LRCX 或文本文件。", impact: "应用后会替换这首歌现有的缓存版本。") {
                    Button("导入…") { model.importLyrics() }.disabled(model.session.track == nil)
                }
                SettingRow(title: "导出歌词", detail: "保存 LRCX 副本，保留翻译、时间轴和逐字标记。") {
                    Button("导出 LRCX…") { model.exportLyrics() }.disabled(model.session.document == nil)
                }
                SettingRow(title: "导出纯文本", detail: "保存便于阅读的文本副本，不改变当前缓存。", impact: "纯文本没有行时间和逐字时间。") {
                    Button("导出文本…") { model.exportLyrics(plain: true) }.disabled(model.session.document == nil)
                }
                SettingRow(title: "写入 Apple Music", detail: "将当前歌词作为纯文本写入 Apple Music 当前歌曲的歌词字段。", impact: "会修改音乐资料库中的歌词，可能覆盖已有内容。") {
                    Button("写入") { model.writeLyricsToMusic() }
                        .disabled(model.session.document == nil || model.session.track?.playerID != "com.apple.Music")
                }
            }
            SettingsCard(title: "Musixmatch 访问令牌") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("为 Musixmatch 歌词来源配置可选的 usertoken。").font(.callout).foregroundStyle(.secondary)
                    SecureField("usertoken", text: $token).textFieldStyle(.roundedBorder)
                    HStack {
                        Text(tokenMessage).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("保存到钥匙串") {
                            do { try TokenStore.save(token); tokenMessage = token.isEmpty ? "已移除令牌" : "已保存" }
                            catch { tokenMessage = error.localizedDescription }
                        }
                    }
                    Text("令牌保存在系统钥匙串中，只用于访问该来源。不要分享令牌；保存空内容会移除它。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(16).task { token = TokenStore.read() ?? "" }
            }
            SettingsCard(title: "显示诊断") {
                ForEach(model.displays.displays) { display in
                    SettingRow(title: display.name, detail: "EDR 潜在余量 \(display.potential.formatted(.number.precision(.fractionLength(2))))×；当前报告 \(display.current.formatted(.number.precision(.fractionLength(2))))×。这些是相对普通白色的倍数，不是尼特数或面板认证。") {
                        Text(display.status).foregroundStyle(.secondary)
                    }
                }
            }
            SettingsCard(title: "搜索排除记录") {
                SettingRow(title: "恢复全部歌词搜索", detail: "已停用 \(p.blockedTracks.count) 首歌曲、\(p.blockedAlbums.count) 张专辑。", impact: "会清空排除记录，之前因匹配错误停用的歌曲也会重新搜索；不会删除歌词文件。") {
                    Button("恢复全部") { p.blockedTracks = []; p.blockedAlbums = []; model.session.reload() }
                        .disabled(p.blockedTracks.isEmpty && p.blockedAlbums.isEmpty)
                }
            }
        }
    }

    private var aboutSettings: some View {
        SettingsCard(title: "LyricsX Next") {
            SettingRow(title: "Swift 重构版", detail: "版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版本") · Zikai Wang") {
                Image(systemName: "quote.bubble.fill").font(.largeTitle).foregroundStyle(.pink)
            }
            SettingRow(title: "使用指南", detail: "从连接播放器到搜索、悬浮窗、自定义、同步与文件管理，完整图文教程。") {
                Button("查看教程") { model.showFeatureGuide?(true) }
            }
            SettingRow(title: "本次更新", detail: "重新查看当前版本新增的功能、修复和优化。") {
                Button("版本介绍") { model.showFeatureGuide?(false) }
            }
            SettingRow(title: "项目与更新", detail: "查看本重构版源代码、版本说明和安装包。") {
                Link("GitHub", destination: URL(string: "https://github.com/wzk112/LyricsX-Next")!)
            }
            SettingRow(title: "上游项目", detail: "保留原 LyricsX、LyricsKit 与媒体适配组件的开源声明。") {
                Link("查看上游", destination: URL(string: "https://github.com/MxIris-LyricsX-Project/LyricsX")!)
            }
            SettingRow(title: "开源许可", detail: "本项目采用 MPL-2.0，依赖遵循各自许可。") {
                Link("查看许可", destination: URL(string: "https://github.com/wzk112/LyricsX-Next/blob/master/LICENSE")!)
            }
        }
    }

    private func refreshLoginStatus() {
        loginStatus = SMAppService.mainApp.status
        model.preferences.launchAtLogin = loginStatus == .enabled
    }

    private func sourceRow(_ source: String, prefs: Preferences) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
                .frame(width: 22, height: 30).contentShape(.rect).draggable(source)
                .help("拖动调整 " + sourceName(source) + " 的优先级")
            Text("\((prefs.sourceOrder.firstIndex(of: source) ?? 0) + 1)")
                .monospacedDigit().foregroundStyle(.secondary).frame(width: 16)
            Toggle(sourceName(source), isOn: Binding(get: { !prefs.disabledSources.contains(source) }, set: { prefs.setSource(source, enabled: $0) }))
                .toggleStyle(.switch).controlSize(.small)
                .accessibilityHint("启用后向此来源查询歌词；关闭后不参与搜索。")
            Button { prefs.moveSource(source, by: -1) } label: { Image(systemName: "chevron.up").frame(width: 22, height: 22) }
                .disabled(prefs.sourceOrder.first == source).accessibilityLabel("提高 " + sourceName(source) + " 的优先级")
            Button { prefs.moveSource(source, by: 1) } label: { Image(systemName: "chevron.down").frame(width: 22, height: 22) }
                .disabled(prefs.sourceOrder.last == source).accessibilityLabel("降低 " + sourceName(source) + " 的优先级")
        }.buttonStyle(.borderless).padding(.horizontal, 16).padding(.vertical, 10).contentShape(.rect)
            .dropDestination(for: String.self) { items, _ in
                guard let item = items.first else { return false }
                return prefs.moveSource(item, before: source)
            }
    }

    private func sourceName(_ value: String) -> String {
        switch value {
        case "NetEase": "网易云音乐"
        case "QQMusic": "QQ 音乐"
        case "Kugou": "酷狗音乐"
        default: value
        }
    }
}
