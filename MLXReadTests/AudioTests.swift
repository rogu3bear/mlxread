import AVFoundation
import XCTest
@testable import MLXRead

final class PCMBufferConverterTests: XCTestCase {

    func testConversionPreservesSamplesAndFormat() throws {
        let samples: [Float] = [0.0, 0.5, -0.5, 1.0, -1.0, 0.25]
        let buffer = try PCMBufferConverter.makeBuffer(samples: samples, sampleRate: 24_000)

        XCTAssertEqual(buffer.frameLength, 6)
        XCTAssertEqual(buffer.format.sampleRate, 24_000)
        XCTAssertEqual(buffer.format.channelCount, 1)
        XCTAssertEqual(buffer.format.commonFormat, .pcmFormatFloat32)

        let out = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: 6)
        XCTAssertEqual(Array(out), samples)
    }

    func testEmptyInputThrows() {
        XCTAssertThrowsError(try PCMBufferConverter.makeBuffer(samples: [], sampleRate: 24_000))
    }

    func testInvalidSampleRateThrows() {
        XCTAssertThrowsError(try PCMBufferConverter.makeBuffer(samples: [0.1], sampleRate: 0))
    }
}

final class AudioQueueTests: XCTestCase {

    func testBoundedAcquireBlocksAtCapacity() async {
        let queue = AudioQueue(capacity: 2)
        let e1 = await queue.acquire()
        _ = await queue.acquire()

        let blocked = expectation(description: "third acquire blocks until release")
        let acquisition = Task {
            _ = await queue.acquire()
            blocked.fulfill()
        }

        // Give the third acquire a moment to (correctly) not complete.
        try? await Task.sleep(for: .milliseconds(100))
        let inFlightBefore = await queue.inFlight
        XCTAssertEqual(inFlightBefore, 2)

        await queue.release(epoch: e1)
        await fulfillment(of: [blocked], timeout: 2)
        acquisition.cancel()
    }

    func testDrainWaitsForAllReleases() async {
        let queue = AudioQueue(capacity: 4)
        let e1 = await queue.acquire()
        let e2 = await queue.acquire()

        let drained = expectation(description: "drain completes")
        Task {
            await queue.drain()
            drained.fulfill()
        }

        try? await Task.sleep(for: .milliseconds(50))
        await queue.release(epoch: e1)
        try? await Task.sleep(for: .milliseconds(50))
        await queue.release(epoch: e2)
        await fulfillment(of: [drained], timeout: 2)
    }

    func testResetUnblocksEverythingAndInvalidatesEpoch() async {
        let queue = AudioQueue(capacity: 1)
        let stale = await queue.acquire()

        let unblocked = expectation(description: "waiter released by reset")
        Task {
            _ = await queue.acquire()
            unblocked.fulfill()
        }
        try? await Task.sleep(for: .milliseconds(50))
        await queue.reset()
        await fulfillment(of: [unblocked], timeout: 2)

        // Stale release from before the reset must be a no-op.
        let countAfterReset = await queue.inFlight
        await queue.release(epoch: stale)
        let countAfterStaleRelease = await queue.inFlight
        XCTAssertEqual(countAfterStaleRelease, countAfterReset, "stale epoch release must not decrement")
    }

    func testStaleSessionChunkDroppedByPlayer() async throws {
        let player = StreamingAudioPlayer()
        let sessionA = UUID()
        let sessionB = UUID()
        try await player.startSession(sessionA, speed: 1.0)
        try await player.startSession(sessionB, speed: 1.0)
        // Chunk for A must be silently dropped; enqueue must not throw or hang.
        let chunk = SpeechAudioChunk(samples: [0.1, 0.2, 0.3], sampleRate: 24_000, index: 0)
        try await player.enqueue(chunk, session: sessionA)
        await player.stopImmediately()
    }
}
