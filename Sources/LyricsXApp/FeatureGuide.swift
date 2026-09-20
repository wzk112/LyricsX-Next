import AppKit
import SwiftUI
import LyricsXCore
import LyricsXServices

/// Capture installation evidence BEFORE Preferences performs its migrations.
/// Receipt lives in the app domain, so replacing/moving the .app or a manual
/// download has the same behavior as any other update method.
@MainActor final class GuideHistory {
    enum Presentation: Equatable { case tutorial, update(previous: String?) }
    private let defaults: UserDefaults
    let version: String
    let existingInstallation: Bool
    init(defaults: UserDefaults = .standard, version: String = GuideContent.version) {
        self.defaults = defaults
        self.version = version
        existingInstallation = ["compactOverlayVersion", "fixedOverlayWidthVersion", "overlayVisible",
            "overlayWidth", "overlayAppearance", "fontSize", "playerMode", "ModernLyricsDirectory",
            "guideLastVersion"].contains { defaults.object(forKey: $0) != nil }
    }
    var pending: Presentation? {
        guard !(defaults.stringArray(forKey: "guidePresentedVersions") ?? []).contains(version),
              defaults.string(forKey: "guideLastVersion") != version else { return nil }
        return existingInstallation ? .update(previous: defaults.string(forKey: "guideLastVersion")) : .tutorial
    }
    func didPresent() {
        var versions = defaults.stringArray(forKey: "guidePresentedVersions") ?? []
        if !versions.contains(version) { versions.append(version) }
        defaults.set(versions, forKey: "guidePresentedVersions")
        defaults.set(version, forKey: "guideLastVersion")
    }
}

struct GuidePage: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let points: [String]
    var illustration = "lyrics"
}

enum GuideContent {
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.34"
    static let tutorial: [GuidePage] = [
        .init(id: "start", title: "播放音乐，歌词自动出现", subtitle: "先播放一首歌", symbol: "play.circle", points: [
            "打开 Apple Music、Spotify、网易云或 QQ 音乐播放歌曲，即可自动同步歌词。自动识别不包含浏览器。",
            "没有识别到播放器？前往“设置 → 播放器”选择来源或重新连接。系统询问控制播放器的权限时，请允许。",
            "应用会自动搜索并保存歌词。等待歌词时显示三个点，纯音乐或没有歌词时显示歌曲信息。"], illustration: "player"),
        .init(id: "main", title: "主窗口与菜单栏", subtitle: "播放、切歌和查看歌词", symbol: "text.quote", points: [
            "点击歌词可跳到那一句；底部可以播放、暂停、切歌和拖动进度。",
            "关闭主窗口也能继续看悬浮歌词。菜单栏歌词、Dock 图标和登录启动，可在“设置 → 通用”调整。",
            "⌥⌘O 打开主窗口，⌥⌘L 显示或隐藏悬浮窗。隐藏菜单栏和 Dock 图标后，仍可用快捷键打开。"], illustration: "player"),
        .init(id: "search", title: "选择合适的歌词", subtitle: "点击放大镜，或按 ⌘F", symbol: "magnifyingglass", points: [
            "输入歌名或歌手，点“预览”查看效果，再点“应用当前歌词”使用。列表会保持打开，方便继续挑选。",
            "“完整搜索”会查找更多版本，但可能需要更久；平时保持关闭即可。",
            "下方可调整来源顺序、逐字或双语优先。改好后，对当前歌曲点“重新搜索”，即可重新选择。"], illustration: "search"),
        .init(id: "overlay", title: "把歌词放在桌面上", subtitle: "设置 → 悬浮窗", symbol: "rectangle.on.rectangle", points: [
            "悬浮窗显示在其他窗口上方，可随长句自动换行、调整高度。关闭自动高度后可手动调整宽度。",
            "解锁后拖动窗口，锁定后避免误拖。“点击穿透”让你直接操作后面的应用，并自动锁定位置。",
            "锁定时可开启“鼠标经过时隐藏”，离开后恢复。也可以选择暂停播放时隐藏。"], illustration: "overlay"),
        .init(id: "style", title: "选择喜欢的背景", subtitle: "Liquid Glass · 磨砂阅读", symbol: "square.on.square", points: [
            "Liquid Glass 更通透；磨砂阅读能柔化背景，让歌词更清楚。点击图例切换。",
            "透明度越高，越能看清后方；磨砂越强，背景越柔和。两种样式会分别记住磨砂程度。",
            "实际效果会随桌面背景变化。系统开启“降低透明度”时，会使用实色背景。"], illustration: "style"),
        .init(id: "text", title: "字体和颜色，由你决定", subtitle: "设置 → 歌词 · 边调边预览", symbol: "textformat", points: [
            "选择喜欢的本机字体，分别调整主窗口、悬浮窗和辅助文字的字号。字体缺少某些字符时，会自动使用系统字体。",
            "自由设置文字颜色，也能分别设置已唱、未唱的颜色。开启“跟随封面主题色”，歌词就会随歌曲封面换色。",
            "辅助文字可选翻译、下一句或两者都显示。“翻译或下一句”会在没有翻译时显示下一句；也支持简繁体显示。"], illustration: "text"),
        .init(id: "effects", title: "让歌词随演唱亮起来", subtitle: "设置 → 动效", symbol: "sparkles", points: [
            "带逐字时间的歌词会依次提亮、轻微放大，慢唱和长音还会柔和发光。普通逐行歌词没有这些效果。",
            "EDR 辉光增强可让高光更亮，实际效果取决于屏幕。它不会改变系统亮度；不支持时使用普通辉光。",
            "喜欢安静的画面，可开启“减少动态效果”。想降低开销，可在开发者选项中选择 60 帧或智能节能。"], illustration: "effects"),
        .init(id: "timing", title: "让歌词与音乐对齐", subtitle: "每首歌都会记住调整", symbol: "slider.horizontal.3", points: [
            "歌词慢了，用正偏移提前；歌词快了，用负偏移延后。底部每次调整 0.1 秒，点击数值即可重置。",
            "也可用 ⌥⌘↑／↓ 每次调整 0.2 秒。调整会保存，下次播放无需重设。",
            "歌词版本不对时可重新搜索。菜单栏 → 歌词还可以停用某首歌或整张专辑的搜索，需要时再恢复。"], illustration: "timing"),
        .init(id: "library", title: "使用自己的歌词文件", subtitle: "点击书本图标打开资料库", symbol: "books.vertical", points: [
            "下载过的歌词会保存在本地，下次播放优先使用。资料库可以查看已有歌词。",
            "把 LRC 或 LRCX 文件拖入主窗口，即可替换当前歌词。LRCX 可保留翻译和逐字效果；导出纯文本则不保留时间。",
            "更换保存位置、导出和写入 Apple Music 等操作在开发者选项中。更换位置不会自动搬移文件；写入 Apple Music 可能覆盖原歌词。"], illustration: "library"),
        .init(id: "privacy", title: "帮助与更新", subtitle: "设置 → 关于，可随时重看", symbol: "info.circle", points: [
            "搜索时会向启用的歌词来源发送歌名、歌手和时长。不需要的来源可在设置中关闭。",
            "开发者选项包含文件管理、歌词来源令牌和性能设置，日常使用无需调整。来源令牌保存在系统钥匙串中。",
            "菜单栏可以检查更新。教程和更新介绍只自动显示一次，以后可在“设置 → 关于”重新查看。"], illustration: "privacy")
    ]
    // Add new release entries here; a version jump includes every intervening
    // entry, while a first upgrade from versions without receipts gets a recap.
    static let releases: [(version: String, page: GuidePage)] = [
        ("2.0.34", .init(id: "r30", title: "换上喜欢的字体", subtitle: "新功能 · 设置 → 歌词", symbol: "textformat", points: [
            "使用本机安装的字体，分别调整主窗口、悬浮窗和辅助文字的字号。",
            "边调边预览，找到适合自己的大小和风格。"], illustration: "text")),
        ("2.0.34", .init(id: "color34", title: "歌词颜色，自由搭配", subtitle: "新功能 · 设置 → 歌词", symbol: "paintpalette", points: [
            "原文与翻译可以分别选色，逐字歌词也能单独设置已唱和未唱的颜色。",
            "保留逐字高亮和长音辉光，让演唱进度更清楚。"], illustration: "text")),
        ("2.0.34", .init(id: "theme34", title: "跟随歌曲封面换色", subtitle: "新功能 · 设置 → 歌词", symbol: "photo", points: [
            "开启“跟随封面主题色”，歌词会自动搭配当前封面；已唱与未唱用明暗区分。",
            "主窗口背景也更有封面的色彩。关闭开关即可恢复手动配色。"], illustration: "theme")),
        ("2.0.34", .init(id: "r29", title: "悬浮歌词显示更稳定", subtitle: "修复 · 启动、换行与切歌", symbol: "rectangle.on.rectangle", points: [
            "启动后即可显示悬浮窗，菜单栏歌词也恢复正常。",
            "修复切歌或更换歌词后高度未及时变化、文字被截断，以及更换字体后对齐不准的问题。"], illustration: "overlay")),
        ("2.0.34", .init(id: "r33", title: "播放与切歌更流畅", subtitle: "改进 · 动画与性能", symbol: "waveform", points: [
            "改善逐字、辉光、封面和背景过渡，减少播放与切歌时的卡顿、闪动，并降低不必要的资源占用。",
            "修复简繁体转换后逐字效果失效，以及部分歌词搜索和显示问题。"], illustration: "effects")),
        ("2.0.34", .init(id: "settings34", title: "设置更清楚，上手更轻松", subtitle: "新增教程 · 设置 → 关于", symbol: "slider.horizontal.3", points: [
            "搜索可先预览再应用，列表保持打开，方便挑选。设置页面也更清楚、更好操作。",
            "首次使用会显示完整教程，更新后只介绍本次变化。以后都可以在“关于”中重新查看。"], illustration: "settings"))
    ]
    // Last release actually published on GitHub, not a local test build.
    static let latestBaseline: String? = "2.0.28"
    static func updates(after previous: String?) -> [GuidePage] {
        let pages = releases.filter { entry in
            guard let previous else { return true }
            return entry.version.compare(previous, options: .numeric) == .orderedDescending
        }.map(\.page)
        return pages.isEmpty ? releases.filter { $0.version == "2.0.34" }.map(\.page) : pages
    }
}

@MainActor final class FeatureGuideController: NSObject, NSWindowDelegate {
    let history: GuideHistory
    weak var preferences: Preferences?
    weak var model: AppModel?
    private(set) var window: NSWindow?
    init(history: GuideHistory = GuideHistory()) { self.history = history }
    func showAutomaticIfNeeded() {
        guard let pending = history.pending else { return }
        show(pending)
        // Record only after constructing and ordering the visible window.
        history.didPresent()
    }
    func show(_ mode: GuideHistory.Presentation) {
        if window == nil {
            let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 920, height: 700),
                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.minSize = .init(width: 800, height: 640)
            window.delegate = self
            window.center()
            self.window = window
        }
        window?.title = mode == .tutorial ? "LyricsX Next · 使用指南" : "LyricsX Next · 版本介绍"
        window?.contentView = NSHostingView(rootView: FeatureGuideView(mode: mode, preferences: preferences, model: model, close: { [weak self] in self?.window?.close() }))
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
    func windowWillClose(_ notification: Notification) {
        // Release previews/display links even though the controller is retained.
        window?.contentView = nil
        window = nil
    }
}

struct FeatureGuideView: View {
    let mode: GuideHistory.Presentation
    let preferences: Preferences?
    let model: AppModel?
    let close: () -> Void
    @State private var index = 0
    init(mode: GuideHistory.Presentation, initialPage: Int = 0, preferences: Preferences? = nil, model: AppModel? = nil, close: @escaping () -> Void) {
        self.mode = mode
        self.preferences = preferences
        self.model = model
        self.close = close
        let count: Int
        if case .update(let previous) = mode { count = GuideContent.updates(after: previous).count }
        else { count = GuideContent.tutorial.count }
        _index = State(initialValue: min(max(0, initialPage), max(0, count - 1)))
    }
    private var pages: [GuidePage] {
        if case .update(let previous) = mode { return GuideContent.updates(after: previous) }
        return GuideContent.tutorial
    }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Label("LyricsX Next", systemImage: "quote.bubble.fill").font(.headline)
                Text(mode == .tutorial ? "使用指南" : "更新至 \(GuideContent.version)")
                    .font(.title3.weight(.semibold))
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(Array(pages.enumerated()), id: \.element.id) { item in
                            Button { index = item.offset } label: {
                                Label(item.element.title, systemImage: item.element.symbol)
                                    .font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10).background(index == item.offset ? Color.accentColor.opacity(0.14) : .clear,
                                                            in: .rect(cornerRadius: 10))
                            }.buttonStyle(.plain).accessibilityAddTraits(index == item.offset ? .isSelected : [])
                        }
                    }
                }
                Text("无需登录 · 设置自动保存").font(.caption).foregroundStyle(.secondary)
            }.padding(20).frame(width: 205).background(.quaternary.opacity(0.25))
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    let page = pages[min(index, pages.count - 1)]
                    VStack(alignment: .leading, spacing: 18) {
                        Text(page.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        Text(page.title).font(.system(size: 27, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                        GuideIllustration(kind: page.illustration, appReduced: preferences?.reduceMotion == true).id(page.id)
                            .frame(height: 190).clipShape(.rect(cornerRadius: 20))
                        ForEach(Array(page.points.enumerated()), id: \.offset) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(item.offset + 1)").font(.caption.bold()).foregroundStyle(Color.accentColor)
                                    .frame(width: 24, height: 24).background(Color.accentColor.opacity(0.12), in: .circle)
                                Text(item.element).font(.body).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if let preferences {
                            GuideQuickSettings(page: page.id, preferences: preferences, model: model)
                        }
                    }.padding(26)
                }.id(index)
                Divider()
                HStack {
                    Button("稍后再看", action: close)
                    Spacer()
                    Text("\(index + 1) / \(pages.count)").monospacedDigit().foregroundStyle(.secondary)
                    Button("上一步") { index -= 1 }.disabled(index == 0)
                    Button(index == pages.count - 1 ? "开始使用" : "下一步") {
                        if index == pages.count - 1 { close() } else { index += 1 }
                    }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }.padding(20)
            }
        }.frame(minWidth: 800, minHeight: 600).background(.background)
    }
}

/// Original demonstration text; shares the actual word renderer and materials.
/// One 30 Hz clock per visible page, no player connection or cache writes.
private struct GuideIllustration: View {
    let kind: String
    var appReduced = false
    @State private var visible = false
    @State private var inViewport = false
    @State private var anchor = ProcessInfo.processInfo.systemUptime
    @State private var appearance: OverlayAppearance = .glass
    @Environment(\.accessibilityReduceMotion) private var reduced
    private let line = LyricLine(id: 0, time: 0, text: "让歌词随音乐流动", words: [
        .init(text: "让歌词", start: 0, end: 1.2), .init(text: "随", start: 1.2, end: 3.8),
        .init(text: "音乐", start: 3.8, end: 5), .init(text: "流动", start: 5, end: 6.5)])
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.25, blue: 0.35), Color(red: 0.32, green: 0.2, blue: 0.36)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if kind == "search" {
                VStack(alignment: .leading, spacing: 12) {
                    Label("歌名 / 歌手", systemImage: "magnifyingglass").foregroundStyle(.white.opacity(0.7))
                    ForEach(["网易云音乐 · 双语 · 逐字", "QQ 音乐 · 逐字", "LRCLIB · 逐行"], id: \.self) { text in
                        HStack { Text(text); Spacer(); Image(systemName: "chevron.right") }
                            .padding(10).background(.white.opacity(0.12), in: .rect(cornerRadius: 9))
                    }
                }.font(.callout).padding(20)
            } else if kind == "library" || kind == "privacy" || kind == "settings" {
                HStack(spacing: 25) {
                    ForEach(kind == "library" ? ["doc.text", "arrow.right", "books.vertical"] : ["slider.horizontal.3", "lock.shield", "info.circle"], id: \.self) { icon in
                        Image(systemName: icon).font(.system(size: 36, weight: .light))
                            .frame(width: 70, height: 80).background(.white.opacity(0.08), in: .rect(cornerRadius: 18))
                    }
                }
            } else {
                VStack(spacing: 12) {
                    if kind == "style" {
                        Picker("材质预览", selection: $appearance) {
                            ForEach(OverlayAppearance.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented).frame(maxWidth: 330)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        HStack { Image(systemName: "music.note"); Text("LyricsX Next · 演示歌词"); Spacer() }
                            .font(.caption).foregroundStyle(.white.opacity(0.75))
                        LyricRenderTimeline(running: visible && inViewport && !reduced && !appReduced, sampledTime: 2.3,
                            preciseTime: { (ProcessInfo.processInfo.systemUptime - anchor).truncatingRemainder(dividingBy: 7.5) }) { time in
                            WordHighlight(line: line, time: time, active: true,
                                text: kind == "conversion" ? "讓歌詞隨音樂流動" : line.text,
                                effects: .init(glow: kind == "effects", reduced: reduced || appReduced))
                                .environment(\.lyricWordColors, kind == "theme" ? .init(sung: Color(red: 1, green: 0.82, blue: 0.94), unsung: Color(red: 0.43, green: 0.35, blue: 0.40), plain: .white) : nil)
                                .font(.system(size: 28, weight: .semibold)).frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                        Text(kind == "conversion" ? "简繁转换 · 时间轴保持一致" : kind == "timing" ? "− 0.1 s     同步偏移     + 0.1 s" : "翻译 / 下一句 · 保持同步")
                            .font(.callout).frame(maxWidth: .infinity).foregroundStyle(.white.opacity(0.8))
                    }.padding(20).background {
                        OverlayMaterialPreview(appearance: appearance, transparency: 0.35, frostAmount: 0.5)
                    }.clipShape(.rect(cornerRadius: 22))
                }.padding(16)
            }
        }.foregroundStyle(.white)
            .environment(\.lyricFrameRateLimit, 30)
            .background(WindowVisibilityReader { visible = $0 })
            .onScrollVisibilityChange(threshold: 0.1) { inViewport = $0 }
            .onDisappear { visible = false }
            .accessibilityLabel("功能示意预览，不会控制音乐播放器")
    }
}

/// Real settings, not disconnected demonstration toggles. Playback actions are
/// deliberately absent; merely opening the guide never changes preferences.
private struct GuideQuickSettings: View {
    let page: String
    @Bindable var preferences: Preferences
    let model: AppModel?
    private var available: Bool { ["main", "search", "overlay", "style", "text", "effects"].contains(page) }
    var body: some View {
        if available {
            VStack(alignment: .leading, spacing: 10) {
                Label("在这里设置", systemImage: "slider.horizontal.3").font(.headline)
                Text("可以直接调整，修改会自动保存。")
                    .font(.caption).foregroundStyle(.secondary)
                VStack(spacing: 0) { controls }
                    .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 14))
            }.padding(.top, 8)
        }
    }
    @ViewBuilder private var controls: some View {
        switch page {
        case "main":
            SettingToggle(title: "菜单栏图标", detail: "保留主窗口、歌词搜索和设置入口。", value: $preferences.showMenuBarIcon)
            SettingToggle(title: "菜单栏歌词", detail: "在屏幕顶部显示当前一句。", value: $preferences.showMenubarLyrics)
            SettingToggle(title: "合并图标与歌词", detail: "共用一个菜单栏位置。", value: $preferences.combinedMenubarLyrics)
                .disabled(!preferences.showMenuBarIcon || !preferences.showMenubarLyrics)
        case "overlay":
            SettingToggle(title: "显示悬浮窗", detail: "在其他窗口上方显示歌词；也可用 ⌥⌘L 切换。", value: Binding(
                get: { preferences.overlayVisible }, set: { value in
                    if let model { model.setOverlayVisible(value) } else { preferences.overlayVisible = value }
                }))
            SettingToggle(title: "锁定位置", detail: "关闭后可拖动；解锁会同时关闭点击穿透。", value: Binding(
                get: { preferences.overlayLocked }, set: { value in
                    if let model { model.setOverlayLocked(value) }
                    else { preferences.overlayLocked = value; if !value { preferences.overlayClickThrough = false } }
                }))
            SettingToggle(title: "点击穿透", detail: "点击歌词区域会操作下面的应用；开启时自动锁定位置，控制条仍可用。", value: Binding(
                get: { preferences.overlayClickThrough }, set: { value in
                    if let model { model.setOverlayClickThrough(value) }
                    else { preferences.overlayClickThrough = value; if value { preferences.overlayLocked = true } }
                }))
            SettingToggle(title: "鼠标经过时隐藏", detail: preferences.overlayLocked ? "经过歌词时暂时隐藏，离开后恢复。" : "先锁定位置才会生效；设置会保留。", value: $preferences.hideOverlayOnHover)
            SettingToggle(title: "暂停时隐藏", detail: "暂停播放后隐藏，继续播放后恢复。", value: $preferences.hideWhenPaused)
            SettingToggle(title: "自动调整高度", detail: "宽度保持固定，根据当前句换行调整高度。", value: $preferences.overlayAdaptiveSize)
        case "search":
            SettingToggle(title: "逐字优先", detail: "优先选择带逐字时间的版本，找不到时尝试双语。", value: $preferences.preferWordTiming)
            SettingToggle(title: "双语优先", detail: "优先带翻译的版本；两项同时打开时先逐字、后双语。", value: $preferences.preferBilingual)
            SettingToggle(title: "严格匹配", detail: "更重视歌名准确匹配。关闭后允许可信的别名与标题变体，但需留意同名歌。", value: $preferences.strictLyricsMatching)
            Divider().padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 6) {
                Text("歌词来源与排序").font(.body.weight(.medium))
                Text("用开关启用来源，用箭头调整顺序。越靠上越优先，也会参考歌曲匹配和你的偏好。")
                    .font(.callout).foregroundStyle(.secondary)
                Text("对当前歌曲应用新偏好，请在“设置 → 搜索”中重新搜索。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16)
            ForEach(preferences.sourceOrder, id: \.self) { source in
                HStack {
                    Text("\((preferences.sourceOrder.firstIndex(of: source) ?? 0) + 1)").monospacedDigit().foregroundStyle(.secondary)
                    Toggle(sourceTitle(source), isOn: Binding(get: { !preferences.disabledSources.contains(source) },
                        set: { preferences.setSource(source, enabled: $0) })).toggleStyle(.switch).controlSize(.small)
                    Button { preferences.moveSource(source, by: -1) } label: { Image(systemName: "chevron.up") }
                        .disabled(preferences.sourceOrder.first == source).accessibilityLabel("提高 " + sourceTitle(source) + " 的优先级")
                    Button { preferences.moveSource(source, by: 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(preferences.sourceOrder.last == source).accessibilityLabel("降低 " + sourceTitle(source) + " 的优先级")
                }.padding(.horizontal, 16).padding(.vertical, 10)
            }
        case "style":
            OverlayAppearancePicker(selection: $preferences.overlayAppearance, transparency: preferences.overlayTransparency,
                glassFrostAmount: preferences.overlayGlassFrostAmount, readingFrostAmount: preferences.overlayReadingFrostAmount)
        case "text":
            SettingToggle(title: "跟随封面主题色", detail: "自动生成已唱／未唱明暗配色；关闭恢复手动颜色。", value: $preferences.followArtworkColors)
            SettingToggle(title: "显示翻译", detail: "有译文时在主窗口与悬浮窗显示。", value: $preferences.showTranslation)
            SettingRow(title: "辅助内容", detail: "没有翻译时，“翻译或下一句”会显示下一句；“仅翻译”则不显示。") {
                Picker("辅助内容", selection: $preferences.overlaySecondaryMode) {
                    ForEach(OverlaySecondaryMode.allCases) { Text($0.title).tag($0) }
                }.labelsHidden().frame(width: 150)
            }
        case "effects":
            SettingToggle(title: "逐字轻微放大", detail: "需要歌词自带逐字时间。", value: $preferences.lyricWordLift)
            SettingToggle(title: "长音辉光", detail: "慢唱和长音渐进发光。减少动态效果时暂停。", value: $preferences.lyricGlow)
            SettingToggle(title: "减少动态效果", detail: "保留同步提亮，关闭位移与辉光；也遵循系统设置。", value: $preferences.reduceMotion)
        default:
            EmptyView()
        }
    }
    private func sourceTitle(_ id: String) -> String {
        ["NetEase": "网易云音乐", "QQMusic": "QQ 音乐", "Kugou": "酷狗音乐"][id] ?? id
    }
}
