//
//  FileManagerService.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import Foundation

final class FileManagerService: FileManagerServiceProtocol {

    // MARK: - Config

    private let fileManager: FileManager
    private let recordingsFolderName: String
    private var logger: FileManagerServiceLogger

    /// По умолчанию: Documents/Recordings
    init(
        fileManager: FileManager = .default,
        recordingsFolderName: String = "Recordings",
        logger: FileManagerServiceLogger = FileManagerServiceLogger()
    ) {
        self.fileManager = fileManager
        self.recordingsFolderName = recordingsFolderName
        self.logger = logger
        self.logger.info("init(fileManager:default, recordingsFolderName:\(recordingsFolderName))")
    }

    /// Можно менять логгер после инициализации (например включить/выключить, сменить sink).
    func setLogger(_ logger: FileManagerServiceLogger) {
        self.logger = logger
        self.logger.info("Logger updated (isEnabled=\(logger.isEnabled))")
    }

    // MARK: - Paths

    /// URL папки Documents/Recordings (создаётся при необходимости)
    func recordingsDirectoryURL() throws -> URL {
        logger.debug("recordingsDirectoryURL()")

        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Cannot access Documents directory")
            throw FileManagerServiceError.cannotAccessDocuments
        }

        let dir = docs.appendingPathComponent(recordingsFolderName, isDirectory: true)

        if !fileManager.fileExists(atPath: dir.path) {
            logger.info("Recordings directory not found. Creating: \(dir.path)")
            do {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
                logger.info("Directory created: \(dir.path)")
            } catch {
                logger.error("Failed to create directory: \(dir.path). Error: \(error)")
                throw FileManagerServiceError.cannotCreateDirectory
            }
        } else {
            logger.debug("Directory exists: \(dir.path)")
        }

        return dir
    }

    /// URL файла по id + расширение (без проверки существования)
    func recordingURL(id: String, fileExtension: String = "m4a") throws -> URL {
        logger.debug("recordingURL(id:\(id), ext:\(fileExtension))")

        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidFileName(cleanId) else {
            logger.warning("Invalid id for file name: '\(id)' -> '\(cleanId)'")
            throw FileManagerServiceError.invalidName
        }

        let dir = try recordingsDirectoryURL()
        let url = dir.appendingPathComponent(cleanId).appendingPathExtension(fileExtension)
        logger.debug("Resolved URL: \(url.path)")
        return url
    }

    // MARK: - CREATE

    /// Резервирует путь под новую запись (полезно перед началом AVAudioRecorder).
    /// Возвращает URL, который можно сразу использовать для записи.
    func createNewRecordingURL(
        preferredName: String? = nil,
        fileExtension: String = "m4a"
    ) throws -> URL {
        logger.info("createNewRecordingURL(preferredName:\(preferredName ?? "nil"), ext:\(fileExtension))")

        let dir = try recordingsDirectoryURL()

        let baseName: String
        if let preferredName, !preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let sanitized = sanitizeFileName(preferredName)
            guard isValidFileName(sanitized) else {
                logger.warning("Invalid preferredName after sanitize: '\(preferredName)' -> '\(sanitized)'")
                throw FileManagerServiceError.invalidName
            }
            baseName = sanitized
        } else {
            baseName = makeDefaultName()
        }

        var url = dir.appendingPathComponent(baseName).appendingPathExtension(fileExtension)

        if fileManager.fileExists(atPath: url.path) {
            logger.warning("File already exists: \(url.lastPathComponent). Generating unique name...")
            url = try makeUniqueURL(baseName: baseName, ext: fileExtension)
        }

        logger.info("New recording URL: \(url.path)")
        return url
    }

    // MARK: - READ (list / get)

    /// Список записей в папке (по умолчанию по дате создания, новые сверху)
    func listRecordings(
        allowedExtensions: Set<String> = ["m4a", "wav", "caf", "aac", "mp3"],
        sortNewestFirst: Bool = true
    ) throws -> [FileManagerRecording] {
        logger.info("listRecordings(allowedExtensions:\(allowedExtensions.sorted()), sortNewestFirst:\(sortNewestFirst))")

        let dir = try recordingsDirectoryURL()

        do {
            let urls = try fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            logger.debug("Directory items found: \(urls.count)")

            let filtered = urls.filter { url in
                guard !url.hasDirectoryPath else { return false }
                let ext = url.pathExtension.lowercased()
                return allowedExtensions.contains(ext)
            }

            logger.debug("Filtered recordings: \(filtered.count)")

            let mapped: [FileManagerRecording] = filtered.compactMap { url in
                do {
                    let values = try url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                    let createdAt = values.creationDate ?? Date.distantPast
                    let size = Int64(values.fileSize ?? 0)
                    let id = url.deletingPathExtension().lastPathComponent
                    return FileManagerRecording(id: id, fileURL: url, createdAt: createdAt, sizeBytes: size)
                } catch {
                    logger.warning("Failed to read resource values for \(url.lastPathComponent): \(error)")
                    let id = url.deletingPathExtension().lastPathComponent
                    return FileManagerRecording(id: id, fileURL: url, createdAt: Date.distantPast, sizeBytes: 0)
                }
            }

            let sorted = mapped.sorted { a, b in
                sortNewestFirst ? (a.createdAt > b.createdAt) : (a.createdAt < b.createdAt)
            }

            logger.info("Returning recordings: \(sorted.count)")
            return sorted
        } catch {
            logger.error("Failed to list directory contents: \(dir.path). Error: \(error)")
            throw FileManagerServiceError.io(error)
        }
    }

    /// Быстрая проверка, существует ли файл
    func exists(url: URL) -> Bool {
        let ok = fileManager.fileExists(atPath: url.path)
        logger.debug("exists(\(url.lastPathComponent)) -> \(ok)")
        return ok
    }

    // MARK: - UPDATE (rename / replace)

    /// Переименовать запись (в той же папке). Возвращает новый URL.
    func renameRecording(from oldURL: URL, to newName: String) throws -> URL {
        logger.info("renameRecording(from:\(oldURL.lastPathComponent), to:\(newName))")

        let newNameSanitized = sanitizeFileName(newName)
        guard isValidFileName(newNameSanitized) else {
            logger.warning("Invalid newName after sanitize: '\(newName)' -> '\(newNameSanitized)'")
            throw FileManagerServiceError.invalidName
        }

        guard fileManager.fileExists(atPath: oldURL.path) else {
            logger.warning("File not found for rename: \(oldURL.path)")
            throw FileManagerServiceError.fileNotFound
        }

        let ext = oldURL.pathExtension
        let dir = oldURL.deletingLastPathComponent()
        let newURL = dir.appendingPathComponent(newNameSanitized).appendingPathExtension(ext)

        if fileManager.fileExists(atPath: newURL.path) {
            logger.warning("Rename conflict, target exists: \(newURL.lastPathComponent)")
            throw FileManagerServiceError.renameConflict
        }

        do {
            try fileManager.moveItem(at: oldURL, to: newURL)
            logger.info("Renamed to: \(newURL.lastPathComponent)")
            return newURL
        } catch {
            logger.error("Rename failed. Error: \(error)")
            throw FileManagerServiceError.io(error)
        }
    }

    /// Заменить файл содержимым из другого URL (например, после обработки).
    /// Если replaceIfExists=false и целевой файл существует — ошибка.
    func replaceRecording(
        at targetURL: URL,
        with sourceURL: URL,
        replaceIfExists: Bool = true
    ) throws {
        logger.info("replaceRecording(target:\(targetURL.lastPathComponent), source:\(sourceURL.lastPathComponent), replaceIfExists:\(replaceIfExists))")

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            logger.warning("Source not found: \(sourceURL.path)")
            throw FileManagerServiceError.fileNotFound
        }

        if fileManager.fileExists(atPath: targetURL.path) {
            if !replaceIfExists {
                logger.warning("Target exists and replaceIfExists=false: \(targetURL.path)")
                throw FileManagerServiceError.fileAlreadyExists
            }
            do {
                _ = try fileManager.replaceItemAt(targetURL, withItemAt: sourceURL)
                logger.info("Replaced: \(targetURL.lastPathComponent)")
                return
            } catch {
                logger.error("Replace failed: \(error)")
                throw FileManagerServiceError.io(error)
            }
        } else {
            do {
                try fileManager.copyItem(at: sourceURL, to: targetURL)
                logger.info("Copied to new target: \(targetURL.lastPathComponent)")
            } catch {
                logger.error("Copy failed: \(error)")
                throw FileManagerServiceError.io(error)
            }
        }
    }

    // MARK: - DELETE

    func deleteRecording(at url: URL) throws {
        logger.info("deleteRecording(\(url.lastPathComponent))")

        guard fileManager.fileExists(atPath: url.path) else {
            logger.warning("File not found for delete: \(url.path)")
            throw FileManagerServiceError.fileNotFound
        }

        do {
            try fileManager.removeItem(at: url)
            logger.info("Deleted: \(url.lastPathComponent)")
        } catch {
            logger.error("Delete failed: \(error)")
            throw FileManagerServiceError.io(error)
        }
    }

    /// Удалить все записи (осторожно)
    func deleteAllRecordings(
        allowedExtensions: Set<String> = ["m4a", "wav", "caf", "aac", "mp3"]
    ) throws {
        logger.warning("deleteAllRecordings() called")

        let items = try listRecordings(allowedExtensions: allowedExtensions)
        logger.info("Deleting \(items.count) recordings...")

        var deleted = 0
        for item in items {
            do {
                try deleteRecording(at: item.fileURL)
                deleted += 1
            } catch {
                logger.warning("Failed to delete \(item.fileURL.lastPathComponent): \(error)")
            }
        }

        logger.info("deleteAllRecordings() done. Deleted: \(deleted)/\(items.count)")
    }

    // MARK: - Helpers

    private func makeDefaultName() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "Recording_\(f.string(from: Date()))"
    }

    private func makeUniqueURL(baseName: String, ext: String) throws -> URL {
        let dir = try recordingsDirectoryURL()
        var i = 2
        while true {
            let candidate = dir
                .appendingPathComponent("\(baseName)_\(i)")
                .appendingPathExtension(ext)
            if !fileManager.fileExists(atPath: candidate.path) {
                logger.debug("Unique URL generated: \(candidate.lastPathComponent)")
                return candidate
            }
            i += 1
            if i > 10_000 {
                logger.error("Too many conflicts generating unique filename for baseName=\(baseName)")
                throw FileManagerServiceError.fileAlreadyExists
            }
        }
    }

    private func sanitizeFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let forbidden = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let parts = trimmed.components(separatedBy: forbidden)
        let joined = parts.joined(separator: "_")

        return joined
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "_")
    }

    private func isValidFileName(_ name: String) -> Bool {
        if name.isEmpty { return false }
        if name == "." || name == ".." { return false }
        if name.count > 120 { return false }

        let forbidden = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.rangeOfCharacter(from: forbidden) == nil
    }
}
