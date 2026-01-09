//
//  MetaDataFileManagerProtocol.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 9.01.26.
//

import Foundation

protocol MetaDataFileManagerProtocol: AnyObject {

    func setLogger(_ logger: MetaDataFileManagerLogger)

    func upsert(_ metadata: RecordingMetadata) throws

    func read(id: UUID) throws -> RecordingMetadata

    func exists(id: UUID) throws -> Bool

    func delete(id: UUID) throws

    func listAll() throws -> [RecordingMetadata]

    func deleteAll() throws

    func metadataDirectoryURL() throws -> URL
}
