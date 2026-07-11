import Darwin
import XCTest
@testable import MLXRead

/// Deterministic local synthesis benchmark. Opt-in:
///   TEST_RUNNER_MLXREAD_BENCHMARK=1 (script/benchmark.sh)
///
/// Prints machine-readable lines prefixed with "BENCHMARK|" that
/// script/benchmark.sh formats. All values are measured, never estimated.
final class BenchmarkTests: XCTestCase {

    static let passage = """
    Reading long passages aloud is the core job of MLXRead. This benchmark \
    passage contains several sentences of ordinary prose, mirroring what a \
    user would select in a browser or an editor. The quick brown fox jumps \
    over the lazy dog while seventeen synthesizers hum quietly in the \
    background. Latency to the first audible word matters more than total \
    throughput, because the reader starts listening immediately. Finally, a \
    concluding sentence rounds out the paragraph at a natural boundary.
    """

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["MLXREAD_BENCHMARK"] == "1",
            "benchmark is opt-in (MLXREAD_BENCHMARK=1)"
        )
        ModelStore.bootstrapEnvironment()
    }

    private func peakFootprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.ledger_phys_footprint_peak) / 1_048_576.0
    }

    private func runBenchmark(model: ModelInfo, voice: String?) async throws {
        let engine = NativeMLXSpeechEngine(modelInfo: model)

        let coldStart = ContinuousClock.now
        try await engine.prepare()
        let coldLoad = ContinuousClock.now - coldStart

        let config = SpeechConfiguration(voice: voice)

        // Warm-up pass so the benchmark measures steady-state latency.
        for try await _ in engine.generate(text: "Warm up pass.", configuration: config) {}

        let synthStart = ContinuousClock.now
        var firstAudio: Duration?
        var totalSamples = 0
        var sampleRate = model.nominalSampleRate
        for try await chunk in engine.generate(text: Self.passage, configuration: config) {
            if firstAudio == nil {
                firstAudio = ContinuousClock.now - synthStart
            }
            totalSamples += chunk.samples.count
            sampleRate = chunk.sampleRate
        }
        let totalSynth = ContinuousClock.now - synthStart

        XCTAssertNotNil(firstAudio, "no audio produced")
        XCTAssertGreaterThan(totalSamples, 0)

        let audioSeconds = Double(totalSamples) / sampleRate
        let synthSeconds = Double(totalSynth.components.seconds)
            + Double(totalSynth.components.attoseconds) * 1e-18
        let firstAudioSeconds = firstAudio.map {
            Double($0.components.seconds) + Double($0.components.attoseconds) * 1e-18
        } ?? 0
        let coldSeconds = Double(coldLoad.components.seconds)
            + Double(coldLoad.components.attoseconds) * 1e-18
        let rtf = synthSeconds > 0 ? audioSeconds / synthSeconds : 0

        print("BENCHMARK|model=\(model.id)")
        print("BENCHMARK|input_chars=\(Self.passage.count)")
        print(String(format: "BENCHMARK|cold_load_s=%.3f", coldSeconds))
        print(String(format: "BENCHMARK|warm_first_audio_s=%.3f", firstAudioSeconds))
        print(String(format: "BENCHMARK|total_synthesis_s=%.3f", synthSeconds))
        print(String(format: "BENCHMARK|audio_duration_s=%.3f", audioSeconds))
        print(String(format: "BENCHMARK|real_time_factor=%.2f", rtf))
        print(String(format: "BENCHMARK|peak_phys_footprint_mb=%.1f", peakFootprintMB()))
    }

    func testBenchmarkSoprano() async throws {
        try await runBenchmark(model: ModelManifest.soprano, voice: nil)
    }

    func testBenchmarkKokoro() async throws {
        try await runBenchmark(model: ModelManifest.kokoro, voice: "af_heart")
    }
}
