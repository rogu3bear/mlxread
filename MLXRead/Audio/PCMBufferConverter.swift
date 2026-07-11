import AVFoundation

enum PCMBufferConversionError: Error {
    case invalidFormat
    case allocationFailed
    case emptyInput
}

/// Converts raw mono float samples from a speech engine into
/// `AVAudioPCMBuffer`s suitable for `AVAudioPlayerNode` scheduling.
enum PCMBufferConverter {
    static func makeBuffer(samples: [Float], sampleRate: Double) throws -> AVAudioPCMBuffer {
        guard !samples.isEmpty else { throw PCMBufferConversionError.emptyInput }
        guard sampleRate > 0,
              let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
              )
        else { throw PCMBufferConversionError.invalidFormat }

        let frameCount = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData
        else { throw PCMBufferConversionError.allocationFailed }

        samples.withUnsafeBufferPointer { source in
            channel[0].update(from: source.baseAddress!, count: samples.count)
        }
        buffer.frameLength = frameCount
        return buffer
    }
}
