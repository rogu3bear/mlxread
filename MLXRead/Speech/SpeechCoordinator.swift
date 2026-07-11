import Foundation
import Observation

/// The single authoritative state machine for MLXRead.
///
/// Owns: current generation identity, capture/synthesis tasks, playback
/// session, cancellation, and the user-visible `state`. Every UI surface
/// observes this object; nothing else infers whether speech is active.
@MainActor
@Observable
final class SpeechCoordinator {
    private(set) var state: SpeechState = .idle {
        didSet {
            if state != oldValue {
                AppLogger.speech.notice("State: \(oldValue.displayName, privacy: .public) → \(self.state.displayName, privacy: .public)")
            }
        }
    }
    /// True when the last read had to truncate the selection.
    private(set) var lastReadWasTruncated = false

    private let selection: any SelectionCapturing
    private let player: any AudioPlaying
    private let engineProvider: () -> any SpeechEngine
    private let configurationProvider: () -> SpeechConfiguration
    private let maximumLengthProvider: () -> Int
    /// External availability gates (permission, model present).
    var availabilityCheck: () -> SpeechState? = { nil }

    private var currentGeneration: UUID?
    private var readingTask: Task<Void, Never>?
    private var failureResetTask: Task<Void, Never>?

    init(
        selection: any SelectionCapturing,
        player: any AudioPlaying,
        engineProvider: @escaping () -> any SpeechEngine,
        configurationProvider: @escaping () -> SpeechConfiguration,
        maximumLengthProvider: @escaping () -> Int = { Constants.Defaults.maximumSelectionLength }
    ) {
        self.selection = selection
        self.player = player
        self.engineProvider = engineProvider
        self.configurationProvider = configurationProvider
        self.maximumLengthProvider = maximumLengthProvider
    }

    /// Recomputes the resting state (permission/model gates) when idle.
    func refreshAvailability() {
        guard !state.isBusy else { return }
        if let gated = availabilityCheck() {
            state = gated
        } else if !state.isBusy {
            state = .idle
        }
    }

    /// Hotkey entry point. Busy → cancel; otherwise start a read.
    func toggle() {
        if state.isBusy {
            stop()
        } else {
            beginReadingSelection()
        }
    }

    func beginReadingSelection() {
        refreshAvailability()
        switch state {
        case .idle, .failed:
            break
        case .permissionRequired, .modelRequired, .unavailable:
            AppLogger.speech.notice("Read requested but state is \(String(describing: self.state.displayName))")
            return
        default:
            return
        }
        startReading(source: .selectionCapture)
    }

    /// Settings "test phrase" playback; skips selection capture.
    func speakSample(_ text: String) {
        guard !state.isBusy else { return }
        startReading(source: .fixedText(text))
    }

    func stop() {
        guard state.isBusy || readingTask != nil else { return }
        state = .stopping
        let task = readingTask
        readingTask = nil
        currentGeneration = nil
        Task { [player, engineProvider] in
            task?.cancel()
            await engineProvider().cancel()
            await player.stopImmediately()
            await MainActor.run {
                if self.state == .stopping {
                    self.state = .idle
                    self.refreshAvailability()
                }
            }
        }
    }

    // MARK: - Reading pipeline

    private enum ReadingSource {
        case selectionCapture
        case fixedText(String)
    }

    private func startReading(source: ReadingSource) {
        failureResetTask?.cancel()
        lastReadWasTruncated = false
        let generation = UUID()
        currentGeneration = generation
        state = .capturing

        readingTask = Task { [weak self] in
            await self?.run(generation: generation, source: source)
        }
    }

    private func run(generation: UUID, source: ReadingSource) async {
        do {
            let raw: String
            switch source {
            case .fixedText(let text):
                raw = text
            case .selectionCapture:
                let result = await selection.captureSelection()
                guard isCurrent(generation) else { return }
                raw = try text(from: result)
            }

            let normalized = TextNormalizer.normalize(raw, maximumLength: maximumLengthProvider())
            guard !normalized.isEmpty else {
                throw UserFacingSpeechError.noSelectionFound
            }
            lastReadWasTruncated = normalized.wasTruncated
            if normalized.wasTruncated {
                AppLogger.speech.notice("Selection truncated: \(normalized.originalLength) chars > limit")
            }

            guard isCurrent(generation) else { return }
            state = .preparing
            let engine = engineProvider()
            try await engine.prepare()

            guard isCurrent(generation) else { return }
            state = .generating
            let configuration = configurationProvider()
            try await player.startSession(generation, speed: configuration.speed)

            var deliveredFirstChunk = false
            let stream = engine.generate(text: normalized.text, configuration: configuration)
            for try await chunk in stream {
                // Stale-generation gate: chunks from a cancelled/replaced
                // generation never reach the player.
                guard isCurrent(generation), !Task.isCancelled else { return }
                try await player.enqueue(chunk, session: generation)
                if !deliveredFirstChunk {
                    deliveredFirstChunk = true
                    guard isCurrent(generation) else { return }
                    state = .playing
                }
            }

            guard isCurrent(generation), !Task.isCancelled else { return }
            if !deliveredFirstChunk {
                throw UserFacingSpeechError.synthesisFailed("the model produced no audio")
            }
            await player.finishSession(generation)
            guard isCurrent(generation) else { return }
            finishCurrentRead()
        } catch is CancellationError {
            // stop() owns state transitions for cancellation.
        } catch let error as UserFacingSpeechError {
            await failCurrentRead(generation: generation, error: error)
        } catch {
            await failCurrentRead(generation: generation, error: .synthesisFailed(error.localizedDescription))
        }
    }

    private func text(from result: SelectionCaptureResult) throws -> String {
        switch result {
        case .text(let text, let source):
            AppLogger.selection.info("Captured \(text.count) chars via \(source.rawValue)")
            return text
        case .noSelection:
            throw UserFacingSpeechError.noSelectionFound
        case .unsupported:
            throw UserFacingSpeechError.selectionNotExposed
        case .permissionDenied:
            throw UserFacingSpeechError.accessibilityPermissionMissing
        case .applicationUnavailable:
            throw UserFacingSpeechError.selectionNotExposed
        case .failure(let underlying):
            switch underlying {
            case .clipboardTimeout, .clipboardEmpty:
                throw UserFacingSpeechError.clipboardFallbackFailed
            case .axError:
                throw UserFacingSpeechError.selectionNotExposed
            }
        }
    }

    private func isCurrent(_ generation: UUID) -> Bool {
        currentGeneration == generation
    }

    private func finishCurrentRead() {
        readingTask = nil
        currentGeneration = nil
        state = .idle
        refreshAvailability()
    }

    private func failCurrentRead(generation: UUID, error: UserFacingSpeechError) async {
        await player.stopImmediately()
        guard isCurrent(generation) else { return }
        readingTask = nil
        currentGeneration = nil
        state = .failed(error)
        AppLogger.speech.error("Read failed: \(error.errorDescription ?? "unknown")")
        // Surface the error briefly, then return to the resting state.
        failureResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, !Task.isCancelled else { return }
            if case .failed = self.state {
                self.state = .idle
                self.refreshAvailability()
            }
        }
    }
}
