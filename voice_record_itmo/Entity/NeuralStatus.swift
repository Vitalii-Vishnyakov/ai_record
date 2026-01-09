//
//  NeuralStatus.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 9.01.26.
//

import Foundation

enum NeuralStatus: Int16, Codable {
    case idle = 0
    case warmingUp = 1
    case loadingModel = 2
    case processingAudio = 3
    case transcribing = 4
    case summarizing = 5
    case extractingKeywords = 6
    case done = 7
    case error = 8

    private var localizationKey: String {
        switch self {
        case .warmingUp:
            return "nn.warming_up"
        case .loadingModel:
            return "nn.loading_model"
        case .processingAudio:
            return "nn.processing_audio"
        case .transcribing:
            return "nn.transcribing"
        case .summarizing:
            return "nn.summarizing"
        case .extractingKeywords:
            return "nn.extracting_keywords"
        case .idle:
            return "nn.idle"
        case .done:
            return "nn.done"
        case .error:
            return "nn.error"
        }
    }

    var localizedText: String {
        NSLocalizedString(localizationKey, comment: "")
    }
}
