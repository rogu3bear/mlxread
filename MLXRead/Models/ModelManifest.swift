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
        summary: "Choose from 54 voices in eight languages.",
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
        summary: "One English voice with a quick start.",
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

/// Presentation metadata for voice files. The original identifier remains the
/// engine input; unfamiliar voices remain visible without guessed language data.
struct VoiceOption: Identifiable, Equatable {
    let id: String

    private var knownPrefix: String? {
        let prefix = String(id.prefix(2))
        return ["af", "am", "bf", "bm", "ef", "em", "ff", "hf", "hm",
                "if", "im", "jf", "jm", "pf", "pm", "zf", "zm"].contains(prefix)
            && id.dropFirst(2).first == "_" ? prefix : nil
    }

    var name: String {
        guard knownPrefix != nil else { return id }
        return id.dropFirst(3).replacingOccurrences(of: "_", with: " ").capitalized
    }

    var languageCode: String {
        guard let prefix = knownPrefix else { return "other" }
        switch prefix.first {
        case "a": return "en-US"
        case "b": return "en-GB"
        case "e": return "es"
        case "f": return "fr"
        case "h": return "hi"
        case "i": return "it"
        case "j": return "ja"
        case "p": return "pt-BR"
        case "z": return "zh"
        default: return "other"
        }
    }

    var languageName: String {
        switch languageCode {
        case "en-US": return "English (US)"
        case "en-GB": return "English (UK)"
        case "es": return "Spanish"
        case "fr": return "French"
        case "hi": return "Hindi"
        case "it": return "Italian"
        case "ja": return "Japanese"
        case "pt-BR": return "Portuguese (Brazil)"
        case "zh": return "Mandarin Chinese"
        default: return "Other voices"
        }
    }

    var menuLabel: String { "\(name) · \(languageName)" }

    var sampleText: String {
        switch languageCode {
        case "es": return "Un buen libro nos invita a descubrir nuevas ideas. Escucha con calma y encuentra tu propio ritmo."
        case "fr": return "Un bon livre nous invite à découvrir de nouvelles idées. Prenez le temps d’écouter et trouvez votre rythme."
        case "hi": return "एक अच्छी किताब हमें नए विचारों से परिचित कराती है। आराम से सुनिए और अपनी पसंद की गति चुनिए।"
        case "it": return "Un buon libro ci invita a scoprire nuove idee. Ascolta con calma e trova il tuo ritmo."
        case "ja": return "良い本は、新しい考えに出会うきっかけになります。ゆっくり聞いて、自分に合った速さを見つけてください。"
        case "pt-BR": return "Um bom livro nos convida a descobrir novas ideias. Ouça com calma e encontre o seu ritmo."
        case "zh": return "一本好书能带来新的想法。请慢慢听，找到适合自己的节奏，让阅读成为一种享受。"
        default: return "A good book invites us to discover new ideas. Take a moment to listen, settle in, and find a pace that feels comfortable."
        }
    }
}
