//
//  MetaDataFileManager.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 9.01.26.
//

import Foundation

final class MetaDataFileManager: MetaDataFileManagerProtocol {
    /// Обёртка над моделью, чтобы легко добавлять версию схемы и миграции.
    struct Envelope<T: Codable>: Codable {
        let schemaVersion: Int
        let savedAt: Date
        let payload: T
    }

    // MARK: - Config

    private let fileManager: FileManager
    private let folderName: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var logger: MetaDataFileManagerLogger

    /// Очередь, чтобы операции чтения/записи не гонялись между собой.
    private let queue = DispatchQueue(label: "MetaDataFileManager.queue", qos: .utility)

    /// Текущая версия схемы JSON (на будущее, для миграций).
    private let schemaVersion: Int = 1

    /// По умолчанию: Documents/RecordingMetadata
    init(
        fileManager: FileManager = .default,
        folderName: String = "RecordingMetadata",
        logger: MetaDataFileManagerLogger = MetaDataFileManagerLogger()
    ) {
        self.fileManager = fileManager
        self.folderName = folderName
        self.logger = logger

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        self.logger.info("init(folderName=\(folderName))")
    }

    func setLogger(_ logger: MetaDataFileManagerLogger) {
        self.logger = logger
        self.logger.info("Logger updated (isEnabled=\(logger.isEnabled))")
    }

    // MARK: - Public API (CRUD)

    /// Создать/обновить метаданные.
    func upsert(_ metadata: RecordingMetadata) throws {
        try queue.sync {
            let url = try fileURL(for: metadata.id)

            let envelope = Envelope(schemaVersion: schemaVersion, savedAt: Date(), payload: metadata)

            do {
                let data = try encoder.encode(envelope)
                try writeAtomically(data, to: url)
                logger.info("Upsert ok: \(metadata.id.uuidString)")
            } catch let e as EncodingError {
                logger.error("Encode failed: \(e)")
                throw MetaDataServiceError.encode(e)
            } catch {
                logger.error("Upsert IO failed: \(error)")
                throw MetaDataServiceError.io(error)
            }
        }
    }

    /// Прочитать метаданные по id.
    func read(id: UUID) throws -> RecordingMetadata {
        try queue.sync {
            let url = try fileURL(for: id)

            guard fileManager.fileExists(atPath: url.path) else {
                logger.warning("Read not found: \(id.uuidString)")
                throw MetaDataServiceError.notFound
            }

            do {
                let data = try Data(contentsOf: url)
                // Читаем Envelope, чтобы иметь версию и дату сохранения
                let env = try decoder.decode(Envelope<RecordingMetadata>.self, from: data)

                if env.schemaVersion != schemaVersion {
                    logger.warning("Schema version mismatch: file=\(env.schemaVersion), app=\(schemaVersion)")
                    // Здесь можно добавить миграцию, если понадобится
                }

                logger.debug("Read ok: \(id.uuidString)")
                return env.payload
            } catch let e as DecodingError {
                logger.error("Decode failed: \(e)")
                throw MetaDataServiceError.decode(e)
            } catch {
                logger.error("Read IO failed: \(error)")
                throw MetaDataServiceError.io(error)
            }
        }
    }

    /// Проверить существование.
    func exists(id: UUID) throws -> Bool {
        try queue.sync {
            let url = try fileURL(for: id)
            let ok = fileManager.fileExists(atPath: url.path)
            logger.debug("Exists(\(id.uuidString)) -> \(ok)")
            return ok
        }
    }

    /// Удалить метаданные.
    func delete(id: UUID) throws {
        try queue.sync {
            let url = try fileURL(for: id)

            guard fileManager.fileExists(atPath: url.path) else {
                logger.warning("Delete not found: \(id.uuidString)")
                throw MetaDataServiceError.notFound
            }

            do {
                try fileManager.removeItem(at: url)
                logger.info("Delete ok: \(id.uuidString)")
            } catch {
                logger.error("Delete IO failed: \(error)")
                throw MetaDataServiceError.io(error)
            }
        }
    }

    /// Получить список всех метаданных (читает все json файлы).
    /// Для больших объёмов лучше делать пагинацию или индекс (я скажу как, если нужно).
    func listAll() throws -> [RecordingMetadata] {
        try queue.sync {
            let dir = try metadataDirectoryURL()

            do {
                let urls = try fileManager.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
                let jsons = urls.filter { $0.pathExtension.lowercased() == "json" }

                var result: [RecordingMetadata] = []
                result.reserveCapacity(jsons.count)

                for url in jsons {
                    do {
                        let data = try Data(contentsOf: url)
                        let env = try decoder.decode(Envelope<RecordingMetadata>.self, from: data)
                        result.append(env.payload)
                    } catch {
                        // Один битый файл не должен ломать всё.
                        logger.warning("Skip corrupted file: \(url.lastPathComponent). Error: \(error)")
                    }
                }

                logger.info("listAll -> \(result.count)")
                return result
            } catch {
                logger.error("listAll IO failed: \(error)")
                throw MetaDataServiceError.io(error)
            }
        }
    }

    /// Удалить все json метаданных.
    func deleteAll() throws {
        try queue.sync {
            let dir = try metadataDirectoryURL()
            do {
                let urls = try fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                let jsons = urls.filter { $0.pathExtension.lowercased() == "json" }
                for u in jsons { try? fileManager.removeItem(at: u) }
                logger.warning("deleteAll -> removed \(jsons.count) files")
            } catch {
                logger.error("deleteAll IO failed: \(error)")
                throw MetaDataServiceError.io(error)
            }
        }
    }

    // MARK: - Paths

    func metadataDirectoryURL() throws -> URL {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw MetaDataServiceError.cannotAccessDocuments
        }

        let dir = docs.appendingPathComponent(folderName, isDirectory: true)

        if !fileManager.fileExists(atPath: dir.path) {
            do {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
                logger.info("Created metadata dir: \(dir.path)")
            } catch {
                logger.error("Cannot create metadata dir: \(error)")
                throw MetaDataServiceError.cannotCreateDirectory
            }
        }

        return dir
    }

    func fileURL(for id: UUID) throws -> URL {
        let fileName = sanitizeFileName(id.uuidString.lowercased())
        guard !fileName.isEmpty else { throw MetaDataServiceError.invalidFileName }
        let dir = try metadataDirectoryURL()
        return dir.appendingPathComponent(fileName).appendingPathExtension("json")
    }

    // MARK: - Helpers

    private func writeAtomically(_ data: Data, to url: URL) throws {
        // Data.write(options: .atomic) пишет во временный файл и потом заменяет.
        try data.write(to: url, options: [.atomic])
    }

    private func sanitizeFileName(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let parts = name.components(separatedBy: forbidden)
        return parts.joined(separator: "_")
    }
}
