//
//  FileManagerFacadeProtocol.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 9.01.26.
//

import Foundation

protocol FileManagerFacadeProtocol: AnyObject {
    func listRecordingsMerged(
        allowedExtensions: Set<String>,
        sortNewestFirst: Bool
    ) throws -> [RecordingBundle]

    func createRecording(
        preferredName: String?,
        fileExtension: String,
        makeMetadata: ((URL) -> RecordingMetadata)?
    ) throws -> RecordingBundle

    func loadMetadata(for metadataId: UUID) throws -> RecordingMetadata
    func updateMetadata(_ metadata: RecordingMetadata) throws
    func deleteMetadata(id: UUID) throws

    func renameRecording(bundle: RecordingBundle, to newName: String) throws -> RecordingBundle
    func deleteRecording(bundle: RecordingBundle) throws
}
