//
//  RecordingBundle.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 9.01.26.
//

import Foundation

struct RecordingBundle: Identifiable, Equatable {
    /// Stable ID for UI lists.
    /// Prefer metadata.id if present, otherwise fallback to audio-based id.
    let id: String

    let audio: RecordingAsset
    let metadata: RecordingMetadata?

    var title: String {
        if let metadata, !metadata.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return metadata.title
        }
        return audio.id
    }

    var isStarred: Bool { metadata?.isStarred ?? false }
    var durationSec: Double? { metadata?.durationSec }
}
