import Foundation

extension Lyrics.Metadata.Key {
    public static var attachmentTags = Lyrics.Metadata.Key("attachmentTags")
    public static let plainText = Lyrics.Metadata.Key("plainText")
}

extension Lyrics.Metadata {
    /// Untimed provider text. Never synthesize zero-time lyric lines for it.
    public var plainText: String? {
        get { data[.plainText] as? String }
        set { data[.plainText] = newValue }
    }

    public var attachmentTags: Set<LyricsLine.Attachments.Tag> {
        get { return data[.attachmentTags] as? Set<LyricsLine.Attachments.Tag> ?? [] }
        set { data[.attachmentTags] = newValue }
    }

    public var hasTranslation: Bool {
        return attachmentTags.contains(where: \.isTranslation)
    }
}
