//
//  FileManagerRecording.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import Foundation

struct FileManagerRecording: Equatable, Hashable {
    let id: String
    let fileURL: URL
    let createdAt: Date
    let sizeBytes: Int64
}
