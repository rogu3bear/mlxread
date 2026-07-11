import Foundation

/// Static catalog of the models MLXRead knows how to run.
/// Repo IDs, licenses, and sizes are recorded in docs/technical-decisions.md.
struct ModelInfo: Identifiable, Equatable, Sendable {
    let id: String              // Hugging Face repo ID
    let displayName: String
    let summary: String
    let nominalSampleRate: Double
    let approximateSizeMB: Int
    let weightsLicense: String
    let supportsVoices: Bool
    let defaultVoice: String?
    let languages: [String]

    /// Directory name used by mlx-audio's cache layout.
    var cacheSubdirectory: String {
        "mlx-audio/" + id.replacingOccurrences(of: "/", with: "_")
    }
}

enum ModelManifest {
    /// Kokoro: native implementation present in mlx-audio-swift v0.1.3.
    /// 54 voices, multilingual G2P assets downloaded on first use.
    static let kokoro = ModelInfo(
        id: "mlx-community/Kokoro-82M-bf16",
        displayName: "Kokoro 82M",
        summary: "High-quality multilingual voice (82M, 24 kHz), 54 voices.",
        nominalSampleRate: 24_000,
        approximateSizeMB: 360,
        weightsLicense: "Apache-2.0",
        supportsVoices: true,
        defaultVoice: "af_heart",
        languages: ["en-US", "en-GB", "es", "fr", "hi", "it", "ja", "pt-BR", "zh"]
    )

    /// Soprano: small, fast, English-only. Voice parameter is ignored by the
    /// model, so no voice control is exposed for it.
    static let soprano = ModelInfo(
        id: "mlx-community/Soprano-80M-bf16",
        displayName: "Soprano 80M",
        summary: "Low-latency English voice (80M, 32 kHz).",
        nominalSampleRate: 32_000,
        approximateSizeMB: 200,
        weightsLicense: "See model card",
        supportsVoices: false,
        defaultVoice: nil,
        languages: ["en-US"]
    )

    static let all: [ModelInfo] = [kokoro, soprano]
    static let defaultModel = kokoro

    static func model(withID id: String) -> ModelInfo? {
        all.first { $0.id == id }
    }
}
