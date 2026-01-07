//
//  RecordingState.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

enum RecordingState: Equatable {
    case idle
    case recording
    case pausedRecording
    case playing
    case pausedPlayback
}
