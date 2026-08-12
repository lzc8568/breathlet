import Foundation

/// 在 App 内下载新版本 DMG（进度、完成、失败状态），下载完成后自动挂载。
final class UpdateDownloader: NSObject, ObservableObject {
    enum State {
        case idle
        case downloading(progress: Double)
        case downloaded(URL)
        case failed(String)
    }

    static let shared = UpdateDownloader()

    @Published private(set) var state: State = .idle

    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var destinationURL: URL?

    private override init() {
        super.init()
    }

    func reset() {
        task?.cancel()
        task = nil
        session = nil
        destinationURL = nil
        setState(.idle)
    }

    func start(from url: URL, version: String) {
        reset()

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
        DispatchQueue.main.async {
            self.state = newState
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
