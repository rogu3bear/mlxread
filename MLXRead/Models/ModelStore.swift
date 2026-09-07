import Foundation
import HuggingFace
import Observation

/// Owns model files, download/delete operations, and their observable status.
/// The speech engine owns loaded models; the store never synthesizes text.
@MainActor
@Observable
final class ModelStore {
    let rootDirectory: URL
    private(set) var states: [String: ModelDownloadState] = [:] {
        didSet { onStateChange?() }
    }
    var onStateChange: (() -> Void)?
    private var downloadTasks: [String: (id: UUID, task: Task<Void, Never>)] = [:]
    private let downloader: any ModelDownloading

    /// Kokoro's pronunciation loader uses HubCache.default. Set this before
    /// any cache access so those assets stay in the app's models folder too.
    nonisolated static func bootstrapEnvironment(rootDirectory: URL = Constants.modelsDirectory) {
        try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        setenv("HF_HUB_CACHE", rootDirectory.path, 1)
    }

    init(rootDirectory: URL = Constants.modelsDirectory, downloader: any ModelDownloading = HubModelDownloader()) {
        self.rootDirectory = rootDirectory
        self.downloader = downloader
        refreshAllStates()
    }

    func state(for model: ModelInfo) -> ModelDownloadState {
        states[model.id] ?? .notDownloaded
    }

    func availability(for model: ModelInfo, voice: String?, language: String? = nil) -> SpeechState? {
        guard state(for: model) == .downloaded else { return .modelRequired }
        if model.supportsVoices {
            guard let voice = voice ?? model.defaultVoice,
                  availableVoices(for: model).contains(voice) else { return .voiceRequired }
            guard model.canRead(voice: voice, language: model.readingLanguage(voice: voice, requested: language)) else {
                return .voiceRequired
            }
        }
        return nil
    }

    var isAnyModelDownloaded: Bool {
        ModelManifest.all.contains { state(for: $0) == .downloaded }
    }

    func refreshAllStates() {
        for model in ModelManifest.all where !(states[model.id]?.isBusy ?? false) {
            let current = diskState(for: model)
            // Preserve an actionable network error until retry or completion.
            if case .failed = states[model.id], current != .downloaded { continue }
            states[model.id] = current
        }
    }

    private func diskState(for model: ModelInfo) -> ModelDownloadState {
        if validate(model) { return .downloaded }
        return diskUsageBytes(for: model) > 0 ? .incomplete : .notDownloaded
    }

    func directory(for model: ModelInfo) -> URL {
        rootDirectory.appendingPathComponent(model.cacheSubdirectory, isDirectory: true)
    }

    /// Required tokenizers and voices differ by model. We validate them before
    /// offering a preview; synthesis errors still belong to the speech engine.
    func validate(_ model: ModelInfo) -> Bool {
        guard model.downloads.allSatisfy({ validate($0) }) else { return false }
        return !model.supportsVoices || !availableVoices(for: model).isEmpty
    }

    private func validate(_ asset: ModelAsset) -> Bool {
        let dir = rootDirectory.appendingPathComponent(asset.cacheSubdirectory)
        guard validJSON(dir.appendingPathComponent("config.json")),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil),
              files.contains(where: { $0.pathExtension == "safetensors" && isNonemptyFile($0) }) else {
            return false
        }
        for path in asset.requiredFiles {
            let file = dir.appendingPathComponent(path)
            guard isNonemptyFile(file) else { return false }
            if file.pathExtension == "json", !validJSON(file) { return false }
        }
        return true
    }

    // MARK: - Download and deletion

    func download(_ model: ModelInfo) {
        guard downloadTasks[model.id] == nil, !state(for: model).isBusy,
              state(for: model) != .downloaded else { return }
        states[model.id] = .downloading(fraction: 0)
        AppLogger.models.info("Starting download of \(model.id)")
        let destination = directory(for: model)
        let downloader = self.downloader
        let operationID = UUID()
        let task = Task { [weak self] in
            defer {
                if self?.downloadTasks[model.id]?.id == operationID { self?.downloadTasks[model.id] = nil }
            }
            do {
                try await downloader.download(model, to: destination) { [weak self] fraction in
                    guard let self, self.downloadTasks[model.id]?.id == operationID,
                          case .downloading = self.states[model.id] else { return }
                    self.states[model.id] = .downloading(fraction: fraction.isFinite ? min(max(fraction, 0), 1) : 0)
                }
                try Task.checkCancellation()
                guard let self, self.states[model.id] != .deleting else { return }
                self.states[model.id] = .checking
                guard self.validate(model) else { throw UserFacingSpeechError.modelFilesIncomplete }
                self.states[model.id] = .downloaded
                AppLogger.models.info("Download of \(model.id) complete")
            } catch {
                guard let self, self.states[model.id] != .deleting else { return }
                if Task.isCancelled || error is CancellationError {
                    self.states[model.id] = self.diskState(for: model)
                } else {
                    self.states[model.id] = .failed(error.localizedDescription)
                }
            }
        }
        downloadTasks[model.id] = (operationID, task)
    }

    func cancelDownload(_ model: ModelInfo) {
        guard let task = downloadTasks[model.id], state(for: model) != .deleting else { return }
        states[model.id] = .cancelling
        task.task.cancel()
    }

    func remove(_ model: ModelInfo, movingToTrash: Bool = false) async throws {
        guard state(for: model) != .deleting else { return }
        states[model.id] = .deleting
        // Cancellation is not completion. Join the writer before deleting so
        // it cannot recreate files or publish a stale downloaded state.
        if let task = downloadTasks[model.id] {
            task.task.cancel()
            await task.task.value
        }
        do {
            for dir in ownedDirectories(for: model) {
                if FileManager.default.fileExists(atPath: dir.path) {
                    if movingToTrash {
                        try FileManager.default.trashItem(at: dir, resultingItemURL: nil)
                    } else {
                        try FileManager.default.removeItem(at: dir)
                    }
                }
            }
            states[model.id] = .notDownloaded
            AppLogger.models.info("Removed model \(model.id)")
        } catch {
            states[model.id] = diskState(for: model)
            throw error
        }
    }

    // MARK: - Voices and disk usage

    func availableVoices(for model: ModelInfo) -> [String] {
        if case .presets(let voices) = model.voiceCatalog { return voices.map(\.id) }
        guard let subdirectory = model.voiceCatalog.directory else { return [] }
        let voicesDir = directory(for: model).appendingPathComponent(subdirectory)
        let files = (try? FileManager.default.contentsOfDirectory(at: voicesDir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "safetensors" && isNonemptyFile($0) }
            .map { $0.deletingPathExtension().lastPathComponent }.sorted()
    }

    func diskUsageBytes(for model: ModelInfo) -> Int64 {
        ownedDirectories(for: model).reduce(0) { $0 + directorySize($1) }
    }

    func totalDiskUsageBytes() -> Int64 { directorySize(rootDirectory) }

    func revealInFinder() { NSWorkspaceProxy.reveal(rootDirectory) }

    private func ownedDirectories(for model: ModelInfo) -> [URL] {
        model.downloads.flatMap { asset in
            [rootDirectory.appendingPathComponent(asset.cacheSubdirectory),
             HubCache(cacheDirectory: rootDirectory).repoDirectory(repo: Repo.ID(rawValue: asset.id)!, kind: .model)]
        }
    }

    private func validJSON(_ file: URL) -> Bool {
        guard let data = try? Data(contentsOf: file) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) is [String: Any]
    }

    private func isNonemptyFile(_ file: URL) -> Bool {
        guard let values = try? file.resolvingSymlinksInPath()
            .resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else { return false }
        return values.isRegularFile == true && (values.fileSize ?? 0) > 0
    }

    private nonisolated func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let values = try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}

protocol ModelDownloading: Sendable {
    func download(_ model: ModelInfo, to directory: URL,
                  progress: @escaping @MainActor @Sendable (Double) -> Void) async throws
}

struct HubModelDownloader: ModelDownloading {
    func download(_ model: ModelInfo, to directory: URL,
                  progress: @escaping @MainActor @Sendable (Double) -> Void) async throws {
        // The pinned Hub client requires a cache even with a destination.
        // It copies resolved files into the destination, so its extra cached
        // weights can be removed after successful completion.
        let root = directory.deletingLastPathComponent().deletingLastPathComponent()
        let cache = HubCache(cacheDirectory: root)
        let totalSize = Double(model.downloads.reduce(0) { $0 + $1.approximateSizeMB })
        var completedSize = 0.0
        for asset in model.downloads {
            try Task.checkCancellation()
            guard let repo = Repo.ID(rawValue: asset.id) else {
                throw UserFacingSpeechError.modelDownloadFailed("invalid repository ID")
            }
            let completed = completedSize
            _ = try await HubClient(cache: cache).downloadSnapshot(
                of: repo, to: root.appendingPathComponent(asset.cacheSubdirectory),
                matching: ["*.safetensors", "*.json", "*.txt", "*.wav"],
                progressHandler: { value in
                    progress((completed + value.fractionCompleted * Double(asset.approximateSizeMB)) / totalSize)
                }
            )
            try? FileManager.default.removeItem(at: cache.repoDirectory(repo: repo, kind: .model))
            completedSize += Double(asset.approximateSizeMB)
        }
    }
}

/// Small indirection so ModelStore stays importable without AppKit.
enum NSWorkspaceProxy {
    @MainActor
    static func reveal(_ url: URL) {
        #if canImport(AppKit)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }
}

#if canImport(AppKit)
import AppKit
#endif
