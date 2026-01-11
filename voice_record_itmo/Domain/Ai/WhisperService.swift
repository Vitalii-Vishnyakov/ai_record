//
//  WhisperService.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 9.01.26.
//

import Foundation
import WhisperKit
import AVFoundation

actor WhisperService {

    struct ProgressEvent: Sendable {
        enum Kind: Sendable, Equatable {
            case modelLoading
            case preprocessing
            case transcribing
            case done
        }

        let kind: Kind
        let fraction: Double
        let message: String
    }

    typealias ProgressHandler = @Sendable (ProgressEvent) -> Void

    enum ServiceError: LocalizedError {
        case modelNotLoaded
        case emptyResult
        case preprocessFailed(String)

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded: return "Whisper модель не загружена."
            case .emptyResult: return "Whisper вернул пустой результат."
            case .preprocessFailed(let s): return "Подготовка аудио не удалась: \(s)"
            }
        }
    }

    private var pipe: WhisperKit?
    private var isLoading = false

    private let defaultLanguage: String
    private let verbose: Bool

    init(defaultLanguage: String = "ru", verbose: Bool = true) {
        self.defaultLanguage = defaultLanguage
        self.verbose = verbose
    }

    func loadModel(
        deliverOnMainActor: Bool = true,
        progress: ProgressHandler? = nil
    ) async throws {
        if pipe != nil { return }
        if isLoading { return }

        isLoading = true
        defer { isLoading = false }

        try await emit(progress, deliverOnMainActor, .init(kind: .modelLoading, fraction: 0.05, message: "Инициализация WhisperKit"))

        guard let modelFolderPath = Bundle.main.resourcePath else {
            throw NSError(domain: "WhisperService", code: -10, userInfo: [NSLocalizedDescriptionKey: "Bundle.main.resourcePath is nil"])
        }

        let config = WhisperKitConfig(
            model: nil,
            downloadBase: nil,
            modelRepo: nil,
            modelFolder: modelFolderPath,
            tokenizerFolder: nil,
            computeOptions: nil,
            audioProcessor: nil,
            featureExtractor: nil,
            audioEncoder: nil,
            textDecoder: nil,
            logitsFilters: nil,
            segmentSeeker: nil,
            voiceActivityDetector: nil,
            verbose: verbose,
            logLevel: .debug,
            prewarm: true,
            load: true,
            download: false,
            useBackgroundDownloadSession: false
        )

        try await emit(progress, deliverOnMainActor, .init(kind: .modelLoading, fraction: 0.35, message: "Загрузка модели"))
        pipe = try await WhisperKit(config)
        try await emit(progress, deliverOnMainActor, .init(kind: .modelLoading, fraction: 1.0, message: "Whisper готов"))
    }

    func unloadModel() {
        pipe = nil
    }

    func transcribe(
        fileURL: URL,
        language: String? = nil,
        deliverOnMainActor: Bool = true,
        progress: ProgressHandler? = nil
    ) async throws -> String {

        if pipe == nil {
            try await loadModel(deliverOnMainActor: deliverOnMainActor, progress: progress)
        }
        guard let pipe else { throw ServiceError.modelNotLoaded }

        // ПРОСТОЙ препроцессинг:
        // - только приводим к 16kHz mono WAV (без нормализации/фильтров)
        try await emit(progress, deliverOnMainActor, .init(kind: .preprocessing, fraction: 0.0, message: "Подготовка аудио"))
        let preparedURL = try await convertToWhisperFriendlyWav(
            inputURL: fileURL,
            deliverOnMainActor: deliverOnMainActor,
            progress: progress
        )

        defer {
            if preparedURL != fileURL {
                try? FileManager.default.removeItem(at: preparedURL)
            }
        }

        try await emit(progress, deliverOnMainActor, .init(kind: .transcribing, fraction: 0.0, message: "Распознавание"))

        var opts = DecodingOptions()
        opts.language = language ?? defaultLanguage
        opts.task = .transcribe
        opts.detectLanguage = false

        // упор на качество, но без фанатизма
        opts.temperature = 0.0
        opts.topK = 5

        opts.noSpeechThreshold = 0.25
        opts.logProbThreshold = -1.5
        opts.firstTokenLogProbThreshold = -1.5
        opts.compressionRatioThreshold = 2.8

        opts.withoutTimestamps = true
        opts.wordTimestamps = false

        // длинные записи — чанками
        opts.windowClipTime = 25.0

        let results = try await pipe.transcribe(audioPath: preparedURL.path, decodeOptions: opts)

        try await emit(progress, deliverOnMainActor, .init(kind: .transcribing, fraction: 0.9, message: "Сбор результата"))

        let text = results
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let cleaned = postprocess(text: text)
        if cleaned.isEmpty { throw ServiceError.emptyResult }

        try await emit(progress, deliverOnMainActor, .init(kind: .done, fraction: 1.0, message: "Готово"))
        return cleaned
    }

    // MARK: - Simple preprocessing

    private func convertToWhisperFriendlyWav(
        inputURL: URL,
        deliverOnMainActor: Bool,
        progress: ProgressHandler?
    ) async throws -> URL {
        let targetSampleRate: Double = 16_000
        let targetChannels: AVAudioChannelCount = 1

        let tmp = FileManager.default.temporaryDirectory
        let outURL = tmp.appendingPathComponent("whisper_\(UUID().uuidString)").appendingPathExtension("wav")

        let inFile = try AVAudioFile(forReading: inputURL)
        let inFormat = inFile.processingFormat

        guard let outFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: false
        ) else {
            throw ServiceError.preprocessFailed("Не удалось создать output format")
        }

        guard let converter = AVAudioConverter(from: inFormat, to: outFormat) else {
            throw ServiceError.preprocessFailed("Не удалось создать AVAudioConverter")
        }

        let outFile = try AVAudioFile(forWriting: outURL, settings: outFormat.settings)

        let inCap: AVAudioFrameCount = 8192
        guard let inBuffer = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: inCap) else {
            throw ServiceError.preprocessFailed("Не удалось создать input buffer")
        }

        let outCap: AVAudioFrameCount = 8192
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: outCap) else {
            throw ServiceError.preprocessFailed("Не удалось создать output buffer")
        }

        let totalFrames = max(1, Int64(inFile.length))
        var processed: Int64 = 0

        while true {
            try inFile.read(into: inBuffer)
            if inBuffer.frameLength == 0 { break }

            var err: NSError?
            let status = converter.convert(to: outBuffer, error: &err) { _, outStatus in
                outStatus.pointee = .haveData
                return inBuffer
            }

            if status == .error {
                throw ServiceError.preprocessFailed(err?.localizedDescription ?? "convert error")
            }

            try outFile.write(from: outBuffer)

            processed += Int64(outBuffer.frameLength)
            outBuffer.frameLength = 0

            let frac = min(1.0, Double(processed) / Double(totalFrames))
            try await emit(progress, deliverOnMainActor, .init(kind: .preprocessing, fraction: frac, message: "Конвертация \(Int(frac * 100))%"))
        }

        return outURL
    }

    // MARK: - Helpers

    private func emit(
        _ progress: ProgressHandler?,
        _ deliverOnMainActor: Bool,
        _ event: ProgressEvent
    ) async throws {
        guard let progress else { return }
        if deliverOnMainActor {
            await MainActor.run { progress(event) }
        } else {
            progress(event)
        }
    }

    private func postprocess(text: String) -> String {
        var s = text
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        for p in [".", ",", "!", "?", ":", ";"] {
            s = s.replacingOccurrences(of: " \(p)", with: p)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

//let whisper = WhisperService(defaultLanguage: "ru", verbose: true)
//
//Task {
//    try await whisper.loadModel { ev in
//        print(ev.kind, ev.fraction, ev.message)
//    }
//
//    let text = try await whisper.transcribe(fileURL: url) { ev in
//        print(ev.kind, ev.fraction, ev.message)
//    }
//
//    print(text)
//}
