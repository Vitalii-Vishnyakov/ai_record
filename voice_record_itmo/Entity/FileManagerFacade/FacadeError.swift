//
//  FacadeError.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 9.01.26.
//

import Foundation

enum FacadeError: LocalizedError {
    case metadataMissing
    case metadataIdRequired
    case metadataDoesNotMatchAudio
    case io(Error)

    var errorDescription: String? {
        switch self {
        case .metadataMissing:
            return "Метаданные отсутствуют."
        case .metadataIdRequired:
            return "Нужен metadata.id для операции."
        case .metadataDoesNotMatchAudio:
            return "Метаданные не соответствуют аудиофайлу."
        case .io(let e):
            return "Ошибка: \(e.localizedDescription)"
        }
    }
}
