//
//  NeuralStatus.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 9.01.26.
//

import Foundation

enum NeuralStatus: Equatable {
    case warmingUp
    case loadingModel
    case processingAudio
    case transcribing
    case summarizing
    case extractingKeywords
    case idle
    case done
    case error

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
