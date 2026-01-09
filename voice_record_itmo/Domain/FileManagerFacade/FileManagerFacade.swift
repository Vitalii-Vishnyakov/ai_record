//
//  FileManagerFacade.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 9.01.26.
//

import Foundation

// MARK: - FileManagerFacade

final class FileManagerFacade: FileManagerFacadeProtocol {

    private let files: FileManagerServiceProtocol
    private let metadataStore: MetaDataFileManagerProtocol

    init(
        files: FileManagerServiceProtocol,
        metadataStore: MetaDataFileManagerProtocol
    ) {
        self.files = files
        self.metadataStore = metadataStore
    }

    // MARK: - List & merge

    /// Основной метод для экрана списка.
    /// 1) читает все аудиофайлы
    /// 2) читает все метаданные
    /// 3) пытается "склеить" по metadata.relativePath (или по имени файла как фоллбек)
    func listRecordingsMerged(
        allowedExtensions: Set<String> = ["m4a", "wav", "caf", "aac", "mp3"],
        sortNewestFirst: Bool = true
    ) throws -> [RecordingBundle] {

        let audioItems = try files.listRecordings(
            allowedExtensions: allowedExtensions,
            sortNewestFirst: sortNewestFirst
        )
        let allMeta = try metadataStore.listAll()

        // Index metadata by relativePath filename OR by uuid filename (if you store like that)
        var metaByFileName: [String: RecordingMetadata] = [:]
        metaByFileName.reserveCapacity(allMeta.count)

        for m in allMeta {
            let fileName = (m.relativePath as NSString).lastPathComponent
            if !fileName.isEmpty {
                metaByFileName[fileName] = m
            }
        }

        var result: [RecordingBundle] = []
        result.reserveCapacity(audioItems.count)

        for a in audioItems {
            let fileName = a.fileURL.lastPathComponent
            let meta = metaByFileName[fileName]

            let asset = RecordingAsset(
                id: a.id,
                audioURL: a.fileURL,
                createdAt: a.createdAt,
                sizeBytes: a.sizeBytes
            )

            let bundleId: String = {
                if let meta { return meta.id.uuidString }
                return a.id
            }()

            result.append(
                RecordingBundle(
                    id: bundleId,
                    audio: asset,
                    metadata: meta
                )
            )
        }

        return result
    }

    // MARK: - Create

    /// Создаёт URL для записи (файл) + (опционально) создаёт метаданные через makeMetadata
    /// makeMetadata получает audioURL и возвращает RecordingMetadata (можно вернуть nil, если мета не нужна).
    func createRecording(
        preferredName: String? = nil,
        fileExtension: String = "m4a",
        makeMetadata: ((URL) -> RecordingMetadata)? = nil
    ) throws -> RecordingBundle {

        let audioURL = try files.createNewRecordingURL(preferredName: preferredName, fileExtension: fileExtension)

        let asset = RecordingAsset(
            id: audioURL.deletingPathExtension().lastPathComponent,
            audioURL: audioURL,
            createdAt: Date(),
            sizeBytes: 0
        )

        var meta: RecordingMetadata? = nil
        if let makeMetadata {
            let m = makeMetadata(audioURL)
            try metadataStore.upsert(m)
            meta = m
        }

        let bundleId = meta?.id.uuidString ?? asset.id

        return RecordingBundle(id: bundleId, audio: asset, metadata: meta)
    }

    // MARK: - Metadata

    func loadMetadata(for metadataId: UUID) throws -> RecordingMetadata {
        try metadataStore.read(id: metadataId)
    }

    func updateMetadata(_ metadata: RecordingMetadata) throws {
        try metadataStore.upsert(metadata)
    }

    func deleteMetadata(id: UUID) throws {
        try metadataStore.delete(id: id)
    }

    // MARK: - Rename

    /// Переименовывает аудиофайл. Если есть метаданные — обновляет relativePath и title (опционально).
    func renameRecording(bundle: RecordingBundle, to newName: String) throws -> RecordingBundle {
        let newAudioURL = try files.renameRecording(from: bundle.audio.audioURL, to: newName)

        var updatedMeta = bundle.metadata
        if var m = updatedMeta {
            let oldFileName = (m.relativePath as NSString).lastPathComponent
            let newFileName = newAudioURL.lastPathComponent
            let newRelativePath = m.relativePath.replacingOccurrences(of: oldFileName, with: newFileName)

            m = RecordingMetadata(
                id: m.id,
                title: m.title, // оставляем как есть (или можно поставить newName)
                note: m.note,
                isStarred: m.isStarred,
                createdAt: m.createdAt,
                updatedAt: Date(),
                relativePath: newRelativePath,
                fileExt: m.fileExt,
                fileSizeBytes: m.fileSizeBytes,
                durationSec: m.durationSec,
                lastPlaybackPositionSec: m.lastPlaybackPositionSec,
                playbackRate: m.playbackRate,
                transcript: m.transcript,
                summary: m.summary,
                keywords: m.keywords,
                neuralStatus: m.neuralStatus,
                neuralErrorMessage: m.neuralErrorMessage,
                modelName: m.modelName,
                modelVersion: m.modelVersion
            )

            try metadataStore.upsert(m)
            updatedMeta = m
        }

        let updatedAsset = RecordingAsset(
            id: newAudioURL.deletingPathExtension().lastPathComponent,
            audioURL: newAudioURL,
            createdAt: bundle.audio.createdAt,
            sizeBytes: bundle.audio.sizeBytes
        )

        let id = updatedMeta?.id.uuidString ?? updatedAsset.id
        return RecordingBundle(id: id, audio: updatedAsset, metadata: updatedMeta)
    }

    // MARK: - Delete

    /// Удаляет аудиофайл и, если есть метаданные, удаляет и их.
    func deleteRecording(bundle: RecordingBundle) throws {
        try files.deleteRecording(at: bundle.audio.audioURL)
        if let meta = bundle.metadata {
            try? metadataStore.delete(id: meta.id)
        }
    }
}
