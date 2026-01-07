//
//  RecordingViewItem.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import Foundation

struct RecordingViewItem: Identifiable {
    let id: String = UUID().uuidString
    let title: String
    let dateText: String
    let words: Int
    let language: String
    let progress: Double
    let isStarred: Bool
}
