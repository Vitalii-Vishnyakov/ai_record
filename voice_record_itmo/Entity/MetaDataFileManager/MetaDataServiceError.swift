//
//  MetaDataServiceError.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 9.01.26.
//

import Foundation

enum MetaDataServiceError: LocalizedError {
    case cannotAccessDocuments
    case cannotCreateDirectory
    case invalidFileName
    case notFound
    case io(Error)
    case decode(Error)
    case encode(Error)

    var errorDescription: String? {
        switch self {
        case .cannotAccessDocuments:
            return NSLocalizedString("error.metadata.cannot_access_documents", comment: "")
        case .cannotCreateDirectory:
            return NSLocalizedString("error.metadata.cannot_create_directory", comment: "")
        case .invalidFileName:
            return NSLocalizedString("error.metadata.invalid_file_name", comment: "")
        case .notFound:
            return NSLocalizedString("error.metadata.not_found", comment: "")
        case .io(let e):
            let format = NSLocalizedString("error.metadata.io", comment: "")
            return String(format: format, e.localizedDescription)
        case .decode(let e):
            let format = NSLocalizedString("error.metadata.decode", comment: "")
            return String(format: format, e.localizedDescription)
        case .encode(let e):
            let format = NSLocalizedString("error.metadata.encode", comment: "")
            return String(format: format, e.localizedDescription)
        }
    }
}
