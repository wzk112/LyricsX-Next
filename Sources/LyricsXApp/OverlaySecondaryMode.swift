import Foundation

/// One policy for the picker, rendered rows and panel measurement. Manual-height
/// mode reserves two rows per auxiliary item; automatic height uses actual rows.
enum OverlaySecondaryMode: String, CaseIterable, Identifiable {
    case translation, next, either, both, none
    var id: String { rawValue }
    var supportsTranslation: Bool { self == .translation || self == .either || self == .both }
    var supportsNext: Bool { self == .next || self == .either || self == .both }
    var title: String {
        switch self {
        case .translation: "仅翻译"
        case .next: "仅下一句"
        case .either: "翻译或下一句"
        case .both: "翻译和下一句"
        case .none: "关闭"
        }
    }
    struct Content: Equatable {
        var translation: String?
        var next: String?
        func height(translationHeight: Double, nextHeight: Double, primarySpacing: Double, secondarySpacing: Double) -> Double {
            let translationSpace = translation == nil ? 0 : translationHeight + primarySpacing
            let nextSpace = next == nil ? 0 : nextHeight + (translation == nil ? primarySpacing : secondarySpacing)
            return translationSpace + nextSpace
        }
    }
    func content(translation: String?, next: String?) -> Content {
        func nonempty(_ text: String?) -> String? {
            guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return text
        }
        let translation = nonempty(translation), next = nonempty(next)
        switch self {
        case .translation: return .init(translation: translation)
        case .next: return .init(next: next)
        case .either: return translation.map { .init(translation: $0) } ?? .init(next: next)
        case .both: return .init(translation: translation, next: next)
        case .none: return .init()
        }
    }
    func reservedHeight(translationSize: Double, nextSize: Double, primarySpacing: Double, secondarySpacing: Double) -> Double {
        switch self {
        case .none: 0
        case .translation: ceil(translationSize * 1.4) * 2 + primarySpacing
        case .next: nextSize * 2.8 + primarySpacing
        case .either: max(ceil(translationSize * 1.4) * 2, nextSize * 2.8) + primarySpacing
        case .both: ceil(translationSize * 1.4) * 2 + nextSize * 2.8 + primarySpacing + secondarySpacing
        }
    }
}
