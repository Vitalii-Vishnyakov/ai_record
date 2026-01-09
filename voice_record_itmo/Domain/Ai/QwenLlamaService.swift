//
//  QwenLlamaService.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 6.01.26.
//
import Foundation
import LlamaSwift

struct LlamaProgressEvent: Sendable {
    enum Kind: Sendable, Equatable {
        case modelLoading
        case tokenizing
        case evaluatingPrompt
        case generating
        case done
    }

    let kind: Kind
    let fraction: Double          // 0...1
    let message: String
}

typealias LlamaProgressHandler = @Sendable (LlamaProgressEvent) -> Void

actor QwenLlamaService {

    private let nCtx: Int32 = 2048
    private let nBatch: Int32 = 512

    private let maxNewTokens = 200
    private let topK = 40
    private let topP: Float = 0.9
    private let temperature: Float = 0.3

    private var model: OpaquePointer?
    private var vocab: OpaquePointer?

    private var isLoadingModel = false

    deinit {
        if let model { llama_model_free(model) }
        llama_backend_free()
    }

    // MARK: - Async API

    func loadModel(
        deliverOnMainActor: Bool = true,
        progress: LlamaProgressHandler? = nil
    ) async throws {
        if model != nil { return }
        if isLoadingModel { return }

        isLoadingModel = true
        defer { isLoadingModel = false }

        try await emit(progress, deliverOnMainActor, .init(kind: .modelLoading, fraction: 0.01, message: "Инициализация backend"))

        llama_backend_init()

        guard let url = Bundle.main.url(
            forResource: "qwen2.5-1.5b-instruct-q4_k_m",
            withExtension: "gguf"
        ) else {
            throw NSError(domain: "LLM", code: 100, userInfo: [NSLocalizedDescriptionKey: "Model not found in bundle"])
        }

        try await emit(progress, deliverOnMainActor, .init(kind: .modelLoading, fraction: 0.10, message: "Чтение модели"))

        let mp = llama_model_default_params()
        guard let m = llama_model_load_from_file(url.path, mp) else {
            throw NSError(domain: "LLM", code: 101, userInfo: [NSLocalizedDescriptionKey: "Failed to load model at: \(url.path)"])
        }

        self.model = m
        self.vocab = llama_model_get_vocab(m)

        try await emit(progress, deliverOnMainActor, .init(kind: .modelLoading, fraction: 1.0, message: "Модель загружена"))
    }

    func summarize(
        text: String,
        deliverOnMainActor: Bool = true,
        progress: LlamaProgressHandler? = nil
    ) async throws -> String {
        guard let model, let vocab else {
            throw NSError(domain: "LLM", code: 10, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        try await emit(progress, deliverOnMainActor, .init(kind: .tokenizing, fraction: 0.0, message: "Подготовка промпта"))

        var cp = llama_context_default_params()
        cp.n_ctx = UInt32(nCtx)
        cp.n_batch = UInt32(nBatch)

        guard let ctx = llama_init_from_model(model, cp) else {
            throw NSError(domain: "LLM", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to create context"])
        }
        defer { llama_free(ctx) }

        let system = "Ты помощник. Делай короткое точное резюме."
        let user = "Суммаризируй текст в нескольких пунктах, без воды:\n\n\(text)"
        let prompt = chatML(system: system, user: user)

        let promptTokens = try tokenize(prompt, vocab: vocab)

        try await emit(progress, deliverOnMainActor, .init(kind: .tokenizing, fraction: 1.0, message: "Токены: \(promptTokens.count)"))

        let nCur = try await evalPromptInChunks(
            ctx: ctx,
            promptTokens: promptTokens,
            deliverOnMainActor: deliverOnMainActor,
            progress: progress
        )

        try await emit(progress, deliverOnMainActor, .init(kind: .generating, fraction: 0.0, message: "Генерация ответа"))

        var out = ""
        var curPos = nCur

        var batch = llama_batch_init(1, 0, 1)
        defer { llama_batch_free(batch) }

        for i in 0..<maxNewTokens {
            guard let logits = llama_get_logits(ctx) else {
                throw NSError(domain: "LLM", code: 20, userInfo: [NSLocalizedDescriptionKey: "Failed to get logits"])
            }

            let next = sampleNextToken(vocab: vocab, logits: logits)

            if next == llama_vocab_eos(vocab) { break }

            out += tokenToString(vocab: vocab, token: next)

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

            let frac = Double(i + 1) / Double(maxNewTokens)
            try await emit(progress, deliverOnMainActor, .init(kind: .generating, fraction: frac, message: "Токены: \(i + 1)/\(maxNewTokens)"))

            if out.contains("<|im_end|>") { break }
        }

        let cleaned = out
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        try await emit(progress, deliverOnMainActor, .init(kind: .done, fraction: 1.0, message: "Готово"))

        return cleaned
    }

    // MARK: - Emit

    private func emit(
        _ progress: LlamaProgressHandler?,
        _ deliverOnMainActor: Bool,
        _ event: LlamaProgressEvent
    ) async throws {
        guard let progress else { return }
        if deliverOnMainActor {
            await MainActor.run { progress(event) }
        } else {
            progress(event)
        }
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
            true,
            true
        )

        if n <= 0 {
            throw NSError(domain: "LLM", code: 12, userInfo: [NSLocalizedDescriptionKey: "Tokenization failed"])
        }

        return Array(tokens.prefix(Int(n)))
    }

    // MARK: - Prompt evaluation in chunks (with progress)

    private func evalPromptInChunks(
        ctx: OpaquePointer,
        promptTokens: [llama_token],
        deliverOnMainActor: Bool,
        progress: LlamaProgressHandler?
    ) async throws -> Int32 {
        var batch = llama_batch_init(nBatch, 0, 1)
        defer { llama_batch_free(batch) }

        var pos: Int32 = 0
        var offset = 0

        let total = max(1, promptTokens.count)

        while offset < promptTokens.count {
            let chunkCount = min(Int(nBatch), promptTokens.count - offset)
            batch.n_tokens = Int32(chunkCount)

            for i in 0..<chunkCount {
                batch.token[i] = promptTokens[offset + i]
                batch.pos[i] = pos + Int32(i)
                batch.n_seq_id[i] = 1
                if let seq_ids = batch.seq_id, let seq_id = seq_ids[i] { seq_id[0] = 0 }
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

            let frac = Double(offset) / Double(total)
            try await emit(progress, deliverOnMainActor, .init(kind: .evaluatingPrompt, fraction: frac, message: "Промпт: \(offset)/\(promptTokens.count) токенов"))
        }

        return pos
    }

    // MARK: - Sampling + decoding

    private func sampleNextToken(vocab: OpaquePointer, logits: UnsafePointer<Float>) -> llama_token {
        let vocabSize = Int(llama_vocab_n_tokens(vocab))

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

        items.sort { $0.1 > $1.1 }
        if items.count > topK { items = Array(items.prefix(topK)) }

        let maxLogit = items[0].1
        var probs = items.map { expf($0.1 - maxLogit) }
        let sum = probs.reduce(0, +)
        if sum > 0 {
            for i in 0..<probs.count { probs[i] /= sum }
        }

        var cut = probs.count
        var cum: Float = 0
        for i in 0..<probs.count {
            cum += probs[i]
            if cum >= topP { cut = i + 1; break }
        }
        items = Array(items.prefix(cut))
        probs = Array(probs.prefix(cut))

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
        var buf = [CChar](repeating: 0, count: 256)
        let len = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, false)
        guard len > 0 else { return "" }
        return String(cString: buf)
    }
}

//Task {
//    try await qwen.loadModel { ev in
//        self.statusText = ev.message
//        self.modelProgress = ev.fraction
//    }
//
//    let result = try await qwen.summarize(text: bigText) { ev in
//        self.statusText = ev.message
//        self.requestProgress = ev.fraction
//    }
//
//    self.summary = result
//}
