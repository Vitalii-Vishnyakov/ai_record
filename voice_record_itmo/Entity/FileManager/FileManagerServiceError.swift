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
        case .cannotAccessDocuments: return "Не удалось получить доступ к папке Documents."
        case .cannotCreateDirectory: return "Не удалось создать папку для записей."
        case .fileNotFound: return "Файл не найден."
        case .fileAlreadyExists: return "Файл с таким именем уже существует."
        case .renameConflict: return "Невозможно переименовать: имя уже занято."
        case .invalidName: return "Некорректное имя файла."
        case .io(let err): return "Ошибка файловой системы: \(err.localizedDescription)"
        }
    }
}
