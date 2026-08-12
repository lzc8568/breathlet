import Foundation
import UserNotifications

/// here.now 上下发的更新清单（由 release workflow 自动生成并发布）。
struct UpdateInfo: Codable {
    let version: String
    let url: String
    let size: Int64?
    let sha256: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case version, url, size, sha256
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

/// 启动时静默检查更新：每天最多一次，发现新版本才通过通知中心提示。
enum SilentUpdateChecker {
    private static let lastCheckDateKey = "lastSilentUpdateCheckDate"
    private static let minimumInterval: TimeInterval = 24 * 60 * 60

    static func checkIfNeeded() {
        let defaults = UserDefaults.standard
        let lastCheck = defaults.object(forKey: lastCheckDateKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(lastCheck) >= minimumInterval else { return }
        defaults.set(Date(), forKey: lastCheckDateKey)

        Task {
            do {
                let info = try await UpdateChecker.checkLatest()
                let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
                guard UpdateChecker.isNewer(info.version, than: current) else { return }
                await notify(version: info.version)
            } catch {
                // 静默失败：不打扰用户，下次启动再试。
            }
        }
    }

    private static func notify(version: String) async {
        let center = UNUserNotificationCenter.current()
        // 延迟到真正发现新版本时才申请通知权限，避免一启动就弹授权框。
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Breathlet update available", comment: "")
        content.body = String(format: NSLocalizedString("Version %@ is now available.", comment: ""), version)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "breathlet-update-available",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
