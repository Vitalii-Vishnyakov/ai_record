//
//  voice_record_itmoTests.swift
//  voice_record_itmoTests
//
//  Created by Виталий Вишняков on 14.04.2026.
//

import Foundation
import Testing
@testable import voice_record_itmo

struct voice_record_itmoTests {

    @Test("listRecordingsMerged: metadata matches by file name and metadata id becomes bundle id")
    func listRecordingsMerged_matchesByFileName() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let file1 = URL(fileURLWithPath: "/tmp/meeting_a.m4a")
        let file2 = URL(fileURLWithPath: "/tmp/meeting_b.m4a")

        let fm = FileManagerServiceMock()
        fm.listRecordingsResult = [
            .init(id: "audioA", fileURL: file1, createdAt: now, sizeBytes: 101),
            .init(id: "audioB", fileURL: file2, createdAt: now.addingTimeInterval(-100), sizeBytes: 202)
        ]

        let metaStore = MetaDataFileManagerMock()
        let metaA = makeMetadata(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            title: "A",
            relativePath: "Recordings/meeting_a.m4a",
            createdAt: now
        )
        metaStore.listAllResult = [metaA]

        let sut = FileManagerFacade(files: fm, metadataStore: metaStore)
        let result = try sut.listRecordingsMerged(allowedExtensions: ["m4a"], sortNewestFirst: true)

        #expect(result.count == 2)
        #expect(result[0].metadata?.id == metaA.id)
        #expect(result[0].id == metaA.id.uuidString)
        #expect(result[1].metadata == nil)
        #expect(result[1].id == "audioB")
        #expect(fm.listRecordingsCallCount == 1)
        #expect(metaStore.listAllCallCount == 1)
    }

    @Test("createRecording: with metadata closure writes metadata and returns metadata-based id")
    func createRecording_withMetadata() throws {
        let audioURL = URL(fileURLWithPath: "/tmp/new_recording.m4a")

        let fm = FileManagerServiceMock()
        fm.createNewRecordingURLResult = audioURL

        let metaStore = MetaDataFileManagerMock()
        let sut = FileManagerFacade(files: fm, metadataStore: metaStore)

        let metaID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let bundle = try sut.createRecording(
            preferredName: "new_recording",
            fileExtension: "m4a",
            makeMetadata: { url in
                makeMetadata(
                    id: metaID,
                    title: "new_recording",
                    relativePath: "Recordings/\(url.lastPathComponent)",
                    createdAt: .init(timeIntervalSince1970: 1_700_000_100)
                )
            }
        )

        #expect(bundle.id == metaID.uuidString)
        #expect(bundle.metadata?.id == metaID)
        #expect(bundle.audio.audioURL == audioURL)
        #expect(metaStore.upserted.count == 1)
        #expect(metaStore.upserted.first?.id == metaID)
    }

    @Test("createRecording: without metadata closure does not write metadata")
    func createRecording_withoutMetadata() throws {
        let audioURL = URL(fileURLWithPath: "/tmp/audio_only.m4a")

        let fm = FileManagerServiceMock()
        fm.createNewRecordingURLResult = audioURL

        let metaStore = MetaDataFileManagerMock()
        let sut = FileManagerFacade(files: fm, metadataStore: metaStore)

        let bundle = try sut.createRecording(
            preferredName: nil,
            fileExtension: "m4a",
            makeMetadata: nil
        )

        #expect(bundle.metadata == nil)
        #expect(bundle.id == "audio_only")
        #expect(metaStore.upserted.isEmpty)
    }

    @Test("renameRecording: updates metadata relative path and persists")
    func renameRecording_updatesMetadataPath() throws {
        let oldURL = URL(fileURLWithPath: "/tmp/old_name.m4a")
        let newURL = URL(fileURLWithPath: "/tmp/new_name.m4a")
        let now = Date(timeIntervalSince1970: 1_700_000_200)

        let fm = FileManagerServiceMock()
        fm.renameRecordingResult = newURL

        let metaStore = MetaDataFileManagerMock()
        let sut = FileManagerFacade(files: fm, metadataStore: metaStore)

        let metaID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let metadata = makeMetadata(
            id: metaID,
            title: "Old title",
            relativePath: "Recordings/old_name.m4a",
            createdAt: now
        )

        let bundle = RecordingBundle(
            id: metaID.uuidString,
            audio: .init(id: "old_name", audioURL: oldURL, createdAt: now, sizeBytes: 333),
            metadata: metadata
        )

        let renamed = try sut.renameRecording(bundle: bundle, to: "new_name")

        #expect(renamed.audio.audioURL == newURL)
        #expect(renamed.audio.id == "new_name")
        #expect(renamed.metadata?.relativePath == "Recordings/new_name.m4a")
        #expect(metaStore.upserted.count == 1)
        #expect(metaStore.upserted.first?.relativePath == "Recordings/new_name.m4a")
    }

    @Test("deleteRecording: deletes audio and metadata when metadata exists")
    func deleteRecording_withMetadata() throws {
        let audioURL = URL(fileURLWithPath: "/tmp/to_delete.m4a")
        let now = Date(timeIntervalSince1970: 1_700_000_300)
        let metaID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!

        let fm = FileManagerServiceMock()
        let metaStore = MetaDataFileManagerMock()
        let sut = FileManagerFacade(files: fm, metadataStore: metaStore)

        let bundle = RecordingBundle(
            id: metaID.uuidString,
            audio: .init(id: "to_delete", audioURL: audioURL, createdAt: now, sizeBytes: 444),
            metadata: makeMetadata(
                id: metaID,
                title: "To delete",
                relativePath: "Recordings/to_delete.m4a",
                createdAt: now
            )
        )

        try sut.deleteRecording(bundle: bundle)

        #expect(fm.deletedURLs == [audioURL])
        #expect(metaStore.deletedIDs == [metaID])
    }

    @Test("deleteRecording: deletes only audio when metadata is absent")
    func deleteRecording_withoutMetadata() throws {
        let audioURL = URL(fileURLWithPath: "/tmp/to_delete_no_meta.m4a")
        let now = Date(timeIntervalSince1970: 1_700_000_400)

        let fm = FileManagerServiceMock()
        let metaStore = MetaDataFileManagerMock()
        let sut = FileManagerFacade(files: fm, metadataStore: metaStore)

        let bundle = RecordingBundle(
            id: "audio-only-id",
            audio: .init(id: "to_delete_no_meta", audioURL: audioURL, createdAt: now, sizeBytes: 555),
            metadata: nil
        )

        try sut.deleteRecording(bundle: bundle)

        #expect(fm.deletedURLs == [audioURL])
        #expect(metaStore.deletedIDs.isEmpty)
    }

    @Test("mapStageToNeuralStatus maps all stages deterministically")
    func mapStageToNeuralStatus_allCases() {
        #expect(mapStageToNeuralStatus(.idle) == .idle)
        #expect(mapStageToNeuralStatus(.loadingModels) == .loadingModel)
        #expect(mapStageToNeuralStatus(.preprocessingAudio) == .processingAudio)
        #expect(mapStageToNeuralStatus(.transcribing) == .transcribing)
        #expect(mapStageToNeuralStatus(.summarizing) == .summarizing)
        #expect(mapStageToNeuralStatus(.done) == .done)
        #expect(mapStageToNeuralStatus(.error) == .error)
    }
}

private func makeMetadata(
    id: UUID,
    title: String,
    relativePath: String,
    createdAt: Date
) -> RecordingMetadata {
    .init(
        id: id,
        title: title,
        note: nil,
        isStarred: false,
        createdAt: createdAt,
        updatedAt: createdAt,
        relativePath: relativePath,
        fileExt: "m4a",
        fileSizeBytes: 0,
        durationSec: 0,
        lastPlaybackPositionSec: 0,
        playbackRate: 1.0,
        transcript: nil,
        summary: nil,
        keywords: [],
        neuralStatus: .idle,
        neuralErrorMessage: nil,
        modelName: nil,
        modelVersion: nil
    )
}

private final class FileManagerServiceMock: FileManagerServiceProtocol {
    var listRecordingsResult: [FileManagerRecording] = []
    var createNewRecordingURLResult: URL = URL(fileURLWithPath: "/tmp/default.m4a")
    var renameRecordingResult: URL = URL(fileURLWithPath: "/tmp/renamed.m4a")

    var deletedURLs: [URL] = []
    var listRecordingsCallCount = 0

    func setLogger(_ logger: FileManagerServiceLogger) { }

    func recordingsDirectoryURL() throws -> URL {
        URL(fileURLWithPath: "/tmp")
    }

    func recordingURL(id: String, fileExtension: String) throws -> URL {
        URL(fileURLWithPath: "/tmp/\(id).\(fileExtension)")
    }

    func createNewRecordingURL(preferredName: String?, fileExtension: String) throws -> URL {
        createNewRecordingURLResult
    }

    func listRecordings(allowedExtensions: Set<String>, sortNewestFirst: Bool) throws -> [FileManagerRecording] {
        listRecordingsCallCount += 1
        return listRecordingsResult
    }

    func exists(url: URL) -> Bool { true }

    func renameRecording(from oldURL: URL, to newName: String) throws -> URL {
        renameRecordingResult
    }

    func replaceRecording(at targetURL: URL, with sourceURL: URL, replaceIfExists: Bool) throws { }

    func deleteRecording(at url: URL) throws {
        deletedURLs.append(url)
    }

    func deleteAllRecordings(allowedExtensions: Set<String>) throws { }
}

private final class MetaDataFileManagerMock: MetaDataFileManagerProtocol {
    var listAllResult: [RecordingMetadata] = []
    var readResult: RecordingMetadata?

    var upserted: [RecordingMetadata] = []
    var deletedIDs: [UUID] = []
    var listAllCallCount = 0

    func setLogger(_ logger: MetaDataFileManagerLogger) { }

    func upsert(_ metadata: RecordingMetadata) throws {
        upserted.append(metadata)
    }

    func read(id: UUID) throws -> RecordingMetadata {
        if let readResult {
            return readResult
        }
        throw MetaDataServiceError.notFound
    }

    func exists(id: UUID) throws -> Bool { true }

    func delete(id: UUID) throws {
        deletedIDs.append(id)
    }

    func listAll() throws -> [RecordingMetadata] {
        listAllCallCount += 1
        return listAllResult
    }

    func deleteAll() throws { }

    func metadataDirectoryURL() throws -> URL {
        URL(fileURLWithPath: "/tmp")
    }
}
