import Foundation
import ImageIO

/// ImageIO must finish decompression off the main actor, before either window
/// uploads the pixels. A serial actor bounds peak decode memory during skips.
actor ArtworkDecoder {
    static let shared = ArtworkDecoder()
    private var cached: (data: Data, image: CGImage)?

    func load(data: Data?, url originalURL: URL?) async -> CGImage? {
        if let data, let image = decode(data) { return image }
        guard !Task.isCancelled, let originalURL,
              let scheme = originalURL.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        var url = originalURL
        if scheme == "http", var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false) {
            components.scheme = "https"
            url = components.url ?? originalURL
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled, (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return decode(data)
        } catch { return nil }
    }

    func decode(_ data: Data) -> CGImage? {
        guard !Task.isCancelled, data.count < 8_000_000 else { return nil }
        if let cached, cached.data == data { return cached.image }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 640,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary), !Task.isCancelled else { return nil }
        cached = (data, image)
        return image
    }
}
