//
//  MapStageToNeuralStatus.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 11.01.26.
//

func mapStageToNeuralStatus(_ stage: AiFacade.ProgressEvent.Stage) -> NeuralStatus {
    return switch stage {
    case .idle:
            .idle
    case .loadingModels:
            .loadingModel
    case .preprocessingAudio:
            .processingAudio
    case .transcribing:
            .transcribing
    case .summarizing:
            .summarizing
    case .done:
            .done
    case .error:
            .error
    }
}
