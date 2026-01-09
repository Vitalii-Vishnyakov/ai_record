//
//  RecordingMetadata.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 9.01.26.
//

import Foundation

struct RecordingMetadata: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let note: String?
    let isStarred: Bool

    let createdAt: Date
    let updatedAt: Date

    let relativePath: String
    let fileExt: String
    let fileSizeBytes: Int64
    let durationSec: Double

    let lastPlaybackPositionSec: Double
    let playbackRate: Float

    let transcript: String?
    let summary: String?
    let keywords: [String]
    let neuralStatus: NeuralStatus
    let neuralErrorMessage: String?
    let modelName: String?
    let modelVersion: String?
}
