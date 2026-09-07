# Third-party notices

MLXRead links the following open-source Swift packages:

| Package | Version | License |
|---|---|---|
| [mlx-audio-swift](https://github.com/Blaizzy/mlx-audio-swift) | v0.1.3 (`d302a5c`) | MIT — © 2025 Prince Canuma |
| [mlx-swift](https://github.com/ml-explore/mlx-swift) | 0.31.6 | MIT — © Apple Inc. |
| [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) | 3.31.4 | MIT — © Apple Inc. |
| [swift-transformers](https://github.com/huggingface/swift-transformers) | 1.3.3 | Apache-2.0 — © Hugging Face |
| [swift-huggingface](https://github.com/huggingface/swift-huggingface) | 0.9.0 | Apache-2.0 — © Hugging Face |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | 2.9.4 | MIT — © Andy Matuschak & the Sparkle contributors |
| swift-collections, swift-numerics, swift-atomics, swift-system, swift-nio, swift-crypto, swift-asn1, swift-argument-parser, swift-syntax, Jinja, EventSource, yyjson | (resolved transitively) | Apache-2.0 / MIT — see each repository |

### Sparkle bundled components

Sparkle embeds several components under their own permissive licenses; the
full text is in Sparkle's own `LICENSE`:

| Component | License |
|---|---|
| bsdiff / bspatch (bsdiff 4.3) — © Colin Percival | BSD 2-Clause |
| sais-lite — © Yuta Mori | MIT |
| Portable C Ed25519 implementation — © Orson Peters | zlib |
| SUSignatureVerifier — © Mark Hamlin | BSD 2-Clause |

## Model weights (downloaded by the user at runtime)

| Model | Repository | License |
|---|---|---|
| Kokoro 82M (bf16) | [mlx-community/Kokoro-82M-bf16](https://huggingface.co/mlx-community/Kokoro-82M-bf16) | Apache-2.0 (upstream: hexgrad/Kokoro-82M) |
| Soprano 80M (bf16) | [mlx-community/Soprano-80M-bf16](https://huggingface.co/mlx-community/Soprano-80M-bf16) | Apache-2.0 |
| Qwen3-TTS 12Hz 1.7B CustomVoice (8-bit) | [mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit) | Apache-2.0 — Qwen Team; MLX conversion by MLX Community |
| Chatterbox Turbo fp16 | [mlx-community/chatterbox-turbo-fp16](https://huggingface.co/mlx-community/chatterbox-turbo-fp16) | Apache-2.0 as labeled by the MLX model card; original [Resemble AI model](https://huggingface.co/ResembleAI/chatterbox-turbo) is MIT |
| S3TokenizerV2 | [mlx-community/S3TokenizerV2](https://huggingface.co/mlx-community/S3TokenizerV2) | Converted from [FunAudioLLM/CosyVoice2-0.5B](https://huggingface.co/FunAudioLLM/CosyVoice2-0.5B), Apache-2.0 upstream; conversion card supplies no separate license |
| Pocket TTS | [mlx-community/pocket-tts](https://huggingface.co/mlx-community/pocket-tts) | CC-BY-4.0 — Kyutai; MLX conversion by Lucas Newman / MLX Community |

Pocket's preset voice embeddings derive from Kyutai's published voice catalog.
The [upstream voice catalog](https://huggingface.co/kyutai/tts-voices) provides
individual credits and licenses, including Alba MacKenna's voice under
CC-BY-4.0 and the Voice-Zero selections under CC0. MLXRead downloads the converted weights
and embeddings without modifying them; model cards and credits are also linked
from each model's details in Settings.

Kokoro synthesis additionally downloads grapheme-to-phoneme assets on first
use (fetched by mlx-audio-swift):

| Asset | Repository | License (as stated upstream) |
|---|---|---|
| English G2P lexicons + model | beshkenadze/kitten-tts-g2p | MIT (Misaki / CMUdict-derived) |
| Multilingual IPA lexicons | beshkenadze/kokoro-ipa-lexicons | MIT (gruut-derived) |
| Multilingual neural G2P | beshkenadze/g2p-multilingual-byT5-tiny-mlx | MIT (ByT5-derived) |

License texts are available in each linked repository. Nothing in this list
grants trademark rights.
