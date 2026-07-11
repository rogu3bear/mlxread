import Foundation
import HuggingFace
import MLXAudioCore
import Observation

/// Owns model assets on disk: download (single-flight, with progress),
/// validation, removal, disk usage. Loading/keeping models warm is the speech
/// engine's job; the store only manages files.
///
/// Cache layout is mlx-audio's: `<root>/mlx-audio/<owner>_<repo>/…`.
/// `Self.bootstrapEnvironment()` points `HF_HUB_CACHE` at our root before
/// anything touches `HubCache.default`, because parts of mlx-audio-swift
/// (Kokoro G2P asset downloads) hardcode the default cache.
@MainActor
@Observable
final class ModelStore {
    let rootDirectory: URL
    private(set) var states: [String: ModelDownloadState] = [:]
    private var downloadTasks: [String: Task<Void, Never>] = [:]

    /// Must run before any HubCache.default access anywhere in the process.
    nonisolated static func bootstrapEnvironment(rootDirectory: URL = Constants.modelsDirectory) {
        try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        setenv("HF_HUB_CACHE", rootDirectory.path, 1)
    }

    init(rootDirectory: URL = Constants.modelsDirectory) {
        self.rootDirectory = rootDirectory
        refreshAllStates()
    }

    // MARK: - State

    func state(for model: ModelInfo) -> ModelDownloadState {
        states[model.id] ?? .notDownloaded
    }

    var isAnyModelDownloaded: Bool {
        ModelManifest.all.contains { state(for: $0) == .downloaded }
    }

    func refreshAllStates() {
        for model in ModelManifest.all where !(states[model.id]?.isDownloading ?? false) {
            states[model.id] = validate(model) ? .downloaded : .notDownloaded
        }
    }

    func directory(for model: ModelInfo) -> URL {
        rootDirectory.appendingPathComponent(model.cacheSubdirectory, isDirectory: true)
    }

    /// A model is complete when config.json parses and at least one non-empty
    /// weights file exists (plus voices/ for voice models).
    func validate(_ model: ModelInfo) -> Bool {
        let dir = directory(for: model)
        let fm = FileManager.default
        let configURL = dir.appendingPathComponent("config.json")
        guard let data = try? Data(contentsOf: configURL),
              (try? JSONSerialization.jsonObject(with: data)) != nil
        else { return false }
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return false
        }
        let hasWeights = files.contains { url in
            url.pathExtension == "safetensors"
                && ((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0) > 0
        }
        guard hasWeights else { return false }
        if model.supportsVoices {
            let voicesDir = dir.appendingPathComponent("voices")
            let voices = (try? fm.contentsOfDirectory(atPath: voicesDir.path)) ?? []
            guard voices.contains(where: { $0.hasSuffix(".safetensors") }) else { return false }
        }
        return true
    }

    // MARK: - Download

    /// Starts (or joins) the download for `model`. Single-flight per model.
    func download(_ model: ModelInfo) {
        guard downloadTasks[model.id] == nil else { return }
        states[model.id] = .downloading(fraction: 0)
        AppLogger.models.info("Starting download of \(model.id)")

        let cache = HubCache(cacheDirectory: rootDirectory)
        let modelID = model.id
        downloadTasks[model.id] = Task { [weak self] in
            do {
                guard let repoID = Repo.ID(rawValue: modelID) else {
                    throw UserFacingSpeechError.modelDownloadFailed("invalid repo ID")
                }
                _ = try await ModelUtils.resolveOrDownloadModel(
                    client: HubClient(cache: cache),
                    cache: cache,
                    repoID: repoID,
                    requiredExtension: "safetensors",
                    additionalMatchingPatterns: [],
                    progressHandler: { [weak self] progress in
                        self?.noteProgress(modelID: modelID, fraction: progress.fractionCompleted)
                    }
                )
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.downloadTasks[modelID] = nil
                    if let info = ModelManifest.model(withID: modelID), self.validate(info) {
                        self.states[modelID] = .downloaded
                        AppLogger.models.info("Download of \(modelID) complete")
                    } else {
                        self.states[modelID] = .failed(UserFacingSpeechError.modelFilesIncomplete.errorDescription ?? "incomplete")
                        AppLogger.models.error("Download of \(modelID) finished but validation failed")
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.downloadTasks[modelID] = nil
                    if error is CancellationError {
                        self.states[modelID] = self.validate(ModelManifest.model(withID: modelID) ?? model) ? .downloaded : .notDownloaded
                    } else {
                        AppLogger.models.error("Download of \(modelID) failed: \(error.localizedDescription)")
                        self.states[modelID] = .failed(error.localizedDescription)
                    }
                }
            }
        }
    }

    private func noteProgress(modelID: String, fraction: Double) {
        if case .downloading = states[modelID] ?? .notDownloaded {
            states[modelID] = .downloading(fraction: fraction)
        }
    }

    func cancelDownload(_ model: ModelInfo) {
        downloadTasks[model.id]?.cancel()
    }

    // MARK: - Removal & inspection

    func remove(_ model: ModelInfo) throws {
        cancelDownload(model)
        let dir = directory(for: model)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
        states[model.id] = .notDownloaded
        AppLogger.models.info("Removed model \(model.id)")
    }

    func diskUsageBytes(for model: ModelInfo) -> Int64 {
        directorySize(directory(for: model))
    }

    func totalDiskUsageBytes() -> Int64 {
        directorySize(rootDirectory)
    }

    /// Voice names discovered on disk (Kokoro: voices/<name>.safetensors).
    func availableVoices(for model: ModelInfo) -> [String] {
        guard model.supportsVoices else { return [] }
        let voicesDir = directory(for: model).appendingPathComponent("voices")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: voicesDir.path)) ?? []
        return files
            .filter { $0.hasSuffix(".safetensors") }
            .map { String($0.dropLast(".safetensors".count)) }
            .sorted()
    }

    func revealInFinder() {
        NSWorkspaceProxy.reveal(rootDirectory)
    }

    private nonisolated func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}

/// Small indirection so ModelStore stays importable in unit tests without AppKit.
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
