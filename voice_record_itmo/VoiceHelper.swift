//
//  VoiceHelper.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 24.11.25.
//

import Foundation



protocol DecodeVoiceFromUrl {
    func decode(url: URL)
}

final class VoiceHelper: DecodeVoiceFromUrl {
    private let transcriber: WhisperTranscriber = WhisperTranscriber()
    private weak var delegate: ViewPresentationDelegate?
    
    func decode(url: URL) {
        Task {
            AppState.shared.state = .transcribing
            let text = try await transcriber.transcribe(fileURL: url)
            
            await MainActor.run {
                AppState.shared.state = .none
                delegate?.showSummarizedText(text: text)
            }
        }
    }

    init(delegate: ViewPresentationDelegate) {
        self.delegate = delegate
    }
}
