//
//  RecordingViewItem.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import Foundation

struct RecordingViewItem: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let dateText: String
    let duration: Int
    let progress: Double
    let isStarred: Bool
    let isTranscribed: Bool
    let isSummurized: Bool
    var isPlaying: Bool

    let audioURL: URL
    let metadataId: UUID?
}
