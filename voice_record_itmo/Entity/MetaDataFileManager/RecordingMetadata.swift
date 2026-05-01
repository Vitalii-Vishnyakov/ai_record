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
    let summaryEssence: String?
    let summaryBulletPoints: String?
    let keywords: [String]
    let neuralStatus: NeuralStatus
    let neuralErrorMessage: String?
    let modelName: String?
    let modelVersion: String?

    init(
        id: UUID,
        title: String,
        note: String?,
        isStarred: Bool,
        createdAt: Date,
        updatedAt: Date,
        relativePath: String,
        fileExt: String,
        fileSizeBytes: Int64,
        durationSec: Double,
        lastPlaybackPositionSec: Double,
        playbackRate: Float,
        transcript: String?,
        summary: String?,
        summaryEssence: String? = nil,
        summaryBulletPoints: String? = nil,
        keywords: [String],
        neuralStatus: NeuralStatus,
        neuralErrorMessage: String?,
        modelName: String?,
        modelVersion: String?
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.isStarred = isStarred
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.relativePath = relativePath
        self.fileExt = fileExt
        self.fileSizeBytes = fileSizeBytes
        self.durationSec = durationSec
        self.lastPlaybackPositionSec = lastPlaybackPositionSec
        self.playbackRate = playbackRate
        self.transcript = transcript
        self.summary = summary
        self.summaryEssence = summaryEssence
        self.summaryBulletPoints = summaryBulletPoints
        self.keywords = keywords
        self.neuralStatus = neuralStatus
        self.neuralErrorMessage = neuralErrorMessage
        self.modelName = modelName
        self.modelVersion = modelVersion
    }
}
