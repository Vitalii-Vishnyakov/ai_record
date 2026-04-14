//
//  FileManagerServiceError.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import Foundation

enum FileManagerServiceError: LocalizedError {
    case cannotAccessDocuments
    case cannotCreateDirectory
    case fileNotFound
    case fileAlreadyExists
    case renameConflict
    case invalidName
    case io(Error)

    var errorDescription: String? {
        switch self {
        case .cannotAccessDocuments:
            return NSLocalizedString("error.file_manager.cannot_access_documents", comment: "")
        case .cannotCreateDirectory:
            return NSLocalizedString("error.file_manager.cannot_create_directory", comment: "")
        case .fileNotFound:
            return NSLocalizedString("error.file_manager.file_not_found", comment: "")
        case .fileAlreadyExists:
            return NSLocalizedString("error.file_manager.file_already_exists", comment: "")
        case .renameConflict:
            return NSLocalizedString("error.file_manager.rename_conflict", comment: "")
        case .invalidName:
            return NSLocalizedString("error.file_manager.invalid_name", comment: "")
        case .io(let err):
            let format = NSLocalizedString("error.file_manager.io", comment: "")
            return String(format: format, err.localizedDescription)
        }
    }
}
