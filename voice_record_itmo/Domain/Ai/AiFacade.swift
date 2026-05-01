//
//  AiFacade.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 11.01.26.
//

import Foundation
import Combine

enum SummaryMode: String, CaseIterable, Hashable, Identifiable, Sendable {
    case essence
    case bulletPoints

    var id: String { rawValue }

    var title: String {
        switch self {
        case .essence:
            return L10n.summaryModeEssence.text
        case .bulletPoints:
            return L10n.summaryModeBulletPoints.text
        }
    }

    var userPromptInstruction: String {
        switch self {
        case .essence:
            return "Достань суть текста в 2 предложения. Ответь связным коротким абзацем, без списков и лишних деталей."
        case .bulletPoints:
            return """
            Сожми текст до 6-7 кратких пунктов.
            Строго верни только список: каждый пункт должен быть отдельной строкой и начинаться с маркера "•".
            Не отвечай сплошным абзацем. Не добавляй вступление или заключение.
            """
        }
    }
}

@MainActor
final class AiFacade {

    struct ProgressEvent: Sendable, Equatable {
        enum Stage: Sendable, Equatable {
            case idle
            case loadingModels
            case preprocessingAudio
            case transcribing
            case summarizing
            case done
            case error
        }

        let stage: Stage
        let fraction: Double
        let message: String
    }

    enum AiError: LocalizedError {
        case emptyTranscription
        case emptySummary

        var errorDescription: String? {
            switch self {
            case .emptyTranscription: return NSLocalizedString("ai.facade.error.empty_transcription", comment: "")
            case .emptySummary: return NSLocalizedString("ai.facade.error.empty_summary", comment: "")
            }
        }
    }

    static let shared = AiFacade()

    let progressSubject = CurrentValueSubject<ProgressEvent, Never>(.init(stage: .idle, fraction: 0, message: ""))

    private let whisper: WhisperService
    private let qwen: QwenLlamaService

    private init(
        whisper: WhisperService = WhisperService(defaultLanguage: "ru", verbose: true),
        qwen: QwenLlamaService = QwenLlamaService()
    ) {
        self.whisper = whisper
        self.qwen = qwen
        emit(.init(stage: .idle, fraction: 0, message: ""))
    }

    func resetProgress() {
        emit(.init(stage: .idle, fraction: 0, message: ""))
    }

    func loadModels() async throws {
        emit(.init(stage: .loadingModels, fraction: 0.0, message: NSLocalizedString("ai.facade.progress.loading_whisper", comment: "")))

        try await whisper.loadModel(deliverOnMainActor: true) { [weak self] ev in
            Task { @MainActor in
                guard let self else { return }
                let p = ev.fraction * 0.5
                self.emit(.init(stage: .loadingModels, fraction: p, message: ev.message))
            }
        }

        emit(.init(stage: .loadingModels, fraction: 0.5, message: NSLocalizedString("ai.facade.progress.loading_qwen", comment: "")))

        try await qwen.loadModel(deliverOnMainActor: true) { [weak self] ev in
            Task { @MainActor in
                guard let self else { return }
                let p = 0.5 + ev.fraction * 0.5
                self.emit(.init(stage: .loadingModels, fraction: p, message: ev.message))
            }
        }

        emit(.init(stage: .done, fraction: 1.0, message: NSLocalizedString("ai.facade.progress.models_ready", comment: "")))
    }

    func transcribe(audioURL: URL, language: String = "ru") async throws -> String {
        let text = try await whisper.transcribe(
            fileURL: audioURL,
            language: language,
            deliverOnMainActor: true
        ) { [weak self] ev in
            Task { @MainActor in
                guard let self else { return }
                switch ev.kind {
                case .modelLoading:
                    self.emit(.init(stage: .loadingModels, fraction: ev.fraction, message: ev.message))
                case .preprocessing:
                    self.emit(.init(stage: .preprocessingAudio, fraction: ev.fraction, message: ev.message))
                case .transcribing:
                    self.emit(.init(stage: .transcribing, fraction: ev.fraction, message: ev.message))
                case .done:
                    self.emit(.init(stage: .transcribing, fraction: 1.0, message: NSLocalizedString("ai.facade.progress.transcription_ready", comment: "")))
                }
            }
        }

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            emit(.init(stage: .error, fraction: 1.0, message: AiError.emptyTranscription.localizedDescription))
            throw AiError.emptyTranscription
        }

        return text
    }

    func summarize(text: String, mode: SummaryMode = .bulletPoints) async throws -> String {
        emit(.init(stage: .summarizing, fraction: 0.0, message: NSLocalizedString("ai.facade.progress.summarizing", comment: "")))

        let out = try await qwen.summarize(
            text: text,
            mode: mode,
            deliverOnMainActor: true
        ) { [weak self] ev in
            Task { @MainActor in
                guard let self else { return }
                self.emit(.init(stage: .summarizing, fraction: ev.fraction, message: ev.message))
            }
        }

        let formatted = formatSummary(out, mode: mode)

        if formatted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            emit(.init(stage: .error, fraction: 1.0, message: AiError.emptySummary.localizedDescription))
            throw AiError.emptySummary
        }

        emit(.init(stage: .done, fraction: 1.0, message: NSLocalizedString("ai.facade.progress.summary_ready", comment: "")))
        return formatted
    }

    func summarizeAll(text: String) async throws -> (essence: String, bulletPoints: String) {
        let essence = try await summarize(text: text, mode: .essence)
        let bulletPoints = try await summarize(text: text, mode: .bulletPoints)
        return (essence, bulletPoints)
    }

    func transcribeAndSummarize(
        audioURL: URL,
        language: String = "ru",
        mode: SummaryMode = .bulletPoints
    ) async throws -> (transcript: String, summary: String) {
        let transcript = try await transcribe(audioURL: audioURL, language: language)
        let summary = try await summarize(text: transcript, mode: mode)
        return (transcript, summary)
    }

    func transcribeAndSummarizeAll(
        audioURL: URL,
        language: String = "ru"
    ) async throws -> (transcript: String, essence: String, bulletPoints: String) {
        let transcript = try await transcribe(audioURL: audioURL, language: language)
        let summaries = try await summarizeAll(text: transcript)
        return (transcript: transcript, essence: summaries.essence, bulletPoints: summaries.bulletPoints)
    }

    private func emit(_ event: ProgressEvent) {
        progressSubject.send(event)
    }

    private func formatSummary(_ text: String, mode: SummaryMode) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard mode == .bulletPoints else { return trimmed }
        return formatBulletPoints(trimmed)
    }

    private func formatBulletPoints(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(
                of: #"(?<!^)\s+(?=(?:\d+[\).]|[-*•])\s)"#,
                with: "\n",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var points = normalized
            .components(separatedBy: .newlines)
            .map { cleanBulletPoint($0) }
            .filter { !$0.isEmpty }

        if points.count < 2 {
            points = splitIntoSentences(normalized)
                .map { cleanBulletPoint($0) }
                .filter { !$0.isEmpty }
        }

        if points.count < 2 {
            points = normalized
                .components(separatedBy: CharacterSet(charactersIn: ";"))
                .map { cleanBulletPoint($0) }
                .filter { !$0.isEmpty }
        }

        if points.isEmpty {
            return normalized
        }

        return points
            .prefix(7)
            .map { "• \($0)" }
            .joined(separator: "\n")
    }

    private func cleanBulletPoint(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: #"^\s*(?:[-*•]\s*|\d+[\).]\s*)"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        let delimiters = CharacterSet(charactersIn: ".!?…")

        for scalar in text.unicodeScalars {
            current.unicodeScalars.append(scalar)

            if delimiters.contains(scalar) {
                let sentence = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty {
                    sentences.append(sentence)
                }
                current = ""
            }
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            sentences.append(tail)
        }

        return sentences
    }
}
