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
    let voiceCatalog: ModelVoiceCatalog
    let defaultVoice: String?
    let languages: [String]
    var requiredFiles: [String] = []
    var supportsIndependentLanguage = false
    var additionalDownloads: [ModelAsset] = []

    var downloads: [ModelAsset] {
        [ModelAsset(id: id, approximateSizeMB: approximateSizeMB, requiredFiles: requiredFiles)] + additionalDownloads
    }

    var supportsVoices: Bool { voiceCatalog != .single }
    var downloadSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(downloads.reduce(0) { $0 + $1.approximateSizeMB }) * 1_000_000, countStyle: .file)
    }

    func readingLanguage(voice: String?, requested: String?) -> String {
        if supportsIndependentLanguage {
            if let requested, languages.contains(requested) { return requested }
            return "en-US"
        }
        return supportsVoices ? voiceOption(voice ?? defaultVoice ?? "").languageCode : languages[0]
    }

    func canRead(voice: String?, language: String) -> Bool {
        voiceOption(voice ?? defaultVoice ?? "").supportedLanguages?.contains(language) ?? true
    }

    func voiceOption(_ id: String) -> VoiceOption {
        switch voiceCatalog {
        case .presets(let voices): return voices.first { $0.id == id } ?? VoiceOption(id: id)
        case .files(_, let language) where language != nil:
            return VoiceOption(id: id, displayName: id.capitalized, fixedLanguage: language)
        default: return VoiceOption(id: id)
        }
    }

    /// Directory name used by mlx-audio's cache layout.
    var cacheSubdirectory: String {
        "mlx-audio/" + id.replacingOccurrences(of: "/", with: "_")
    }
}

/// A separately distributed asset required by a catalog model's native loader.
struct ModelAsset: Equatable, Sendable {
    let id: String
    let approximateSizeMB: Int
    var requiredFiles: [String] = []

    var cacheSubdirectory: String { "mlx-audio/" + id.replacingOccurrences(of: "/", with: "_") }
}

enum ModelVoiceCatalog: Equatable, Sendable {
    case single
    case files(directory: String, language: String?)
    case presets([VoiceOption])

    var directory: String? {
        if case .files(let directory, _) = self { return directory }
        return nil
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
        voiceCatalog: .files(directory: "voices", language: nil),
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
        weightsLicense: "Apache-2.0",
        voiceCatalog: .single,
        defaultVoice: nil,
        languages: ["en-US"]
    )

    static let qwen = ModelInfo(
        id: "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit",
        displayName: "Qwen3 · Expressive",
        summary: "Nine voices with delivery control. Ryan and Aiden are native English voices.",
        nominalSampleRate: 24_000,
        approximateSizeMB: 3_080,
        weightsLicense: "Apache-2.0",
        voiceCatalog: .presets([
            VoiceOption(id: "ryan", displayName: "Ryan", fixedLanguage: "en-US"),
            VoiceOption(id: "aiden", displayName: "Aiden", fixedLanguage: "en-US"),
            VoiceOption(id: "vivian", displayName: "Vivian", fixedLanguage: "zh"),
            VoiceOption(id: "serena", displayName: "Serena", fixedLanguage: "zh"),
            VoiceOption(id: "uncle_fu", displayName: "Uncle Fu", fixedLanguage: "zh"),
            VoiceOption(id: "dylan", displayName: "Dylan", fixedLanguage: "zh", supportedLanguages: ["zh"]),
            VoiceOption(id: "eric", displayName: "Eric", fixedLanguage: "zh", supportedLanguages: ["zh"]),
            VoiceOption(id: "ono_anna", displayName: "Ono Anna", fixedLanguage: "ja"),
            VoiceOption(id: "sohee", displayName: "Sohee", fixedLanguage: "ko")
        ]),
        defaultVoice: "ryan",
        languages: ["en-US", "zh", "ja", "ko", "de", "fr", "ru", "pt-BR", "es", "it"],
        requiredFiles: ["vocab.json", "merges.txt", "tokenizer_config.json",
                        "speech_tokenizer/config.json", "speech_tokenizer/model.safetensors"],
        supportsIndependentLanguage: true
    )

    static let pocket = ModelInfo(
        id: "mlx-community/pocket-tts",
        displayName: "Pocket · Lightweight",
        summary: "Eight English voices in a small download. A lightweight alternative to Kokoro.",
        nominalSampleRate: 24_000,
        approximateSizeMB: 240,
        weightsLicense: "CC-BY-4.0 · Kyutai",
        voiceCatalog: .files(directory: "embeddings", language: "en-US"),
        defaultVoice: "alba",
        languages: ["en-US"],
        requiredFiles: ["tokenizer.json"]
    )

    static let chatterbox = ModelInfo(
        id: "mlx-community/chatterbox-turbo-fp16",
        displayName: "Chatterbox Turbo · English",
        summary: "An English speech engine from Resemble AI with one built-in voice.",
        nominalSampleRate: 24_000,
        approximateSizeMB: 2_990,
        weightsLicense: "Apache-2.0 (MLX card); MIT (upstream)",
        voiceCatalog: .single,
        defaultVoice: nil,
        languages: ["en-US"],
        requiredFiles: ["model.safetensors", "conds.safetensors", "vocab.json", "merges.txt", "tokenizer_config.json"],
        additionalDownloads: [ModelAsset(id: "mlx-community/S3TokenizerV2", approximateSizeMB: 495,
                                         requiredFiles: ["model.safetensors"])]
    )

    static let all: [ModelInfo] = [chatterbox, kokoro, qwen, pocket, soprano]
    static let defaultModel = kokoro

    static func model(withID id: String) -> ModelInfo? {
        all.first { $0.id == id }
    }
}

/// Presentation metadata for voice files. The original identifier remains the
/// engine input; unfamiliar voices remain visible without guessed language data.
struct VoiceOption: Identifiable, Equatable, Sendable {
    let id: String
    var displayName: String? = nil
    var fixedLanguage: String? = nil
    var supportedLanguages: [String]? = nil

    private var knownPrefix: String? {
        let prefix = String(id.prefix(2))
        return ["af", "am", "bf", "bm", "ef", "em", "ff", "hf", "hm",
                "if", "im", "jf", "jm", "pf", "pm", "zf", "zm"].contains(prefix)
            && id.dropFirst(2).first == "_" ? prefix : nil
    }

    var name: String {
        if let displayName { return displayName }
        guard knownPrefix != nil else { return id }
        return id.dropFirst(3).replacingOccurrences(of: "_", with: " ").capitalized
    }

    var languageCode: String {
        if let fixedLanguage { return fixedLanguage }
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

    var languageName: String { Self.languageName(languageCode) }

    static func languageName(_ code: String) -> String {
        switch code {
        case "en-US": return "English (US)"
        case "en-GB": return "English (UK)"
        case "es": return "Spanish"
        case "fr": return "French"
        case "hi": return "Hindi"
        case "it": return "Italian"
        case "ja": return "Japanese"
        case "pt-BR": return "Portuguese (Brazil)"
        case "zh": return "Mandarin Chinese"
        case "ko": return "Korean"
        case "de": return "German"
        case "ru": return "Russian"
        default: return "Other voices"
        }
    }

    var menuLabel: String { "\(name) · \(languageName)" }

    var sampleText: String { Self.sampleText(language: languageCode) }

    static func sampleText(language: String) -> String {
        switch language {
        case "es": return "Un buen libro nos invita a descubrir nuevas ideas. Escucha con calma y encuentra tu propio ritmo."
        case "fr": return "Un bon livre nous invite à découvrir de nouvelles idées. Prenez le temps d’écouter et trouvez votre rythme."
        case "hi": return "एक अच्छी किताब हमें नए विचारों से परिचित कराती है। आराम से सुनिए और अपनी पसंद की गति चुनिए।"
        case "it": return "Un buon libro ci invita a scoprire nuove idee. Ascolta con calma e trova il tuo ritmo."
        case "ja": return "良い本は、新しい考えに出会うきっかけになります。ゆっくり聞いて、自分に合った速さを見つけてください。"
        case "pt-BR": return "Um bom livro nos convida a descobrir novas ideias. Ouça com calma e encontre o seu ritmo."
        case "zh": return "一本好书能带来新的想法。请慢慢听，找到适合自己的节奏，让阅读成为一种享受。"
        case "ko": return "좋은 책은 새로운 생각을 만나게 해 줍니다. 편안하게 듣고 자신에게 맞는 속도를 찾아보세요."
        case "de": return "Ein gutes Buch eröffnet neue Gedanken. Hören Sie in Ruhe zu und finden Sie Ihr eigenes Tempo."
        case "ru": return "Хорошая книга открывает новые идеи. Слушайте спокойно и найдите удобный для себя ритм."
        default: return "A good book invites us to discover new ideas. Take a moment to listen, settle in, and find a pace that feels comfortable."
        }
    }
}
