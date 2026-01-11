//
//  AiFacade.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 11.01.26.
//

import Foundation
import Combine

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
            case .emptyTranscription: return "Пустая транскрипция."
            case .emptySummary: return "Пустая суммаризация."
            }
        }
    }

    static let shared = AiFacade()

    let progressSubject = PassthroughSubject<ProgressEvent, Never>()

    private let whisper: WhisperService
    private let qwen: QwenLlamaService

    private init(
        whisper: WhisperService = WhisperService(defaultLanguage: "ru", verbose: false),
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
        emit(.init(stage: .loadingModels, fraction: 0.0, message: "Загрузка Whisper"))

        try await whisper.loadModel(deliverOnMainActor: true) { [weak self] ev in
            Task { @MainActor in
                guard let self else { return }
                let p = ev.fraction * 0.5
                self.emit(.init(stage: .loadingModels, fraction: p, message: ev.message))
            }
        }

        emit(.init(stage: .loadingModels, fraction: 0.5, message: "Загрузка Qwen"))

        try await qwen.loadModel(deliverOnMainActor: true) { [weak self] ev in
            Task { @MainActor in
                guard let self else { return }
                let p = 0.5 + ev.fraction * 0.5
                self.emit(.init(stage: .loadingModels, fraction: p, message: ev.message))
            }
        }

        emit(.init(stage: .done, fraction: 1.0, message: "Модели готовы"))
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
                    self.emit(.init(stage: .transcribing, fraction: 1.0, message: "Транскрипция готова"))
                }
            }
        }

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            emit(.init(stage: .error, fraction: 1.0, message: AiError.emptyTranscription.localizedDescription))
            throw AiError.emptyTranscription
        }

        return text
    }

    func summarize(text: String) async throws -> String {
        emit(.init(stage: .summarizing, fraction: 0.0, message: "Суммаризация"))

        let out = try await qwen.summarize(
            text: text,
            deliverOnMainActor: true
        ) { [weak self] ev in
            Task { @MainActor in
                guard let self else { return }
                self.emit(.init(stage: .summarizing, fraction: ev.fraction, message: ev.message))
            }
        }

        if out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            emit(.init(stage: .error, fraction: 1.0, message: AiError.emptySummary.localizedDescription))
            throw AiError.emptySummary
        }

        emit(.init(stage: .done, fraction: 1.0, message: "Суммаризация готова"))
        return out
    }

    func transcribeAndSummarize(audioURL: URL, language: String = "ru") async throws -> (transcript: String, summary: String) {
        let transcript = try await transcribe(audioURL: audioURL, language: language)
        let summary = try await summarize(text: transcript)
        return (transcript, summary)
    }

    private func emit(_ event: ProgressEvent) {
        progressSubject.send(event)
    }
}
