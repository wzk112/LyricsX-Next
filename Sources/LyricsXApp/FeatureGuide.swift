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
        .init(id: "start", title: "连接音乐，自动同步歌词", subtitle: "从播放一首歌曲开始", symbol: "play.circle", points: [
            "打开 Apple Music、Spotify、网易云或 QQ 音乐播放歌曲，LyricsX Next 自动读取歌曲与进度；自动模式排除浏览器。",
            "其他音乐应用需向系统提供播放状态。若未识别，在设置 → 播放器指定来源或重新连接；macOS 询问自动化访问时按需允许。",
            "自动查询启用的歌词源并保存匹配结果。没有歌词或纯音乐时显示歌曲信息，前奏和句间等待显示三个点。"], illustration: "player"),
        .init(id: "main", title: "主窗口与菜单栏", subtitle: "歌词跟随真实播放进度", symbol: "text.quote", points: [
            "主窗口展示封面、歌词和翻译。点击歌词可跳转到该句，底部可播放、暂停、切歌和拖动进度。",
            "关闭主窗口后仍可使用悬浮歌词。菜单栏可显示图标、当前歌词或合并显示；设置 → 通用可调整 Dock 和登录启动。",
            "⌥⌘O 打开主窗口，⌥⌘L 显示或隐藏悬浮窗。关闭 Dock 与菜单栏入口后也能使用这些快捷键。"], illustration: "player"),
        .init(id: "search", title: "找到适合这首歌的版本", subtitle: "⌘F · 搜索歌词", symbol: "magnifyingglass", points: [
            "点击主窗口放大镜或按 ⌘F，修改歌名、歌手后搜索。候选结果逐步出现，可查看来源、匹配度、双语与逐字信息，再选择应用。",
            "完整搜索默认关闭；需要更多别名或版本时再开启，结果更多，等待也可能更久。无结果时检查网络或更换搜索词。",
            "设置 → 搜索可启用来源、排序、设置严格匹配与双语／逐字偏好。修改影响下一次搜索；当前歌曲可点“重新搜索”绕过已有缓存。"], illustration: "search"),
        .init(id: "overlay", title: "桌面上的悬浮歌词", subtitle: "宽度固定，高度随当前句调整", symbol: "rectangle.on.rectangle", points: [
            "悬浮窗放在其他窗口上方，长句自动换行并调整高度，顶部位置保持稳定。关闭自动高度后可手动修改宽度。",
            "解锁后拖动歌词区域移动；锁定避免误拖。点击穿透让点击传给后面的应用，开启时自动锁定；解锁会关闭穿透。",
            "鼠标经过隐藏只在锁定时生效，离开后恢复。可设置暂停时隐藏；右上控制条和菜单栏保留操作入口。"], illustration: "overlay"),
        .init(id: "style", title: "两种背景，按场景选择", subtitle: "Liquid Glass / 磨砂阅读", symbol: "square.on.square", points: [
            "Liquid Glass 保留通透和折射边缘；磨砂阅读柔化后方内容，提高复杂背景上的可读性。",
            "透明度越高越通透，磨砂越强背景越柔和。两种样式分别记住磨砂值；文字不会随背景一起模糊。",
            "系统开启“降低透明度”时使用实色背景。预览与实际窗口后方内容不同，效果也会不同。"], illustration: "style"),
        .init(id: "text", title: "字体、颜色与辅助内容", subtitle: "设置 → 歌词 · 实时预览", symbol: "textformat", points: [
            "选择本机字体，独立设置主窗口、悬浮窗原文和辅助行字号；缺少字形会使用系统后备字体。",
            "设置原文和辅助文字颜色，或为逐字歌词分别设置已唱与未唱颜色。简繁体转换只影响显示，保留逐字时间，不修改歌词文件。",
            "辅助内容可选仅翻译、仅下一句、翻译或下一句、两者同时显示或关闭。“翻译或下一句”在没有译文时显示下一句；翻译总开关同时影响两个窗口。"], illustration: "text"),
        .init(id: "effects", title: "逐字高亮与长音辉光", subtitle: "按歌词时间驱动，不自动猜测逐字时间", symbol: "sparkles", points: [
            "逐字歌词会随进度提亮，演唱中的词轻微放大。长音中的字符依次柔和起伏并渐进发光；普通行级歌词没有逐字效果。",
            "HDR／EDR 增强按当前屏幕可用余量限制亮度，普通屏幕自动回退。它不会修改系统亮度，也不代表屏幕有 HDR 面板认证。",
            "减少动态效果保留同步提亮，关闭位移和辉光。设置 → 开发者选项可选 60 帧或智能节能；隐藏的预览停止刷新。"], illustration: "effects"),
        .init(id: "timing", title: "校准同步，处理错误匹配", subtitle: "每首歌单独记住偏移", symbol: "slider.horizontal.3", points: [
            "歌词慢了，增加正偏移让它提前；歌词快了，使用负偏移让它延后。主窗口底部可按 0.1 秒调整，点偏移值重置。",
            "偏移会保存到当前歌词文件，下次播放继续使用。快捷键 ⌥⌘↑／↓ 以 0.2 秒调整。",
            "版本不对可手动搜索替换。菜单栏 → 歌词可停用此歌曲或专辑的自动搜索；需要时可恢复，开发者选项支持清空排除记录。"], illustration: "timing"),
        .init(id: "library", title: "本地歌词与资料库", subtitle: "保留已有文件，管理自己的版本", symbol: "books.vertical", points: [
            "工具栏书本图标打开歌词资料库。自动下载的歌词会缓存，之后优先复用；切歌不必每次重新联网。",
            "将 LRC / LRCX 拖入主窗口，或在菜单中导入，应用到当前歌曲。LRCX 可保留翻译和逐字时间；导出纯文本会去掉时间信息。",
            "开发者选项可以更换缓存目录、导出文件或写入 Apple Music。切换目录不会搬迁文件；导入会替换当前版本，写入音乐资料库可能覆盖原歌词。"], illustration: "library"),
        .init(id: "privacy", title: "数据、更新与帮助", subtitle: "随时在设置 → 关于重新查看", symbol: "info.circle", points: [
            "搜索会向启用的来源发送歌名、歌手和时长。Musixmatch 可选令牌保存在系统钥匙串；无需使用的来源可关闭。",
            "开发者选项集中放置文件与排除记录操作、令牌、帧率和显示诊断。普通使用无需修改这些项目。",
            "菜单栏可检查 GitHub 更新。每个新版本首次打开介绍新增和修复；同版本重启不再弹出。设置 → 关于可重看完整教程和版本介绍。"], illustration: "privacy")
    ]
    // Add new release entries here; a version jump includes every intervening
    // entry, while a first upgrade from versions without receipts gets a recap.
    static let releases: [(version: String, page: GuidePage)] = [
        ("2.0.34", .init(id: "r29", title: "启动与悬浮窗更可靠", subtitle: "稳定性修复", symbol: "rectangle.on.rectangle", points: ["悬浮窗无需先打开主窗口即可启动，菜单栏歌词恢复正常。", "歌词替换时重新测量高度；修复屏幕参数通知中断缩放，导致文字截断、必须鼠标经过才恢复的问题。"], illustration: "overlay")),
        ("2.0.34", .init(id: "r30", title: "歌词按你的习惯显示", subtitle: "新增自定义字体与配色", symbol: "textformat", points: ["自定义字体与原文、辅助行颜色，并可分别设置已唱和未唱颜色。", "改进封面与背景切歌过渡，修正自定义字体字号和对齐，恢复屏幕 EDR 辉光检测。"], illustration: "text")),
        ("2.0.34", .init(id: "r33", title: "减少重复工作", subtitle: "性能优化", symbol: "leaf", points: ["优化 QQ 歌词长文本的重复扫描，减少搜索时的 CPU 开销。缓存文件只读取一次，字体行高复用测量结果。", "播放器列表随应用启动、退出和唤醒更新；修复悬浮窗与计时器的释放，关闭资料库后清理文档与扫描。原有动效和帧率策略保留。", "长音字符依次起伏，平滑放大与回落；微小播放器时间抖动不再直接跳变高亮和辉光，设置图例提升为可见时 60 帧。"], illustration: "effects")),
        ("2.0.34", .init(id: "r34", title: "简繁转换保留逐字效果", subtitle: "本次修复 · 2.0.34", symbol: "character.book.closed", points: ["简体与繁体转换后保留每段逐字时间，继续显示逐字高亮、独立配色和长音辉光。", "转换只作用于显示，不改写歌词文件。主窗口与悬浮窗使用同一套修复。"], illustration: "conversion")),
        ("2.0.34", .init(id: "theme34", title: "歌词随封面变换主题色", subtitle: "新功能 · 设置 → 歌词", symbol: "paintpalette", points: ["主窗口背景保留更多封面颜色，偏暗封面补充同色系底色，减少灰黑感并保留平滑切换。", "另可开启“跟随封面主题色”：已唱与未唱使用同色系明暗对比，翻译使用浅色，保留逐字时间和长音辉光。", "无封面回退中性白色；关闭开关恢复手动配色。主题只在封面变化时提取，预览不会控制音乐。"], illustration: "theme")),
        ("2.0.34", .init(id: "settings34", title: "设置更清楚，预览更轻量", subtitle: "本次优化 · 2.0.34", symbol: "slider.horizontal.3", points: ["根据辅助文字模式显示相关字号，标明系统动效限制与登录启动状态。", "边栏统一图标与行距，展开／收起保持阅读列宽度，减少重排卡顿；修正链接并校验旧设置。", "新增完整教程和版本介绍，首次自动展示后可在“关于”重看。"], illustration: "settings"))
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
                Text("以下是应用的真实设置，修改后立即保存；不操作就保持原来的选择。")
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
                Text("越靠上越优先。开关决定是否参与搜索，箭头调整顺序；歌名匹配与版本偏好也会影响最终选择。")
                    .font(.callout).foregroundStyle(.secondary)
                Text("从下一次搜索生效，已有缓存继续复用。当前歌曲可在设置 → 搜索中重新搜索。")
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
            SettingRow(title: "辅助内容", detail: "“翻译或下一句”没有译文时显示下一句，“仅翻译”则不回退。") {
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
