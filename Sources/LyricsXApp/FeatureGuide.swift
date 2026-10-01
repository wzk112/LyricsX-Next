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
    let revision: String
    let existingInstallation: Bool
    init(defaults: UserDefaults = .standard, version: String = GuideContent.version, revision: String = GuideContent.revision) {
        self.defaults = defaults
        self.version = version
        self.revision = revision
        existingInstallation = ["compactOverlayVersion", "fixedOverlayWidthVersion", "overlayVisible",
            "overlayWidth", "overlayAppearance", "fontSize", "playerMode", "ModernLyricsDirectory",
            "guideLastVersion"].contains { defaults.object(forKey: $0) != nil }
    }
    var pending: Presentation? {
        guard !(defaults.stringArray(forKey: "guidePresentedEditions") ?? []).contains(version + ":" + revision) else { return nil }
        return existingInstallation ? .update(previous: defaults.string(forKey: "guideLastVersion")) : .tutorial
    }
    func didPresent() {
        var versions = defaults.stringArray(forKey: "guidePresentedVersions") ?? []
        if !versions.contains(version) { versions.append(version) }
        defaults.set(versions, forKey: "guidePresentedVersions")
        defaults.set(version, forKey: "guideLastVersion")
        var editions = defaults.stringArray(forKey: "guidePresentedEditions") ?? []
        let edition = version + ":" + revision
        if !editions.contains(edition) { editions.append(edition) }
        defaults.set(editions, forKey: "guidePresentedEditions")
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
    // Changed only when the introduction itself is revised, never for a routine rebuild.
    static let revision = "playback-controls-39"
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.39"
    static let tutorial: [GuidePage] = [
        .init(id: "start", title: "播放音乐，歌词自动出现", subtitle: "先播放一首歌", symbol: "play.circle", points: [
            "打开 Apple Music、Spotify、网易云或 QQ 音乐播放歌曲，即可自动同步歌词。自动识别不包含浏览器。",
            "没有识别到播放器？前往“设置 → 播放器”选择来源或重新连接。系统询问控制播放器的权限时，请允许。",
            "应用会自动搜索并保存歌词。等待歌词时显示三个点，纯音乐或没有歌词时显示歌曲信息。"], illustration: "player"),
        .init(id: "main", title: "主窗口与菜单栏", subtitle: "播放、切歌和查看歌词", symbol: "text.quote", points: [
            "点击歌词可跳到那一句；底部可以播放、暂停、切歌和拖动进度。在“设置 → 歌词 → 文字”可将主窗口当前歌词设为居中、上方或自定义百分比（5%–95%，越小越靠上），手动滚动后可返回正在唱的地方。",
            "关闭主窗口也能继续看悬浮歌词。菜单栏歌词、Dock 图标和登录启动，可在“设置 → 通用”调整。",
            "默认 ⌥⌘O 打开主窗口，⌥⌘L 显示或隐藏悬浮窗。在“设置 → 通用”可自定义或清除全局快捷键；清除后，可重新打开应用进入主窗口。"], illustration: "player"),
        .init(id: "search", title: "选择合适的歌词", subtitle: "点击放大镜，或按 ⌘F", symbol: "magnifyingglass", points: [
            "输入歌名或歌手，点“预览”查看效果，再点“应用当前歌词”使用。列表会保持打开，方便继续挑选。",
            "“完整搜索”会查找更多版本，但可能需要更久；平时保持关闭即可。",
            "下方可调整来源顺序、逐字或双语优先。改好后，对当前歌曲点“重新搜索”，即可重新选择。"], illustration: "search"),
        .init(id: "overlay", title: "把歌词放在桌面上", subtitle: "设置 → 悬浮窗", symbol: "rectangle.on.rectangle", points: [
            "悬浮窗显示在其他窗口上方，可随长句自动换行并平滑调整高度。关闭波形时歌词内容会在玻璃窗中居中；关闭自动高度后可手动调整宽度。",
            "解锁后拖动窗口，锁定后避免误拖。“点击穿透”让你直接操作后面的应用，并自动锁定位置。",
            "锁定时可开启“鼠标经过时隐藏”，离开后恢复。也可以选择暂停播放时隐藏。"], illustration: "overlay"),
        .init(id: "waveform", title: "可选的悬浮窗音频波形", subtitle: "设置 → 悬浮窗", symbol: "waveform", points: [
            "实时波形默认关闭。开启后可选择白色或封面彩色，波形沿悬浮窗底部显示。",
            "首次开启可能需要 macOS 系统音频录制权限。仅尝试读取当前识别播放器的音频；暂停、隐藏和减少动态效果时停止。",
            "这里显示固定的示意帧，打开指南不会读取音频。权限或音频不可用时，可在设置中查看状态并重试。"], illustration: "releaseWaveform38"),
        .init(id: "style", title: "选择喜欢的背景", subtitle: "两种材质，实时预览", symbol: "square.on.square", points: [
            "Liquid Glass 使用高透玻璃、原生亮边与边缘折射，保持统一外观；磨砂阅读可单独选择深色、浅色或跟随系统。",
            "Liquid Glass 的透明度调节用于减淡底色，保留完整折射；磨砂阅读还可调节磨砂强度。",
            "实际效果会随桌面背景变化。系统开启“降低透明度”时，会使用实色背景。"], illustration: "style"),
        .init(id: "fonts", title: "换上喜欢的字体", subtitle: "设置 → 歌词 → 字体与颜色", symbol: "textformat", points: [
            "选择此 Mac 已安装的字体，主窗口和悬浮窗会一起更换，下方可实时预览排版。",
            "主窗口、悬浮窗、翻译和下一句的字号可分别调整。缺少字符或字体被卸载时，会使用系统字体。",
            "点击“恢复字体与颜色”可回到默认外观。"], illustration: "font"),
        .init(id: "colors", title: "原文与辅助文字分别选色", subtitle: "设置 → 歌词 → 字体与颜色", symbol: "paintpalette", points: [
            "“当前歌词颜色”控制原文；“翻译与下一句颜色”控制辅助文字，两组颜色可分别设置。",
            "修改后立即生效并保存。Liquid Glass 使用自定义颜色或封面配色时不额外改色，恢复默认配色后自动优化可读性。",
            "若手动颜色选项变灰，请先关闭“跟随封面主题色”。"], illustration: "colors"),
        .init(id: "wordColors", title: "已唱与未唱，用不同颜色", subtitle: "设置 → 歌词 → 逐字独立配色", symbol: "character.cursor.ibeam", points: [
            "开启“逐字独立配色”，分别选择已唱到和未唱到的颜色，演唱进度会在两种颜色间推进。",
            "只对带逐字时间的歌词生效，仍保留轻微放大和长音辉光。普通逐行歌词使用原文颜色。",
            "关闭独立配色会恢复明暗高亮，已选的两种颜色会保留。"], illustration: "wordColors"),
        .init(id: "theme", title: "让歌词跟随封面配色", subtitle: "设置 → 歌词 → 跟随封面主题色", symbol: "photo", points: [
            "开启后从封面提取最多四种代表色：原文与辅助文字分别配色，已唱部分更明亮，未唱部分较暗。彩色波形使用多色渐变，切歌时自动更新。",
            "没有封面时使用中性配色。自动配色优先于手动颜色，但不会覆盖它们，关闭即可恢复。",
            "主窗口背景也会随封面变化。背景与歌词的配色分别处理，关闭歌词跟色不会关掉封面背景。"], illustration: "theme"),
        .init(id: "text", title: "翻译、下一句与简繁体", subtitle: "设置 → 歌词", symbol: "text.alignleft", points: [
            "开启“显示翻译”后，有译文的歌词会显示翻译。辅助内容还可选下一句或两者都显示。",
            "“翻译或下一句”会在没有翻译时显示下一句；“仅翻译”则留空。下一句换到当前句时会平滑上移。",
            "可选择原文、简体或繁体显示，简繁转换后仍保留逐字进度。"], illustration: "conversion"),
        .init(id: "effects", title: "让歌词随演唱亮起来", subtitle: "设置 → 动效", symbol: "sparkles", points: [
            "带逐字时间的歌词会依次提亮、轻微放大，慢唱和长音还会柔和发光。普通逐行歌词没有这些效果。",
            "EDR 辉光增强可让高光更亮，实际效果取决于屏幕。它不会改变系统亮度；不支持时使用普通辉光。",
            "喜欢安静的画面，可开启应用的“减少动态效果”；系统的同名设置也会生效，位移与辉光会停稳。在开发者选项中可选跟随屏幕（120 Hz 屏幕可请求 120 帧）、固定 60 帧或智能节能；实际帧率由系统决定。"], illustration: "effects"),
        .init(id: "timing", title: "让歌词与音乐对齐", subtitle: "每首歌都会记住调整", symbol: "slider.horizontal.3", points: [
            "歌词慢了，用正偏移提前；歌词快了，用负偏移延后。底部每次调整 0.1 秒，点击数值即可重置。",
            "也可用 ⌥⌘↑／↓ 每次调整 0.2 秒。调整会保存，下次播放无需重设。",
            "歌词版本不对时可重新搜索。菜单栏 → 歌词还可以停用某首歌或整张专辑的搜索，需要时再恢复。"], illustration: "timing"),
        .init(id: "library", title: "使用自己的歌词文件", subtitle: "点击书本图标打开资料库", symbol: "books.vertical", points: [
            "下载过的歌词会保存在本地，下次播放优先使用。资料库可以查看已有歌词。",
            "把 LRC 或 LRCX 文件拖入主窗口，即可替换当前歌词。LRCX 可保留翻译和逐字效果；导出纯文本则不保留时间。",
            "更换保存位置、导出和写入 Apple Music 等操作在开发者选项中。更换位置不会自动搬移文件；写入 Apple Music 可能覆盖原歌词。"], illustration: "library"),
        .init(id: "flexbar", title: "可选的 Flexbar 歌词", subtitle: "设置 → 开发者选项 → Flexbar", symbol: "rectangle.on.rectangle", points: [
            "需要另行安装并配置 FlexDesigner 歌词插件，然后在开发者选项中开启 Flexbar 连接。普通歌词和悬浮窗不需要此功能。",
            "插件可显示逐字歌词与翻译；这里展示插件渲染器生成的图片，不代表设备上的实际显示帧率或亮度。",
            "暂停、隐藏或没有歌词时会减少更新。设备与插件的实际表现可能不同。"], illustration: "releaseFlexbar38"),
        .init(id: "privacy", title: "帮助与更新", subtitle: "设置 → 关于，可随时重看", symbol: "info.circle", points: [
            "搜索时会向启用的歌词来源发送歌名、歌手和时长。不需要的来源可在设置中关闭。",
            "实时波形需在“设置 → 悬浮窗”主动开启，首次使用可能请求系统音频录制权限；打开本指南不会采集音频。开发者选项包含文件管理、来源令牌、帧率与可选 Flexbar 连接。来源令牌保存在系统钥匙串中。",
            "菜单栏可以检查更新。教程和更新介绍只自动显示一次，以后可在“设置 → 关于”重新查看。"], illustration: "privacy")
    ]
    // Add new release entries here; a version jump includes every intervening
    // entry, while a first upgrade from versions without receipts gets a recap.
    static let releases: [(version: String, page: GuidePage)] = release39Pages.map { ("2.0.39", $0) } + [
        ("2.0.38", .init(id: "waveform38", title: "悬浮窗音频波形", subtitle: "新增 · 设置 → 悬浮窗", symbol: "waveform", points: [
            "在“设置 → 悬浮窗”可开启实时音频波形，选择白色或封面彩色；默认关闭，不会因升级自动开始采集。",
            "首次开启时 macOS 可能请求系统音频录制权限。波形仅尝试读取当前识别播放器的音频，暂停、隐藏或减少动态效果时停止。",
            "权限未获准或没有可用音频时会安静停用；可在设置中查看状态并手动重试。不同播放器和设备的实际效果可能不同。"], illustration: "releaseWaveform38")),
        ("2.0.38", .init(id: "overlay38", title: "悬浮歌词排版更协调", subtitle: "改进 · 居中与窗口运动", symbol: "rectangle.on.rectangle", points: [
            "关闭波形时，歌词可见内容与纯音乐歌卡在玻璃窗中居中；开启波形时，歌卡上下留白更均衡。",
            "窗口高度随内容平滑调整，顶部标题固定在玻璃窗内；鼠标经过隐藏和恢复时，整窗一起淡入淡出。",
            "系统或应用开启“减少动态效果”后，进行中的位移、淡入淡出会尽快停稳。"], illustration: "releaseOverlay38")),
        ("2.0.38", .init(id: "mainMotion38", title: "歌词滚动与换句动画", subtitle: "改进 · 主窗口与动效", symbol: "text.quote", points: [
            "主窗口的歌词跟随和搜索预览滚动更贴合播放进度；切歌、跳播及文档切换时减少不必要的滑动。",
            "收敛旧歌词退场的上移和模糊，主窗口与悬浮窗的动效同时遵循系统和应用的减少动态效果设置。",
            "歌卡按歌名与歌手的实际行高调整，长标题换行时继续留出必要空间。"], illustration: "livePlayer")),
        ("2.0.38", .init(id: "performanceFlexbar38", title: "刷新优化与 Flexbar 连接", subtitle: "改进 · 设置 → 开发者选项", symbol: "gauge.with.dots.needle.33percent", points: [
            "菜单栏歌词按下一句时间更新；暂停、隐藏或没有可用音频时减少不必要的持续刷新。",
            "“开发者选项”可开启 Flexbar 歌词连接，需要另行安装并配置 FlexDesigner 插件；实际显示效果取决于设备与插件。",
            "已有歌词、偏移、字体和悬浮窗设置继续保留。本次更新介绍只自动显示一次，以后可在“设置 → 关于”重看。"], illustration: "releaseFlexbar38")),
        ("2.0.37", .init(id: "glassHDR37", title: "玻璃歌词，高亮更到位", subtitle: "修复 · HDR 与长音辉光", symbol: "sparkles", points: [
            "修复 Liquid Glass 悬浮窗的 HDR 高亮偏暗、调高亮度后变化不明显的问题。",
            "默认配色、逐字独立配色和跟随封面颜色都能正确使用高亮，实际亮度仍由屏幕和系统决定。",
            "长音外围光晕适度收紧，保留逐字放大和发光效果。已有设置与歌词缓存继续保留。"], illustration: "liveGlass")),
        ("2.0.36", .init(id: "glassColor36", title: "玻璃歌词配色，由你选择", subtitle: "新增 · 悬浮窗与歌词颜色", symbol: "paintpalette", points: [
            "Liquid Glass 使用默认配色时自动优化可读性，无需手动开关。",
            "使用自定义颜色、逐字独立配色或跟随封面时，按当前配色原样显示，不再额外调整颜色。",
            "恢复默认配色后自动恢复优化。主窗口和磨砂阅读沿用原有配色方式，已有颜色设置继续保留。"], illustration: "liveGlass")),
        ("2.0.35", .init(id: "glass35", title: "更通透的 Liquid Glass", subtitle: "更新 · 悬浮窗材质", symbol: "square.on.square", points: [
            "换用高透原生玻璃，边缘亮光与背景折射更清晰；保留磨砂阅读，适合背景复杂时使用。",
            "透明度只调整玻璃底色，不会削弱折射亮边。新安装默认 60%；升级会保留并换算原有设置。",
            "这里使用与应用相同的歌词和材质渲染。也可以打开独立悬浮窗，放到自己的桌面背景上比较。"], illustration: "liveGlass")),
        ("2.0.35", .init(id: "appearance35", title: "深浅外观，分别设置", subtitle: "新增 · 通用与悬浮窗设置", symbol: "circle.lefthalf.filled", points: [
            "主窗口与设置可选择深色、浅色或跟随系统；磨砂悬浮窗可以单独设置。Liquid Glass 保持统一的高透外观。",
            "优化浅色背景、自定义配色和封面配色的可读性，让已唱与未唱的文字更容易区分。",
            "调整设置页比例与间距；切换材质或外观时，减少底色残留和透明度没有更新的问题。"], illustration: "liveAppearance")),
        ("2.0.35", .init(id: "motion35", title: "切歌时，界面保持稳定", subtitle: "修复 · 排版与动画", symbol: "waveform", points: [
            "固定主窗口进度条与播放按钮的位置，长短歌名切换、专辑信息补全和歌词加载时不再下沉回弹。",
            "保留封面与文字的模糊过渡，改善悬浮窗高度变化、下一句上移和逐字动画的连贯性。",
            "按屏幕刷新时刻绘制，减少帧间抖动；隐藏的演示停止刷新，避免额外后台开销。"], illustration: "livePlayer")),
        ("2.0.35", .init(id: "highlight35", title: "辉光与窗口恢复", subtitle: "改进 · 长音与 EDR", symbol: "sparkles", points: [
            "增强普通亮度下的长音辉光；支持 EDR 的屏幕会根据可用亮度显示更亮的高光。",
            "主窗口和悬浮窗分别维持高亮输出，改善关闭主窗口、隐藏后恢复时的高亮；悬浮窗的外围光晕更收敛。",
            "亮度可按 1–4× 调节或直接输入，显示屏幕当前可用上限，并提供真实亮度对比预览。实际高亮仍由屏幕与系统决定。"], illustration: "liveGlow")),
        ("2.0.35", .init(id: "upgrade35", title: "升级后，原有设置继续使用", subtitle: "兼容 · 设置与更新介绍", symbol: "checkmark.circle", points: [
            "保留字体、颜色、歌词来源、偏移和悬浮窗位置。两种材质分别记住参数，无需重新设置。",
            "本次介绍会在升级后首次打开时自动出现，关闭后不再重复。新安装仍显示完整教程。",
            "以后在“设置 → 关于”可重看教程或本次更新；关闭介绍会回到原来的窗口。"], illustration: "liveGlass")),
        ("2.0.34", .init(id: "font34", title: "自定义字体与实时预览", subtitle: "新增 · 设置 → 歌词", symbol: "textformat", points: [
            "选择本机字体，主窗口与悬浮窗一起更换；原文、翻译和下一句的字号可分别调整。",
            "设置里可实时查看排版，也能一键恢复默认字体与颜色。缺少字符时自动使用系统字体。"], illustration: "font")),
        ("2.0.34", .init(id: "color34", title: "原文与辅助文字分别选色", subtitle: "新增 · 设置 → 歌词 → 字体与颜色", symbol: "paintpalette", points: [
            "自定义原文颜色，以及翻译与下一句的颜色，两个窗口同步生效并自动保存。",
            "保留逐字明暗高亮和长音辉光。预览中可以直接检查配色是否清楚。"], illustration: "colors")),
        ("2.0.34", .init(id: "word34", title: "逐字歌词，两种颜色", subtitle: "新增 · 设置 → 歌词 → 逐字独立配色", symbol: "character.cursor.ibeam", points: [
            "分别设置已唱到、未唱到的颜色；演唱中的文字仍会逐个提亮、柔和放大。需要歌词自带逐字时间。",
            "关闭后恢复原来的明暗高亮，并保留已选颜色。翻译和下一句仍使用辅助文字颜色。"], illustration: "wordColors")),
        ("2.0.34", .init(id: "theme34", title: "跟随封面，自动换色", subtitle: "新增 · 设置 → 歌词 → 跟随封面主题色", symbol: "photo", points: [
            "从当前歌曲封面提取歌词配色，用明暗区分已唱与未唱；切歌时自动更新，无封面时用中性色。",
            "自动配色不会覆盖手动颜色，关闭即可恢复。主窗口背景取色也更鲜明，减少灰黑感。"], illustration: "theme")),
        ("2.0.34", .init(id: "search34", title: "先预览，再应用歌词", subtitle: "新增 · 放大镜或 ⌘F", symbol: "magnifyingglass", points: [
            "点“预览”，右侧按实际播放进度显示歌词和翻译，不替换正式歌词，也不保存。",
            "满意后点“应用当前歌词”。列表保持打开，可继续比较版本；点“完成”才关闭。",
            "修复应用后马上消失的问题。手动应用会恢复这首歌的显示，切歌后旧结果不能误用到新歌。"], illustration: "search")),
        ("2.0.34", .init(id: "settings34", title: "设置更清楚、更好操作", subtitle: "改进 · 设置", symbol: "slider.horizontal.3", points: [
            "重新整理侧栏、图标与说明，收起或展开侧栏时，右侧内容保持稳定。",
            "相关选项按开关状态显示，例如逐字颜色和辅助字号。文件管理、来源令牌与性能选项集中在开发者选项。"], illustration: "settings")),
        ("2.0.34", .init(id: "guide34", title: "完整教程，随时重看", subtitle: "新增 · 设置 → 关于", symbol: "book.closed", points: [
            "首次安装会介绍播放器、搜索、悬浮窗、字体颜色、动效、同步和文件管理；教程里可直接调整常用设置。",
            "更新后只介绍新增功能与改进，之后不重复弹出。“关于”中可重看“使用指南”或“本次更新”。"], illustration: "guide")),
        ("2.0.34", .init(id: "overlay34", title: "悬浮窗与菜单栏更稳定", subtitle: "修复 · 启动、换行与字体", symbol: "rectangle.on.rectangle", points: [
            "启动后即可显示悬浮窗，修复菜单栏歌词不显示的问题。关闭或最小化主窗口时，悬浮歌词更顺畅。",
            "修复切歌、更换歌词后高度更新不及时和文字被截断的问题；更换字体后保持字号、对齐与行距。"], illustration: "overlay")),
        ("2.0.34", .init(id: "playback34", title: "逐字与切歌更顺畅", subtitle: "改进 · 动画与资源占用", symbol: "waveform", points: [
            "改善逐字放大缩小、长音辉光，以及封面、背景和歌词的切歌过渡，减少卡顿与闪动。",
            "悬浮窗的下一句从原位平滑上移，上一句向上模糊淡出；普通歌词与逐字歌词都适用。",
            "减少重复取色、字体测量、文件读取和后台绘制；关闭窗口后释放不再使用的内容，保留现有动效。"], illustration: "effects")),
        ("2.0.34", .init(id: "compatibility34", title: "这些小问题也修好了", subtitle: "修复 · 简繁体、辉光与搜索", symbol: "checkmark.circle", points: [
            "简繁体转换后仍能显示逐字进度。自定义颜色保留 EDR 辉光，改善窗口首次显示时的屏幕能力识别。",
            "改善部分 QQ 音乐歌词的读取、搜索与封面显示；修复缓存文件变化及异常设置值引起的显示问题。"], illustration: "conversion"))
    ]
    // Current release pages are also included in the numbered history above.
    // An upgrade from 2.0.38 displays only these four pages.
    static let release39Pages: [GuidePage] = [
        .init(id: "position39", title: "主歌词位置", subtitle: "新增 · 设置 → 歌词 → 主窗口当前歌词位置", symbol: "text.aligncenter", points: [
            "当前句可选择居中或上方。第一句尚未开始、首尾歌词、长句和翻译均按所选位置对齐。",
            "手动浏览后，点击“回到当前歌词”会平滑回到当前句；重新打开窗口或改变排版时直接对齐。",
            "下方可修改实际设置；示意区使用独立播放会话，不改变正在播放的歌曲。"], illustration: "livePlayer"),
        .init(id: "hotkeys39", title: "自定义全局快捷键", subtitle: "新增 · 设置 → 通用 → 快捷键", symbol: "keyboard", points: [
            "可录制显示悬浮窗和打开主窗口的快捷键，也可清除或恢复默认。保存后立即生效。",
            "重复组合、无效组合或系统注册失败会显示原因；清除后不再占用该组合。",
            "下方使用正式快捷键设置组件，修改会自动保存。"], illustration: "liveHotkeys"),
        .init(id: "colors39", title: "封面多色配色", subtitle: "改进 · 设置 → 歌词 → 跟随封面主题色", symbol: "paintpalette", points: [
            "封面保留最多四种代表色，原文与辅助歌词分别配色；彩色音频波形使用多色渐变。",
            "改善小面积点缀色、半透明封面和暗色波形；灰阶或无封面时使用中性配色。",
            "波形开关与白色／彩色选项在“设置 → 悬浮窗”；此处不会启动音频采集。"], illustration: "liveTheme"),
        .init(id: "transitions39", title: "切歌与窗口过渡", subtitle: "修复 · 自动生效；设置 → 动效可减少动态效果", symbol: "text.quote", points: [
            "快速加载的歌词直接交接，减少短暂显示标题；新歌词模糊淡入后变清晰，同一首歌的候选升级不重复播放动画。",
            "封面加载共用有限等待期限，旧歌曲的异步结果不会覆盖新歌；尚未加载完成时减少默认封面闪动。",
            "恢复播放时同时缩短后续播放器轮询，避免进度和两个歌词窗口等候旧的暂停轮询期限。",
            "调整主窗口大小时复用封面背景，结束后更新尺寸，同一封面不重复播放背景淡入淡出。",
            "修复鼠标经过隐藏歌词后，暂停播放仍残留右上角控制条的问题。“暂停时隐藏”在设置 → 悬浮窗。",
            "关闭主窗口后停止主窗口绘制，悬浮窗继续更新；快捷键、Dock 和菜单栏可重开原窗口，重新对齐当前歌词。"], illustration: "livePlayer")
    ]
    static func displayUpdates(after previous: String?) -> [GuidePage] {
        updates(after: previous)
    }
    // The previous public version defines the manual current-release introduction.
    static let latestBaseline: String? = "2.0.38"
    static func updates(after previous: String?) -> [GuidePage] {
        let pages = releases.filter { entry in
            guard let previous else { return true }
            return entry.version.compare(previous, options: .numeric) == .orderedDescending
        }.map(\.page)
        return pages.isEmpty ? releases.filter { $0.version == version }.map(\.page) : pages
    }
}

@MainActor final class FeatureGuideController: NSObject, NSWindowDelegate {
    let history: GuideHistory
    weak var preferences: Preferences?
    weak var model: AppModel?
    private(set) var window: NSWindow?
    private weak var returnWindow: NSWindow?
    private var automaticPresentationTask: Task<Void, Never>?
    init(history: GuideHistory = GuideHistory()) { self.history = history }

    /// Wait until SwiftUI has installed its scenes before presenting the
    /// first-run window. Creating an AppKit window directly from
    /// applicationDidFinishLaunching can leave it ordered behind a later
    /// SwiftUI window until the user opens another window.
    func scheduleAutomaticPresentation() {
        guard history.pending != nil, automaticPresentationTask == nil else { return }
        automaticPresentationTask = Task { @MainActor [weak self] in
            await Task.yield()
            // The SwiftUI Window scene is installed after the application
            // delegate finishes launching. Wait for that real host window so
            // it cannot subsequently cover the guide. A bounded fallback also
            // supports menu-bar-only launches.
            for _ in 0..<20 {
                guard !Task.isCancelled else { return }
                let hostIsReady = NSApp.windows.contains {
                    $0.isVisible && $0.level == .normal && $0.styleMask.contains(.titled)
                }
                if hostIsReady { break }
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard !Task.isCancelled, let self else { return }
            self.automaticPresentationTask = nil
            self.showAutomaticIfNeeded()
        }
    }

    func cancelScheduledPresentation() {
        automaticPresentationTask?.cancel()
        automaticPresentationTask = nil
    }

    func showAutomaticIfNeeded() {
        guard let pending = history.pending else { return }
        guard present(pending, automatic: true) else { return }
        // Record only after constructing and ordering the visible window.
        history.didPresent()
    }

    func show(_ mode: GuideHistory.Presentation) {
        // A manual replay never consumes the automatic receipt. If it races
        // cold launch, leave the receipt for the next launch rather than
        // replacing what the user explicitly opened.
        cancelScheduledPresentation()
        _ = present(mode, automatic: false)
    }

    @discardableResult
    private func present(_ mode: GuideHistory.Presentation, automatic: Bool) -> Bool {
        if automatic, window != nil { return false }
        let previousWindow = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.orderedWindows.first {
            $0 !== window && $0.isVisible && $0.level == .normal
        }
        if let previousWindow, previousWindow !== window, previousWindow.isVisible {
            returnWindow = previousWindow
        }
        if window == nil {
            let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 920, height: 700),
                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.tabbingMode = .disallowed
            window.minSize = .init(width: 800, height: 640)
            window.delegate = self
            window.center()
            self.window = window
        }
        window?.title = mode == .tutorial ? "LyricsX Next · 使用指南" : "LyricsX Next · 版本介绍"
        window?.contentView = NSHostingView(rootView: FeatureGuideView(mode: mode, preferences: preferences, model: model, close: { [weak self] in self?.close() }))
        // Activate first, then force this dedicated window to the front. This
        // is independent from Settings and the motion/search preview scenes.
        NSApp.activate()
        window?.orderFrontRegardless()
        window?.makeKey()
        return window?.isVisible == true
    }

    func close() {
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow, closingWindow === window else { return }
        // Release previews/display links even though the controller is retained.
        closingWindow.contentView = nil
        window = nil
        let destination = returnWindow
        returnWindow = nil
        DispatchQueue.main.async {
            guard let destination, destination.isVisible else { return }
            destination.makeKeyAndOrderFront(nil)
        }
    }
}

struct FeatureGuideView: View {
    let mode: GuideHistory.Presentation
    let preferences: Preferences?
    let model: AppModel?
    let close: () -> Void
    @State private var index = 0
    @State private var scrollHeight: CGFloat = 600
    init(mode: GuideHistory.Presentation, initialPage: Int = 0, preferences: Preferences? = nil, model: AppModel? = nil, close: @escaping () -> Void) {
        self.mode = mode
        self.preferences = preferences
        self.model = model
        self.close = close
        let count: Int
        if case .update(let previous) = mode { count = GuideContent.displayUpdates(after: previous).count }
        else { count = GuideContent.tutorial.count }
        _index = State(initialValue: min(max(0, initialPage), max(0, count - 1)))
    }
    private var pages: [GuidePage] {
        if case .update(let previous) = mode { return GuideContent.displayUpdates(after: previous) }
        return GuideContent.tutorial
    }
    var body: some View {
        GeometryReader { guideSize in
          HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Label("LyricsX Next", systemImage: "quote.bubble.fill").font(.headline)
                Text(mode == .tutorial ? "使用指南" : "\(GuideContent.version) · 本次更新")
                    .font(.title3.weight(.semibold))
                ScrollViewReader { navigation in
                    ScrollView {
                        VStack(spacing: 5) {
                            ForEach(Array(pages.enumerated()), id: \.element.id) { item in
                                Button { index = item.offset } label: {
                                    Label(item.element.title, systemImage: item.element.symbol)
                                        .font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10).background(index == item.offset ? Color.accentColor.opacity(0.14) : .clear,
                                                                in: .rect(cornerRadius: 10))
                                }.buttonStyle(.plain).accessibilityAddTraits(index == item.offset ? .isSelected : [])
                                    .id(item.element.id)
                            }
                        }
                    }.onChange(of: index, initial: true) { _, value in
                        navigation.scrollTo(pages[value].id)
                    }
                }
                Text("无需登录 · 设置自动保存").font(.caption).foregroundStyle(.secondary)
            }.padding(16).frame(width: guideSize.size.width < 900 ? 184 : 205).background(.quaternary.opacity(0.25))
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    let page = pages[min(index, pages.count - 1)]
                    VStack(alignment: .leading, spacing: 14) {
                        Text(page.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        Text(page.title).font(.system(size: guideSize.size.width < 900 ? 24 : 27, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                        Group {
                            if page.illustration == "liveHotkeys", let preferences {
                                HotkeySettingsView(settings: preferences.globalHotkeys)
                            } else if page.illustration == "releaseWaveform38" {
                                GuideReleaseVisual(kind: .waveform38)
                                    .frame(height: min(230, max(185, guideSize.size.height * 0.36)))
                            } else if page.illustration == "releaseOverlay38" {
                                GuideReleaseVisual(kind: .overlay38)
                                    .frame(height: min(230, max(185, guideSize.size.height * 0.36)))
                            } else if page.illustration == "releaseFlexbar38" {
                                GuideReleaseVisual(kind: .performanceFlexbar38)
                                    .frame(height: min(230, max(185, guideSize.size.height * 0.36)))
                            } else if page.illustration.hasPrefix("live") || ["style", "overlay"].contains(page.illustration) {
                                GuideLiveDemo(kind: page.illustration, reduced: preferences?.reduceMotion == true, viewportHeight: scrollHeight,
                                    mainPosition: page.id == "position39" ? preferences?.mainLyricPosition : nil,
                                    mainCustomPercent: page.id == "position39" ? preferences?.mainLyricCustomPercent : nil)
                                    .frame(height: min(300, max(230, guideSize.size.height * 0.43)))
                            } else {
                                GuideIllustration(kind: page.illustration, appReduced: preferences?.reduceMotion == true)
                                    .frame(height: min(190, max(155, guideSize.size.height * 0.29)))
                            }
                        }.id(page.id).clipShape(.rect(cornerRadius: 20))
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
                    }.padding(guideSize.size.width < 900 ? 18 : 26)
                }.id(index)
                    .coordinateSpace(name: "guideContent")
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { scrollHeight = $0 }
                Divider()
                HStack {
                    Button("稍后再看", action: close)
                    Spacer()
                    Text("\(index + 1) / \(pages.count)").monospacedDigit().foregroundStyle(.secondary)
                    Button("上一步") { index -= 1 }.disabled(index == 0)
                    Button(index == pages.count - 1 ? "开始使用" : "下一步") {
                        if index == pages.count - 1 { close() } else { index += 1 }
                    }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }.padding(.horizontal, 16).padding(.vertical, 12)
            }
          }
        }.frame(minWidth: 800, minHeight: 600).background(.background)
            .preferredColorScheme(preferences?.appTheme.colorScheme)
    }
}

/// Real settings, not disconnected demonstration toggles. Playback actions are
/// deliberately absent; merely opening the guide never changes preferences.
private struct GuideQuickSettings: View {
    let page: String
    @Bindable var preferences: Preferences
    let model: AppModel?
    private var available: Bool { ["main", "search", "overlay", "style", "text", "theme", "effects", "waveform", "waveform38", "performanceFlexbar38", "flexbar", "position39", "colors39", "transitions39"].contains(page) }
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
        case "waveform", "waveform38":
            SettingToggle(title: "显示实时波形", detail: "开启后才尝试采集当前播放器音频，首次可能请求 macOS 系统音频录制权限。", value: $preferences.overlayWaveformEnabled)
            SettingRow(title: "波形颜色", detail: "白色或封面多色渐变，沿悬浮窗底部显示。") {
                Picker("波形颜色", selection: $preferences.overlayWaveformStyle) {
                    ForEach(OverlayWaveformStyle.allCases) { Text($0.title).tag($0) }
                }.labelsHidden().frame(width: 140)
            }.disabled(!preferences.overlayWaveformEnabled)
            if !preferences.overlayWaveformStatus.isEmpty {
                SettingRow(title: "音频采集", detail: preferences.overlayWaveformStatus) {
                    Button("重试") { model?.overlay?.retryWaveform() }.disabled(model == nil)
                }
            }
        case "flexbar", "performanceFlexbar38":
            SettingToggle(title: "在 Flexbar 上显示歌词", detail: "需要另行安装和配置 FlexDesigner 歌词插件。入口在设置 → 开发者选项 → Flexbar。", value: $preferences.flexbarEnabled)
        case "position39":
            MainLyricPositionSettings(preferences: preferences)
        case "transitions39":
            SettingToggle(title: "减少动态效果", detail: "停止模糊和位移过渡；系统的同名设置也会生效。", value: $preferences.reduceMotion)
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
            OverlayAppearancePicker(selection: $preferences.overlayAppearance, transparency: preferences.overlayTransparency, glassTintTransparency: preferences.overlayGlassTintTransparency,
                readingFrostAmount: preferences.overlayReadingFrostAmount)
        case "theme", "colors39":
            SettingToggle(title: "跟随封面主题色", detail: "自动生成已唱／未唱明暗配色；关闭恢复手动颜色。", value: $preferences.followArtworkColors)
        case "text":
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
