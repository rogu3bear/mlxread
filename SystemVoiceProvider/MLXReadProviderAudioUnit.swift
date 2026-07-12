// Audio Unit Speech Extensions (component type 'ausp') render offline, so
// Swift is safe here (Apple's own template states the same).
//
// CURRENT SCOPE: this provider exists to verify, with runtime evidence,
// whether a third-party speech synthesis provider is discovered system-wide
// on macOS (see docs/system-voice-provider.md). Its render path produces a
// deterministic audible waveform rather than MLX speech; wiring the MLX
// engine in requires an app-group container for model access and is only
// worth doing once discovery is proven. Nothing in the host app depends on
// this extension.

import AVFoundation
import os

private let log = Logger(subsystem: "me.jkca.mlxread.SystemVoiceProvider", category: "provider")

public class MLXReadProviderAudioUnit: AVSpeechSynthesisProviderAudioUnit, @unchecked Sendable {
    private var outputBus: AUAudioUnitBus
    private var _outputBusses: AUAudioUnitBusArray!
    private let sampleRate: Double = 24_000

    /// Pending rendered samples, guarded by `stateLock` (offline render).
    private let stateLock = NSLock()
    private var pendingSamples: [Float] = []
    private var cursor = 0

    @objc override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        guard let format = AVAudioFormat(streamDescription: &asbd) else {
            throw NSError(domain: "me.jkca.mlxread.SystemVoiceProvider", code: 1)
        }
        outputBus = try AUAudioUnitBus(format: format)
        try super.init(componentDescription: componentDescription, options: options)
        _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
    }

    public override var outputBusses: AUAudioUnitBusArray { _outputBusses }

    public override var channelCapabilities: [NSNumber] { [0, 1] }

    public override var speechVoices: [AVSpeechSynthesisProviderVoice] {
        get {
            let voice = AVSpeechSynthesisProviderVoice(
                name: "MLXRead Preview",
                identifier: "me.jkca.mlxread.voice.preview",
                primaryLanguages: ["en-US"],
                supportedLanguages: ["en-US"]
            )
            return [voice]
        }
        set {}
    }

    public override func synthesizeSpeechRequest(_ speechRequest: AVSpeechSynthesisProviderRequest) {
        let text = Self.plainText(fromSSML: speechRequest.ssmlRepresentation)
        log.info("synthesizeSpeechRequest: \(text.count) chars for voice \(speechRequest.voice.identifier, privacy: .public)")
        // Deterministic audible placeholder: 440 Hz carrier, one 120 ms pulse
        // per word, 40 ms gaps — long enough to hear and assert on.
        let words = max(1, text.split(whereSeparator: \.isWhitespace).count)
        let pulses = min(words, 40)
        var samples: [Float] = []
        samples.reserveCapacity(Int(sampleRate * 0.16) * pulses)
        let pulseFrames = Int(sampleRate * 0.12)
        let gapFrames = Int(sampleRate * 0.04)
        for _ in 0..<pulses {
            for i in 0..<pulseFrames {
                let t = Double(i) / sampleRate
                let envelope = min(1.0, min(Double(i) / (sampleRate * 0.01), Double(pulseFrames - i) / (sampleRate * 0.02)))
                samples.append(Float(sin(2 * .pi * 440 * t) * 0.3 * max(0, envelope)))
            }
            samples.append(contentsOf: repeatElement(0, count: gapFrames))
        }
        stateLock.lock()
        pendingSamples = samples
        cursor = 0
        stateLock.unlock()
    }

    public override func cancelSpeechRequest() {
        stateLock.lock()
        pendingSamples = []
        cursor = 0
        stateLock.unlock()
        log.info("cancelSpeechRequest")
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        { [weak self] actionFlags, _, frameCount, _, outputAudioBufferList, _, _ in
            guard let self else {
                actionFlags.pointee = AudioUnitRenderActionFlags.offlineUnitRenderAction_Complete
                return noErr
            }
            let bufferList = UnsafeMutableAudioBufferListPointer(outputAudioBufferList)
            guard let frames = bufferList[0].mData?.assumingMemoryBound(to: Float32.self) else {
                return kAudioUnitErr_InvalidParameter
            }

            self.stateLock.lock()
            let available = self.pendingSamples.count - self.cursor
            let toCopy = min(Int(frameCount), max(0, available))
            if toCopy > 0 {
                self.pendingSamples.withUnsafeBufferPointer { source in
                    frames.update(from: source.baseAddress! + self.cursor, count: toCopy)
                }
                self.cursor += toCopy
            }
            let finished = self.cursor >= self.pendingSamples.count
            self.stateLock.unlock()

            if toCopy < Int(frameCount) {
                for i in toCopy..<Int(frameCount) { frames[i] = 0 }
            }
            bufferList[0].mDataByteSize = frameCount * 4

            if finished {
                actionFlags.pointee = AudioUnitRenderActionFlags.offlineUnitRenderAction_Complete
            }
            return noErr
        }
    }

    /// Minimal SSML → text: strips tags, decodes the basic entities. The
    /// system hands us SSML; for the placeholder render only word count
    /// matters, but keep this honest for future MLX wiring.
    static func plainText(fromSSML ssml: String) -> String {
        var text = ssml.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = ["&lt;": "<", "&gt;": ">", "&amp;": "&", "&quot;": "\"", "&apos;": "'"]
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
