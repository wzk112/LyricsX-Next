import Foundation
@preconcurrency import LyricsKit

public struct SourceSearchStatus: Sendable, Equatable, Identifiable {
    public var id: String { source }
    public let source: String
    public let count: Int
    public let isSearching: Bool
    public let issue: String?
    public init(source: String, count: Int, isSearching: Bool, issue: String? = nil) {
        self.source = source; self.count = count; self.isSearching = isSearching; self.issue = issue
    }

    static func describe(_ error: Error) -> String {
        if let error = error as? LyricsProviderError {
            switch error {
            case .serviceResponse(let code):
                return [405, 429].contains(code) ? "请求限流，请稍后重试" : "服务响应异常（\(code)）"
            case .networkError(let underlying): return describe(underlying)
            case .decodingError: return "返回数据格式异常"
            case .processingFailed: return "候选歌词暂不可用"
            case .invalidURL: return "来源地址无效"
            }
        }
        if let error = error as? LyricsStore.StoreError { return error.localizedDescription }
        if let error = error as? HTTPResponseError {
            return error.status == 429 ? "请求限流，请稍后重试" : "服务响应异常（\(error.status)）"
        }
        let code = (error as NSError).code
        if (error as NSError).domain == NSURLErrorDomain {
            switch code {
            case NSURLErrorTimedOut: return "响应超时"
            case NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateHasUnknownRoot, NSURLErrorSecureConnectionFailed:
                return "来源证书或安全连接异常"
            case NSURLErrorCancelled: return "已取消"
            default: return "连接暂时失败"
            }
        }
        return error is DecodingError ? "返回数据格式异常" : "搜索暂未完成"
    }
}

extension SourceConfiguration {
    var availableSources: [String] {
        Self.normalizedOrder(sourceOrder).filter {
            enabled.contains($0) && ($0 != "Musixmatch" || musixmatchToken?.isEmpty == false)
        }
    }
}

struct HTTPResponseError: Error, Sendable { let status: Int }
