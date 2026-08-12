import Foundation

/// here.now 上下发的更新清单（由 release workflow 自动生成并发布）。
struct UpdateInfo: Codable {
    let version: String
    let url: String
    let size: Int64?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case version, url, size
        case updatedAt = "updated_at"
    }
}

enum UpdateCheckState {
    case idle
    case checking
    case upToDate
    case updateAvailable(UpdateInfo)
    case failed(String)
}

enum UpdateChecker {
    private static let manifestBaseURL = URL(string: "https://emerald-globe-xmny.here.now/latest.json")!

    // 更新检查必须每次强制取最新：用临时会话，不落缓存
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration)
    }()

    static func checkLatest() async throws -> UpdateInfo {
        // 时间戳参数绕过任何中间/CDN 缓存，保证拿到最新 manifest
        let url = manifestBaseURL.appending(queryItems: [
            URLQueryItem(name: "t", value: "\(Int(Date().timeIntervalSince1970))")
        ])
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(UpdateInfo.self, from: data)
    }

    /// 逐段数值比较 "x.y.z"，candidate > current 视为有新版本。
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").compactMap { Int($0) }
        let b = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(a.count, b.count) {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }
}
