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
    static let manifestURL = URL(string: "https://emerald-globe-xmny.here.now/latest.json")!

    static func checkLatest() async throws -> UpdateInfo {
        var request = URLRequest(url: manifestURL)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
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
