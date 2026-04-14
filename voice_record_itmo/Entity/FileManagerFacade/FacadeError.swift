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
            return NSLocalizedString("error.facade.metadata_missing", comment: "")
        case .metadataIdRequired:
            return NSLocalizedString("error.facade.metadata_id_required", comment: "")
        case .metadataDoesNotMatchAudio:
            return NSLocalizedString("error.facade.metadata_does_not_match_audio", comment: "")
        case .io(let e):
            let format = NSLocalizedString("error.facade.io", comment: "")
            return String(format: format, e.localizedDescription)
        }
    }
}
