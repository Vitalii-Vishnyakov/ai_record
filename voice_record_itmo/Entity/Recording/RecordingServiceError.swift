//
//  RecordingServiceError.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import Foundation

enum RecordingServiceError: LocalizedError {
    case audioSession(Error)
    case recorderInit(Error)
    case recorderStartFailed
    case playerInit(Error)
    case noRecorder
    case noPlayer
    case invalidURL
    case invalidTime
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return NSLocalizedString("error.recording.microphone_permission_denied", comment: "")
        case .audioSession(let e):
            let format = NSLocalizedString("error.recording.audio_session", comment: "")
            return String(format: format, e.localizedDescription)
        case .recorderInit(let e):
            let format = NSLocalizedString("error.recording.recorder_init", comment: "")
            return String(format: format, e.localizedDescription)
        case .recorderStartFailed:
            return NSLocalizedString("error.recording.recorder_start_failed", comment: "")
        case .playerInit(let e):
            let format = NSLocalizedString("error.recording.player_init", comment: "")
            return String(format: format, e.localizedDescription)
        case .noRecorder:
            return NSLocalizedString("error.recording.no_recorder", comment: "")
        case .noPlayer:
            return NSLocalizedString("error.recording.no_player", comment: "")
        case .invalidURL:
            return NSLocalizedString("error.recording.invalid_url", comment: "")
        case .invalidTime:
            return NSLocalizedString("error.recording.invalid_time", comment: "")
        }
    }
}
