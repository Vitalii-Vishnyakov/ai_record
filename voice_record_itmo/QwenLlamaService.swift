//
//  QwenLlamaService.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 6.01.26.
//

import Foundation
import LlamaSwift

/// Сервис для Qwen (ChatML) поверх mattt/llama.swift.
/// - Модель грузится один раз
/// - На каждый запрос создаётся новый context (способ №2)
/// - Промпт прогоняется чанками по nBatch (не падает при promptTokens > nBatch)
actor QwenLlamaService {
    // MARK: - Config

    private let nCtx: Int32 = 2048
    private let nBatch: Int32 = 512

    // Sampling
    private let maxNewTokens = 200
    private let topK = 40
    private let topP: Float = 0.9
    private let temperature: Float = 0.3

    // MARK: - Model (kept loaded)

    private var model: OpaquePointer?
    private var vocab: OpaquePointer?

    // MARK: - Lifecycle

    func loadModel() throws {
        guard let url = Bundle.main.url(
            forResource: "qwen2.5-1.5b-instruct-q4_k_m",
            withExtension: "gguf"
        ) else {
            fatalError("Model not found in bundle")
        }
        
        if model != nil { return }

        llama_backend_init()

        let mp = llama_model_default_params()
        guard let m = llama_model_load_from_file(url.path, mp) else {
            throw NSError(domain: "LLM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load model at: \(url.path)"])
        }

        self.model = m
        self.vocab = llama_model_get_vocab(m)
    }

    deinit {
        if let model { llama_model_free(model) }
        llama_backend_free()
    }

    // MARK: - Public API

    func summarize(text: String) throws -> String {
        guard let model, let vocab else {
            throw NSError(domain: "LLM", code: 10, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        // 1) Новый context на каждый запрос (KV cache чистый)
        var cp = llama_context_default_params()
        cp.n_ctx = UInt32(nCtx)
        cp.n_batch = UInt32(nBatch)

        guard let ctx = llama_init_from_model(model, cp) else {
            throw NSError(domain: "LLM", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to create context"])
        }
        defer { llama_free(ctx) }

        // 2) ChatML prompt для Qwen
        let system = "Ты помощник. Делай короткое точное резюме."
        let user = "Суммаризируй текст в 5–7 пунктах, без воды:\n\n\(text)"
        let prompt = chatML(system: system, user: user)

        // 3) Tokenize (ВАЖНО: special tokens = true для ChatML)
        let promptTokens = try tokenize(prompt, vocab: vocab)

        // 4) Прогон промпта чанками по nBatch
        let nCur = try evalPromptInChunks(ctx: ctx, promptTokens: promptTokens)

        // 5) Генерация (top-k/top-p sampling), по одному токену за decode
        var out = ""
        var curPos = nCur

        var batch = llama_batch_init(1, 0, 1)
        defer { llama_batch_free(batch) }

        for _ in 0..<maxNewTokens {
            // logits после evalPromptInChunks лежат на последнем токене контекста
            // Получаем logits "последнего" токена. В llama.cpp это обычно i = 0 (последний batch был с logits на последнем токене),
            // но безопаснее брать logits_ith(ctx, 0) только если сейчас batch.n_tokens == 1.
            // Поэтому мы берём logits от последнего вычисленного токена через llama_get_logits(ctx),
            // однако в API llama.cpp чаще используется llama_get_logits_ith(ctx, idx).
            // Мы будем использовать logits_ith(ctx, 0) после каждого decode, так как batch всегда 1 токен.
            guard let logits = llama_get_logits(ctx) else {
                throw NSError(domain: "LLM", code: 20, userInfo: [NSLocalizedDescriptionKey: "Failed to get logits"])
            }

            let next = sampleNextToken(vocab: vocab, logits: logits)

            if next == llama_vocab_eos(vocab) {
                break
            }

            out += tokenToString(vocab: vocab, token: next)

            // decode next token
            batch.n_tokens = 1
            batch.token[0] = next
            batch.pos[0] = curPos
            batch.n_seq_id[0] = 1
            if let seq_ids = batch.seq_id, let seq_id = seq_ids[0] { seq_id[0] = 0 }
            batch.logits[0] = 1

            curPos += 1

            guard llama_decode(ctx, batch) == 0 else {
                throw NSError(domain: "LLM", code: 21, userInfo: [NSLocalizedDescriptionKey: "llama_decode(next) failed"])
            }

            // простая остановка по маркерам ChatML (на случай если модель их выводит)
            if out.contains("<|im_end|>") { break }
        }

        return out
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Prompt + tokenization

    private func chatML(system: String, user: String) -> String {
        """
        <|im_start|>system
        \(system)<|im_end|>
        <|im_start|>user
        \(user)<|im_end|>
        <|im_start|>assistant
        """
    }

    private func tokenize(_ text: String, vocab: OpaquePointer) throws -> [llama_token] {
        let utf8Count = text.utf8.count
        let maxTokenCount = utf8Count + 32
        var tokens = [llama_token](repeating: 0, count: maxTokenCount)

        let n = llama_tokenize(
            vocab,
            text,
            Int32(utf8Count),
            &tokens,
            Int32(maxTokenCount),
            true,  // add BOS
            true   // special tokens (нужно для ChatML)
        )

        if n <= 0 {
            throw NSError(domain: "LLM", code: 12, userInfo: [NSLocalizedDescriptionKey: "Tokenization failed"])
        }

        return Array(tokens.prefix(Int(n)))
    }

    // MARK: - Prompt evaluation in chunks

    /// Прогоняет promptTokens чанками по nBatch.
    /// Возвращает позицию `n_cur` (куда ставить pos для первого генерируемого токена).
    private func evalPromptInChunks(ctx: OpaquePointer, promptTokens: [llama_token]) throws -> Int32 {
        var batch = llama_batch_init(nBatch, 0, 1)
        defer { llama_batch_free(batch) }

        var pos: Int32 = 0
        var offset = 0

        while offset < promptTokens.count {
            let chunkCount = min(Int(nBatch), promptTokens.count - offset)
            batch.n_tokens = Int32(chunkCount)

            for i in 0..<chunkCount {
                batch.token[i] = promptTokens[offset + i]
                batch.pos[i] = pos + Int32(i)
                batch.n_seq_id[i] = 1

                if let seq_ids = batch.seq_id, let seq_id = seq_ids[i] {
                    seq_id[0] = 0
                }

                // logits считаем только на последнем токене последнего чанка
                batch.logits[i] = 0
            }

            if offset + chunkCount == promptTokens.count {
                batch.logits[chunkCount - 1] = 1
            }

            guard llama_decode(ctx, batch) == 0 else {
                throw NSError(domain: "LLM", code: 13, userInfo: [NSLocalizedDescriptionKey: "llama_decode(prompt chunk) failed"])
            }

            pos += Int32(chunkCount)
            offset += chunkCount
        }

        return pos
    }

    // MARK: - Sampling + decoding

    private func sampleNextToken(vocab: OpaquePointer, logits: UnsafePointer<Float>) -> llama_token {
        let vocabSize = Int(llama_vocab_n_tokens(vocab))

        // token + scaled logit
        var items: [(llama_token, Float)] = []
        items.reserveCapacity(vocabSize)

        if temperature > 0 {
            for i in 0..<vocabSize {
                items.append((llama_token(i), logits[i] / temperature))
            }
        } else {
            for i in 0..<vocabSize {
                items.append((llama_token(i), logits[i]))
            }
        }

        // top-k
        items.sort { $0.1 > $1.1 }
        if items.count > topK { items = Array(items.prefix(topK)) }

        // softmax -> probs
        let maxLogit = items[0].1
        var probs = items.map { expf($0.1 - maxLogit) }
        let sum = probs.reduce(0, +)
        if sum > 0 {
            for i in 0..<probs.count { probs[i] /= sum }
        }

        // top-p
        var cut = probs.count
        var cum: Float = 0
        for i in 0..<probs.count {
            cum += probs[i]
            if cum >= topP { cut = i + 1; break }
        }
        items = Array(items.prefix(cut))
        probs = Array(probs.prefix(cut))

        // sample
        var r = Float.random(in: 0..<1)
        var idx = 0
        while idx < probs.count {
            r -= probs[idx]
            if r <= 0 { break }
            idx += 1
        }
        if idx >= items.count { idx = items.count - 1 }

        return items[idx].0
    }

    private func tokenToString(vocab: OpaquePointer, token: llama_token) -> String {
        // 256 обычно достаточно; если хочешь — можно делать динамически при необходимости
        var buf = [CChar](repeating: 0, count: 256)
        let len = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, false)
        guard len > 0 else { return "" }
        return String(cString: buf)
    }
}
