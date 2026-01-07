//
//  FileManagerServiceProtocol.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import Foundation

protocol FileManagerServiceProtocol {
    func setLogger(_ logger: FileManagerServiceLogger)

    func recordingsDirectoryURL() throws -> URL
    func recordingURL(id: String, fileExtension: String) throws -> URL

    func createNewRecordingURL(
        preferredName: String?,
        fileExtension: String
    ) throws -> URL

    func listRecordings(
        allowedExtensions: Set<String>,
        sortNewestFirst: Bool
    ) throws -> [FileManagerRecording]

    func exists(url: URL) -> Bool

    func renameRecording(
        from oldURL: URL,
        to newName: String
    ) throws -> URL

    func replaceRecording(
        at targetURL: URL,
        with sourceURL: URL,
        replaceIfExists: Bool
    ) throws

    func deleteRecording(at url: URL) throws

    func deleteAllRecordings(
        allowedExtensions: Set<String>
    ) throws
}
