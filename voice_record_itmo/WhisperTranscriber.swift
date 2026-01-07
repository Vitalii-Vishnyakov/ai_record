//
//  WhisperTranscriber.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 25.11.25.
//
import Foundation
import WhisperKit

actor WhisperTranscriber {
    private var pipe: WhisperKit?
    
    func transcribe(fileURL: URL) async throws -> String {
        try await setupIfNeeded()
        
        guard let pipe else {
            throw NSError(domain: "WhisperTranscriber",
                          code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "WhisperKit не инициализирован"])
        }
        
        let path = fileURL.path
        
        // Теперь transcribe возвращает массив
        var opts = DecodingOptions()

        // Язык и режим
        opts.language = "ru"          // русский
        opts.task = .transcribe       // не перевод
        opts.detectLanguage = false   // НЕ определяем язык сами

        // Точность / меньше галлюцинаций
        opts.temperature = 0.1      // «холодная» модель
        opts.topK = 5                 // ограничить вариантов
        opts.noSpeechThreshold = 0.3  // считать тишиной только очень тихий сигнал
        opts.logProbThreshold = -2.0
        opts.firstTokenLogProbThreshold = -2.0
        opts.compressionRatioThreshold = 3.0

        // Таймкоды если не нужны
        opts.withoutTimestamps = true
        opts.wordTimestamps = false

        // Ограничение длины окна (если запись длинная)
        opts.windowClipTime = 30.0    // обрабатывать кусками по ~30 секунд

        let results = try await pipe.transcribe(audioPath: path, decodeOptions: opts)
        
        // Собираем текст из всех сегментов
        let finalText = results.map { $0.text }.joined(separator: " ")
        
        defer { self.pipe = nil }
        return finalText
    }
    
    init() {
        Task {
            try await setupIfNeeded()
        }
    }
    
    private func setupIfNeeded() async throws {
        if pipe != nil { return }
        AppState.shared.state = .modelLoading
        let modelFolderPath = Bundle.main.resourcePath
        
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
            verbose: true,
            logLevel: .debug,
            prewarm: true,
            load: true,
            download: false,
            useBackgroundDownloadSession: false
        )
        
        pipe = try await WhisperKit(config)
        AppState.shared.state = .none
    }
}
