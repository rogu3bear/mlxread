import AVFoundation

/// Playback abstraction the coordinator drives; mocked in tests.
protocol AudioPlaying: Sendable {
    /// Begins a playback session. Only chunks tagged with `id` are accepted
    /// until the session ends.
    func startSession(_ id: UUID, speed: Double) async throws
    /// Converts and schedules one chunk. Suspends when the bounded buffer
    /// queue is full. Chunks from a non-active session are dropped silently.
    func enqueue(_ chunk: SpeechAudioChunk, session: UUID) async throws
    /// Waits until every scheduled buffer has played, then tears the session
    /// down. Returns immediately if the session is no longer active.
    func finishSession(_ id: UUID) async
    /// Stops playback immediately, clearing all scheduled audio.
    func stopImmediately() async
}

/// Streaming playback on one persistent AVAudioEngine per reading session.
///
/// - one `AVAudioPlayerNode`, buffers queued as they arrive;
/// - bounded in-flight buffer count (`AudioQueue`) for backpressure;
/// - `AVAudioUnitTimePitch` for uniform, model-independent speed control;
/// - immediate stop clears scheduled buffers and invalidates the epoch so
///   stale completion callbacks are ignored.
actor StreamingAudioPlayer: AudioPlaying {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let queue = AudioQueue(capacity: 4)

    private var activeSession: UUID?
    private var connectedSampleRate: Double = 0
    private var engineRunning = false

    init() {
        engine.attach(playerNode)
        engine.attach(timePitch)
    }

    func startSession(_ id: UUID, speed: Double) async throws {
        // A new session displaces any prior one.
        teardownPlayback()
        await queue.reset()
        activeSession = id
        timePitch.rate = Float(min(max(speed, 0.5), 3.0))
    }

    func enqueue(_ chunk: SpeechAudioChunk, session: UUID) async throws {
        guard session == activeSession else {
            AppLogger.audio.debug("Dropping chunk from stale session")
            return
        }
        let buffer = try PCMBufferConverter.makeBuffer(
            samples: chunk.samples,
            sampleRate: chunk.sampleRate
        )
        try ensureEngineConfigured(sampleRate: chunk.sampleRate)

        let epoch = await queue.acquire()
        // Session may have been stopped while we waited for a slot.
        guard session == activeSession else {
            await queue.release(epoch: epoch)
            return
        }
        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [queue] _ in
            Task { await queue.release(epoch: epoch) }
        }
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    func finishSession(_ id: UUID) async {
        guard id == activeSession else { return }
        await queue.drain()
        guard id == activeSession else { return } // stopped while draining
        teardownPlayback()
        activeSession = nil
    }

    func stopImmediately() async {
        activeSession = nil
        teardownPlayback()
        await queue.reset()
    }

    // MARK: - Internals

    private func ensureEngineConfigured(sampleRate: Double) throws {
        if connectedSampleRate != sampleRate {
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            ) else { throw PCMBufferConversionError.invalidFormat }
            playerNode.stop()
            engine.disconnectNodeOutput(playerNode)
            engine.disconnectNodeOutput(timePitch)
            engine.connect(playerNode, to: timePitch, format: format)
            engine.connect(timePitch, to: engine.mainMixerNode, format: format)
            connectedSampleRate = sampleRate
        }
        if !engineRunning || !engine.isRunning {
            do {
                try engine.start()
                engineRunning = true
            } catch {
                AppLogger.audio.error("Audio engine failed to start: \(error.localizedDescription)")
                throw UserFacingSpeechError.audioDeviceUnavailable
            }
        }
    }

    private func teardownPlayback() {
        // stop() clears scheduled buffers; pending completion handlers fire
        // but their epoch is stale after queue.reset().
        playerNode.stop()
        if engineRunning {
            engine.stop()
            engineRunning = false
        }
    }
}
