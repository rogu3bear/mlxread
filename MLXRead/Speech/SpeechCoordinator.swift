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
    private(set) var activeConfiguration: SpeechConfiguration?

    private let selection: any SelectionCapturing
    private let player: any AudioPlaying
    private let engineProvider: () -> any SpeechEngine
    private let configurationProvider: () -> SpeechConfiguration
    private let maximumLengthProvider: () -> Int
    /// External availability gates (permission, model present).
    var availabilityCheck: () -> SpeechState? = { nil }
    var sampleAvailabilityCheck: () -> SpeechState? = { nil }

    private var currentGeneration: UUID?
    private var readingTask: Task<Void, Never>?
    private var activeEngine: (any SpeechEngine)?
    private var lastAvailability: SpeechState?

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

    /// Recomputes permission/model gates, retaining errors across unchanged updates.
    func refreshAvailability(clearFailure: Bool = false) {
        guard !state.isBusy else { return }
        let gated = availabilityCheck()
        let availabilityChanged = gated != lastAvailability
        lastAvailability = gated
        if case .failed = state, !clearFailure, !availabilityChanged {
            return
        }
        state = gated ?? .idle
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
        refreshAvailability(clearFailure: true)
        switch state {
        case .idle, .failed:
            break
        case .permissionRequired, .modelRequired, .voiceRequired, .unavailable:
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
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let gated = sampleAvailabilityCheck() {
            state = gated
            return
        }
        startReading(source: .fixedText(text))
    }

    func stop() {
        guard state.isBusy || readingTask != nil else { return }
        state = .stopping
        let task = readingTask
        readingTask = nil
        currentGeneration = nil
        activeConfiguration = nil
        let engine = activeEngine
        activeEngine = nil
        Task { [player] in
            task?.cancel()
            await player.stopImmediately()
            await engine?.cancel()
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
        lastReadWasTruncated = false
        lastAvailability = availabilityCheck()
        let generation = UUID()
        currentGeneration = generation
        activeConfiguration = configurationProvider()
        activeEngine = engineProvider()
        switch source {
        case .selectionCapture: state = .capturing
        case .fixedText: state = .preparing
        }

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
            guard let engine = activeEngine, let configuration = activeConfiguration else { return }
            try await engine.prepare()

            guard isCurrent(generation) else { return }
            state = .generating
            try await player.startSession(generation, speed: engine.handlesSpeechSpeed ? 1.0 : configuration.speed)

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
            AppLogger.selection.info("Captured \(text.count) chars via \(source.rawValue, privacy: .public)")
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
        activeConfiguration = nil
        activeEngine = nil
        state = .idle
        refreshAvailability()
    }

    private func failCurrentRead(generation: UUID, error: UserFacingSpeechError) async {
        guard isCurrent(generation) else { return }
        await player.stopImmediately()
        guard isCurrent(generation) else { return }
        readingTask = nil
        currentGeneration = nil
        activeConfiguration = nil
        activeEngine = nil
        state = .failed(error)
        AppLogger.speech.error("Read failed: \(error.errorDescription ?? "unknown")")
        // Keep recovery information available until the next read or an
        // availability change. Opening Settings must not race a timeout.
    }
}
