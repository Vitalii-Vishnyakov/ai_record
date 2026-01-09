//
//  RecordingAsset.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 9.01.26.
//

import Foundation

struct RecordingAsset: Identifiable, Equatable {
    let id: String                 // base filename without extension (or fallback id)
    let audioURL: URL
    let createdAt: Date
    let sizeBytes: Int64
}
