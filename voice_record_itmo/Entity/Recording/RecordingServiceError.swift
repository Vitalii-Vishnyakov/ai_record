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
        case .microphonePermissionDenied: return "Mic denied"
        case .audioSession(let e): return "AudioSession error: \(e.localizedDescription)"
        case .recorderInit(let e): return "Recorder init error: \(e.localizedDescription)"
        case .recorderStartFailed: return "Не удалось начать запись"
        case .playerInit(let e): return "Player init error: \(e.localizedDescription)"
        case .noRecorder: return "Recorder не создан"
        case .noPlayer: return "Player не создан"
        case .invalidURL: return "Некорректный URL"
        case .invalidTime: return "Некорректное время"
        }
    }
}
