import SwiftUI
import Observation
import ServiceManagement
import Security
import LyricsXServices

@Observable @MainActor
final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored nonisolated let sourceConfigurationReader: SourceConfigurationReader
    var overlayVisible: Bool { didSet { save("overlayVisible", overlayVisible) } }
    var overlayLocked: Bool { didSet { save("overlayLocked", overlayLocked) } }
    var overlayClickThrough: Bool { didSet { save("overlayClickThrough", overlayClickThrough) } }
    var hideOverlayOnHover: Bool { didSet { save("hideOverlayOnHover", hideOverlayOnHover) } }
    var overlayAppearance: OverlayAppearance { didSet { save("overlayAppearance", overlayAppearance.rawValue) } }
    var overlayTransparency: Double { didSet { save("overlayTransparency", overlayTransparency) } }
    var overlayGlassFrostAmount: Double { didSet { save("overlayGlassFrostAmount", overlayGlassFrostAmount) } }
    var overlayReadingFrostAmount: Double { didSet { save("overlayReadingFrostAmount", overlayReadingFrostAmount) } }
    var overlayFrostAmount: Double {
        get { overlayAppearance == .glass ? overlayGlassFrostAmount : overlayReadingFrostAmount }
        set {
            let amount = overlayAppearance.clampedFrost(newValue)
            if overlayAppearance == .glass { overlayGlassFrostAmount = amount }
            else { overlayReadingFrostAmount = amount }
        }
    }
    var overlayWidth: Double { didSet { save("overlayWidth", overlayWidth) } }
    var overlayAdaptiveSize: Bool { didSet { save("overlayAdaptiveSize", overlayAdaptiveSize) } }
    var overlayFrameRate: OverlayFrameRate { didSet { save("overlayFrameRate", overlayFrameRate.rawValue) } }
    var fontSize: Double { didSet { save("fontSize", fontSize) } }
    var lyricFontName: String { didSet { save("lyricFontName", lyricFontName) } }
    var lyricPrimaryColor: String { didSet { save("lyricPrimaryColor", lyricPrimaryColor) } }
    var lyricSecondaryColor: String { didSet { save("lyricSecondaryColor", lyricSecondaryColor) } }
    var followArtworkColors: Bool { didSet { save("followArtworkColors", followArtworkColors) } }
    // Derived display state only. Never overwrite the user's saved palette.
    var artworkTheme: ArtworkTheme?
    var separateWordColors: Bool { didSet { save("separateWordColors", separateWordColors) } }
    var sungWordColor: String { didSet { save("sungWordColor", sungWordColor) } }
    var unsungWordColor: String { didSet { save("unsungWordColor", unsungWordColor) } }
    var typography: LyricTypography {
        if followArtworkColors {
            let theme = artworkTheme ?? .neutral
            return .init(fontName: lyricFontName, primaryHex: theme.sung, secondaryHex: theme.secondary,
                wordColors: .init(sung: LyricTypography.color(theme.sung), unsung: LyricTypography.color(theme.unsung), plain: LyricTypography.color(theme.sung)))
        }
        return .init(fontName: lyricFontName, primaryHex: lyricPrimaryColor, secondaryHex: lyricSecondaryColor,
            wordColors: separateWordColors ? .init(sung: LyricTypography.color(sungWordColor), unsung: LyricTypography.color(unsungWordColor), plain: LyricTypography.color(lyricPrimaryColor)) : nil)
    }
    var translationFontSize: Double { didSet { save("translationFontSize", translationFontSize) } }
    var nextLineFontSize: Double { didSet { save("nextLineFontSize", nextLineFontSize) } }
    var overlaySecondaryMode: OverlaySecondaryMode { didSet { save("overlaySecondaryMode", overlaySecondaryMode.rawValue) } }
    var mainLyricFontSize: Double { didSet { save("mainLyricFontSize", mainLyricFontSize) } }
    var mainTranslationFontSize: Double { didSet { save("mainTranslationFontSize", mainTranslationFontSize) } }
    var showTranslation: Bool { didSet { save("showTranslation", showTranslation) } }
    var showMenubarLyrics: Bool { didSet { save("showMenubarLyrics", showMenubarLyrics) } }
    var showMenuBarIcon: Bool { didSet { save("showMenuBarIcon", showMenuBarIcon) } }
    var showDockIcon: Bool { didSet { save("showDockIcon", showDockIcon) } }
    var combinedMenubarLyrics: Bool { didSet { save("combinedMenubarLyrics", combinedMenubarLyrics) } }
    var blockedTracks: [String] { didSet { save("blockedTracks", blockedTracks) } }
    var blockedAlbums: [String] { didSet { save("blockedAlbums", blockedAlbums) } }
    var hideWhenPaused: Bool { didSet { save("hideWhenPaused", hideWhenPaused) } }
    var reduceMotion: Bool { didSet { save("reduceMotion", reduceMotion) } }
    var lyricWordLift: Bool { didSet { save("lyricWordLift", lyricWordLift) } }
    var lyricGlow: Bool { didSet { save("lyricGlow", lyricGlow) } }
    var lyricHDR: Bool { didSet { save("lyricHDR", lyricHDR) } }
    var lyricHDRBrightness: Double { didSet { save("lyricHDRBrightness", lyricHDRBrightness) } }
    var lyricEmphasis: LyricEmphasisOptions { .init(lift: lyricWordLift, glow: lyricGlow, hdr: lyricHDR,
        hdrBrightness: lyricHDRBrightness, reduced: reduceMotion) }
    var conversion: String { didSet { save("conversion", conversion) } }
    var playerMode: PlayerMode { didSet { save("playerMode", playerMode.rawValue) } }
    var disabledSources: [String] { didSet { save("disabledSources", disabledSources) } }
    var sourceOrder: [String] { didSet { save("sourceOrder", sourceOrder) } }
    var preferBilingual: Bool { didSet { save("preferBilingual", preferBilingual) } }
    var preferWordTiming: Bool { didSet { save("preferWordTiming", preferWordTiming) } }
    var strictLyricsMatching: Bool { didSet { save("strictLyricsMatching", strictLyricsMatching) } }
    var directory: URL
    var launchAtLogin = SMAppService.mainApp.status == .enabled
    var overlayLayoutWidth: Double { min(1000, max(320, overlayWidth)) }
    var overlayPrimarySpacing: Double { max(10, fontSize * 0.44) }
    var overlaySecondarySpacing: Double { max(8, max(translationFontSize, nextLineFontSize) * 0.6) }
    init(defaults d: UserDefaults = .standard) {
        defaults = d
        sourceConfigurationReader = SourceConfigurationReader(defaults: d)
        overlayVisible = d.object(forKey: "overlayVisible") as? Bool ?? true
        overlayLocked = d.bool(forKey: "overlayLocked")
        overlayClickThrough = d.bool(forKey: "overlayClickThrough")
        hideOverlayOnHover = d.object(forKey: "hideOverlayOnHover") as? Bool ?? true
        overlayAppearance = OverlayAppearance(savedValue: d.string(forKey: "overlayAppearance"))
        let savedTransparency = d.object(forKey: "overlayTransparency") as? Double
        let legacyStrength = d.object(forKey: "overlayBackgroundStrength") as? Double
        let transparency = OverlayAppearance.clampedTransparency(
            savedTransparency ?? legacyStrength.map { 1 - $0 } ?? OverlayAppearance.defaultTransparency)
        overlayTransparency = transparency
        func frost(_ style: OverlayAppearance, key: String) -> Double {
            if let saved = d.object(forKey: key) as? Double { return style.clampedFrost(saved) }
            return savedTransparency != nil || legacyStrength != nil
                ? style.migratedFrost(transparency: transparency) : style.defaultFrost
        }
        overlayGlassFrostAmount = frost(.glass, key: "overlayGlassFrostAmount")
        overlayReadingFrostAmount = frost(.frosted, key: "overlayReadingFrostAmount")
        if d.integer(forKey: "compactOverlayVersion") < 1 {
            if d.object(forKey: "overlayWidth") == nil || d.double(forKey: "overlayWidth") == 640 { d.set(520.0, forKey: "overlayWidth") }
            d.set(1, forKey: "compactOverlayVersion")
        }
        if d.integer(forKey: "fixedOverlayWidthVersion") < 1 {
            if d.object(forKey: "overlayWidth") == nil || d.double(forKey: "overlayWidth") == 520 { d.set(620.0, forKey: "overlayWidth") }
            d.set(1, forKey: "fixedOverlayWidthVersion")
        }
        func number(_ key: String, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
            guard let value = d.object(forKey: key) as? Double, value.isFinite else { return fallback }
            return min(range.upperBound, max(range.lowerBound, value))
        }
        overlayWidth = number("overlayWidth", 620, 320...1000)
        overlayAdaptiveSize = d.object(forKey: "overlayAdaptiveSize") as? Bool ?? true
        overlayFrameRate = OverlayFrameRate(rawValue: d.string(forKey: "overlayFrameRate") ?? "display") ?? .display
        fontSize = number("fontSize", 26, 18...42)
        lyricFontName = d.string(forKey: "lyricFontName") ?? ""
        lyricPrimaryColor = LyricTypography.normalizedHex(d.string(forKey: "lyricPrimaryColor") ?? "FFFFFF")
        lyricSecondaryColor = LyricTypography.normalizedHex(d.string(forKey: "lyricSecondaryColor") ?? "FFFFFF")
        followArtworkColors = d.bool(forKey: "followArtworkColors")
        separateWordColors = d.object(forKey: "separateWordColors") as? Bool ?? false
        sungWordColor = LyricTypography.normalizedHex(d.string(forKey: "sungWordColor") ?? d.string(forKey: "lyricPrimaryColor") ?? "FFFFFF")
        unsungWordColor = LyricTypography.normalizedHex(d.string(forKey: "unsungWordColor") ?? "757575")
        translationFontSize = number("translationFontSize", 13, 10...24)
        nextLineFontSize = number("nextLineFontSize", 12, 10...24)
        overlaySecondaryMode = OverlaySecondaryMode(rawValue: d.string(forKey: "overlaySecondaryMode") ?? "translation") ?? .translation
        mainLyricFontSize = number("mainLyricFontSize", 30, 20...42)
        mainTranslationFontSize = number("mainTranslationFontSize", 14, 11...24)
        showTranslation = d.object(forKey: "showTranslation") as? Bool ?? true
        showMenubarLyrics = d.bool(forKey: "showMenubarLyrics")
        showMenuBarIcon = d.object(forKey: "showMenuBarIcon") as? Bool ?? true
        showDockIcon = d.object(forKey: "showDockIcon") as? Bool ?? true
        combinedMenubarLyrics = d.object(forKey: "combinedMenubarLyrics") as? Bool ?? true
        blockedTracks = d.stringArray(forKey: "blockedTracks") ?? []
        blockedAlbums = d.stringArray(forKey: "blockedAlbums") ?? []
        hideWhenPaused = d.bool(forKey: "hideWhenPaused")
        reduceMotion = d.bool(forKey: "reduceMotion")
        lyricWordLift = d.object(forKey: "lyricWordLift") as? Bool ?? true
        lyricGlow = d.object(forKey: "lyricGlow") as? Bool ?? true
        // Request enhancement by default; each window's display policy gates it.
        // A saved false is an explicit opt-out and must survive reconnects.
        lyricHDR = d.object(forKey: "lyricHDR") as? Bool ?? true
        lyricHDRBrightness = number("lyricHDRBrightness", 1.6, 1...4)
        conversion = ["原文", "简体", "繁體"].first { $0 == d.string(forKey: "conversion") } ?? "原文"
        playerMode = PlayerMode(rawValue: d.string(forKey: "playerMode") ?? "automatic") ?? .automatic
        disabledSources = d.stringArray(forKey: "disabledSources") ?? []
        sourceOrder = SourceConfiguration.normalizedOrder(d.stringArray(forKey: "sourceOrder") ?? [])
        preferBilingual = d.object(forKey: "preferBilingual") as? Bool ?? true
        preferWordTiming = d.object(forKey: "preferWordTiming") as? Bool ?? true
        strictLyricsMatching = d.object(forKey: "strictLyricsMatching") as? Bool ?? true
        directory = CacheLocation.resolve(modern: d)
        // Migrate once. Future launches must prefer the user's new setting.
        if d.string(forKey: "overlayAppearance") != overlayAppearance.rawValue {
            d.set(overlayAppearance.rawValue, forKey: "overlayAppearance")
        }
        if savedTransparency != overlayTransparency {
            d.set(overlayTransparency, forKey: "overlayTransparency")
        }
        d.set(overlayGlassFrostAmount, forKey: "overlayGlassFrostAmount")
        d.set(overlayReadingFrostAmount, forKey: "overlayReadingFrostAmount")
    }
    private func save(_ key: String, _ value: Any) { defaults.set(value, forKey: key) }
    func setSource(_ name: String, enabled: Bool) {
        disabledSources.removeAll { $0 == name }
        if !enabled { disabledSources.append(name) }
    }
    func moveSource(_ source: String, by delta: Int) {
        guard let index = sourceOrder.firstIndex(of: source) else { return }
        let destination = min(sourceOrder.count - 1, max(0, index + delta))
        guard destination != index else { return }
        var order = sourceOrder
        order.remove(at: index)
        order.insert(source, at: destination)
        sourceOrder = order
    }
    func moveSource(_ source: String, before destination: String) -> Bool {
        guard source != destination, sourceOrder.contains(source), sourceOrder.contains(destination) else { return false }
        var order = sourceOrder.filter { $0 != source }
        guard let index = order.firstIndex(of: destination) else { return false }
        order.insert(source, at: index)
        sourceOrder = order
        return true
    }
    func chooseDirectory(_ url: URL) {
        directory = url
        defaults.set(url.path, forKey: "ModernLyricsDirectory")
        if let bookmark = try? url.bookmarkData(options: [.withSecurityScope]) {
            defaults.set(bookmark, forKey: "ModernLyricsDirectoryBookmark")
        }
    }
    private static let convertedText: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 512
        cache.totalCostLimit = 1_000_000
        return cache
    }()
    func text(_ text: String) -> String {
        guard conversion != "原文", !text.isEmpty else { return text }
        let key = (conversion + "\u{0}" + text) as NSString
        if let cached = Self.convertedText.object(forKey: key) { return cached as String }
        let transform = conversion == "简体" ? "Traditional-Simplified" : "Simplified-Traditional"
        let result = text.applyingTransform(StringTransform(transform), reverse: false) ?? text
        Self.convertedText.setObject(result as NSString, forKey: key, cost: (text.utf8.count + result.utf8.count))
        return result
    }
}

/// UserDefaults is thread-safe. Keep the exact settings store used by the UI,
/// including test/profile suites, instead of rereading a separate global store.
final class SourceConfigurationReader: @unchecked Sendable {
    private let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }
    func read() -> SourceConfiguration {
        var config = SourceConfiguration()
        let disabled = defaults.stringArray(forKey: "disabledSources") ?? []
        config.enabled = Set(SourceConfiguration.defaultOrder).subtracting(disabled)
        config.sourceOrder = SourceConfiguration.normalizedOrder(defaults.stringArray(forKey: "sourceOrder") ?? [])
        config.preferBilingual = defaults.object(forKey: "preferBilingual") as? Bool ?? true
        config.preferWordTiming = defaults.object(forKey: "preferWordTiming") as? Bool ?? true
        config.strictMatching = defaults.object(forKey: "strictLyricsMatching") as? Bool ?? true
        config.musixmatchToken = TokenStore.read()
        return config
    }
}

enum TokenStore {
    private static let service = "com.lyricsx.modern.musixmatch"
    static func read() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                   kSecAttrAccount as String: "usertoken", kSecReturnData as String: true]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ token: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "usertoken"]
        if token.isEmpty { SecItemDelete(query as CFDictionary); return }
        let data = Data(token.utf8)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var new = query; new[kSecValueData as String] = data
            status = SecItemAdd(new as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
}
