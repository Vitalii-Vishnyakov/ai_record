//
//  L10n.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 9.01.26.
//

import Foundation

enum L10n {

    // MARK: - App
    case appTitle
    case recordingsTitle
    case newRecordingTitle

    // MARK: - Filters
    case filterAll
    case filterToday
    case filterThisWeek
    case filterStarred

    // MARK: - Recording list
    case recordingNote
    case recordingYesterday
    case recordingRecognized
    case recordingSummarized

    // MARK: - Player
    case playerPlay
    case playerPause
    case playerStop
    case playerSpeed

    // MARK: - Recording screen
    case recordingInProgress
    case recordPaused
    case recordingName
    case recordingNamePlaceholder

    // MARK: - Transcript / Summary
    case transcriptFull
    case summaryTitle
    case aiSummary
    case copy
    case keywords

    // MARK: - Neural network statuses
    case nnWarmingUp
    case nnLoadingModel
    case nnProcessingAudio
    case nnTranscribing
    case nnSummarizing
    case nnExtractingKeywords
    case nnIdle
    case nnDone
    case nnError

    // MARK: - Alerts: Delete
    case alertDeleteTitle
    case alertDeleteMessage
    case alertDeleteConfirm
    case alertDeleteCancel

    // MARK: - Alerts: Rename
    case alertRenameTitle
    case alertRenamePlaceholder
    case alertRenameSave
    case alertRenameCancel

    // MARK: - Alerts: Exit recording
    case alertExitRecordingTitle
    case alertExitRecordingMessage
    case alertExitRecordingConfirm
    case alertExitRecordingCancel

    // MARK: - Errors
    case errorGeneric
    case errorAudioPermission

    // MARK: - Localization

    var key: String {
        switch self {

        case .appTitle: return "app.title"
        case .recordingsTitle: return "recordings.title"
        case .newRecordingTitle: return "new.recording.title"

        case .filterAll: return "filter.all"
        case .filterToday: return "filter.today"
        case .filterThisWeek: return "filter.this_week"
        case .filterStarred: return "filter.starred"

        case .recordingNote: return "recording.note"
        case .recordingYesterday: return "recording.yesterday"
        case .recordingRecognized: return "recording.recognized"
        case .recordingSummarized: return "recording.summarized"

        case .playerPlay: return "player.play"
        case .playerPause: return "player.pause"
        case .playerStop: return "player.stop"
        case .playerSpeed: return "player.speed"

        case .recordingInProgress: return "recording.in_progress"
        case .recordPaused: return "recording.paused"
        case .recordingName: return "recording.name"
        case .recordingNamePlaceholder: return "recording.name.placeholder"

        case .transcriptFull: return "transcript.full"
        case .summaryTitle: return "summary.title"
        case .aiSummary: return "ai.summary"
        case .copy: return "copy"
        case .keywords: return "keywords"

        case .nnWarmingUp: return "nn.warming_up"
        case .nnLoadingModel: return "nn.loading_model"
        case .nnProcessingAudio: return "nn.processing_audio"
        case .nnTranscribing: return "nn.transcribing"
        case .nnSummarizing: return "nn.summarizing"
        case .nnExtractingKeywords: return "nn.extracting_keywords"
        case .nnIdle: return "nn.idle"
        case .nnDone: return "nn.done"
        case .nnError: return "nn.error"

        case .alertDeleteTitle: return "alert.delete.title"
        case .alertDeleteMessage: return "alert.delete.message"
        case .alertDeleteConfirm: return "alert.delete.confirm"
        case .alertDeleteCancel: return "alert.delete.cancel"

        case .alertRenameTitle: return "alert.rename.title"
        case .alertRenamePlaceholder: return "alert.rename.placeholder"
        case .alertRenameSave: return "alert.rename.save"
        case .alertRenameCancel: return "alert.rename.cancel"

        case .alertExitRecordingTitle: return "alert.exit_recording.title"
        case .alertExitRecordingMessage: return "alert.exit_recording.message"
        case .alertExitRecordingConfirm: return "alert.exit_recording.confirm"
        case .alertExitRecordingCancel: return "alert.exit_recording.cancel"

        case .errorGeneric: return "error.generic"
        case .errorAudioPermission: return "error.audio_permission"
        }
    }

    var text: String {
        NSLocalizedString(key, comment: "")
    }
}
