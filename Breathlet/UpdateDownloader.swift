import CryptoKit
import Combine
import Foundation

/// 在 App 内下载新版本 DMG（进度、完成、失败状态），下载完成后自动挂载。
final class UpdateDownloader: NSObject {
    enum State: Equatable {
        case idle
        case downloading(progress: Double)
        case downloaded(URL)
        case failed(String)
    }

    static let shared = UpdateDownloader()

    /// 主线程隔离的下载状态，供 UI 观察（Swift 6 严格并发下避免跨线程裸写 @Published）。
    @MainActor
    final class Model: ObservableObject {
        @Published fileprivate(set) var state: State = .idle

        nonisolated init() {}
    }

    let model = Model()

    // 以下状态仅在 URLSession 代理队列上读写（taskIdentifier 做守卫），
    // 通过 nonisolated(unsafe) 显式声明由人工保证同步。
    nonisolated(unsafe) private var session: URLSession?
    nonisolated(unsafe) private var task: URLSessionDownloadTask?
    nonisolated(unsafe) private var destinationURL: URL?
    nonisolated(unsafe) private var expectedSHA256: String?

    private override init() {
        super.init()
    }

    func reset() {
        task?.cancel()
        task = nil
        session = nil
        destinationURL = nil
        expectedSHA256 = nil
        setState(.idle)
    }

    func start(from url: URL, version: String, sha256: String?) {
        reset()
        expectedSHA256 = sha256

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 60
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session

        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let destination = downloads.appendingPathComponent("Breathlet-\(version).dmg")
        destinationURL = destination

        setState(.downloading(progress: 0))
        let task = session.downloadTask(with: url)
        self.task = task
        task.resume()
    }

    private func setState(_ newState: State) {
        Task { @MainActor in
            model.state = newState
        }
    }
}

extension UpdateDownloader: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard downloadTask.taskIdentifier == self.task?.taskIdentifier else { return }
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        setState(.downloading(progress: min(max(progress, 0), 1)))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard downloadTask.taskIdentifier == self.task?.taskIdentifier else { return }
        do {
            guard let destination = destinationURL else {
                throw URLError(.fileDoesNotExist)
            }
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)

            if let expected = expectedSHA256 {
                let digest = try sha256Digest(of: destination)
                guard digest.lowercased() == expected.lowercased() else {
                    try? FileManager.default.removeItem(at: destination)
                    setState(.failed(NSLocalizedString("Download verification failed", comment: "")))
                    return
                }
            }
            setState(.downloaded(destination))
        } catch {
            setState(.failed(error.localizedDescription))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        guard task.taskIdentifier == self.task?.taskIdentifier else { return }
        setState(.failed(error.localizedDescription))
    }
}

private extension UpdateDownloader {
    /// 流式计算文件的 SHA-256，避免把整个 DMG 读进内存。
    func sha256Digest(of url: URL) throws -> String {
        var hasher = SHA256()
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
