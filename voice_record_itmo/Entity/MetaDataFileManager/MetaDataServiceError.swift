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
        case .cannotAccessDocuments: return "Не удалось получить доступ к Documents."
        case .cannotCreateDirectory: return "Не удалось создать папку метаданных."
        case .invalidFileName: return "Некорректное имя файла."
        case .notFound: return "Метаданные не найдены."
        case .io(let e): return "Ошибка файловой системы: \(e.localizedDescription)"
        case .decode(let e): return "Не удалось прочитать JSON: \(e.localizedDescription)"
        case .encode(let e): return "Не удалось записать JSON: \(e.localizedDescription)"
        }
    }
}
