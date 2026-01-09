//
//  NewRecordingViewModel.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import Foundation
import AVFoundation

@MainActor
final class NewRecordingViewModel: ObservableObject {

    @Published var neuralStatue: NeuralStatus = .idle

    @Published var elapsedSeconds: Int = 0
    @Published var isPaused: Bool = false
    @Published var isBookmarked: Bool = false
    @Published var recordingName: String = ""

    @Published var isPulsingAnimation: Bool = false
    
    private var secondsTimer: Timer?
    private var pulseTimer: Timer?

    private weak var router: Router?

    private let facade: FileManagerFacadeProtocol
    private let recorder: RecordingService

    private var currentAudioURL: URL?
    private var currentMetadata: RecordingMetadata?

    private var startedAt: Date?
    private let calendar: Calendar

    init(
        router: Router?,
        facade: FileManagerFacadeProtocol,
        recorder: RecordingService,
        calendar: Calendar = .current
    ) {
        self.router = router
        self.facade = facade
        self.recorder = recorder
        self.calendar = calendar

        self.recorder.onFinishRecording = { [weak self] url in
            Task { @MainActor in
                guard let self else { return }
                self.stopAllTimers()
                self.isPulsingAnimation = false
                self.neuralStatue = .idle
                self.isPaused = false

                if let url {
                    self.currentAudioURL = url
                    self.finalizeMetadataIfPossible(fileURL: url)
                }
            }
        }
    }

    // MARK: - Lifecycle

    func onAppear() {
        startNewRecording()
    }

    func onDisappear() {
        // если пользователь ушёл с экрана — не продолжаем таймеры
        stopAllTimers()
    }

    func goGack() {
        // если запись идёт — лучше остановить, чтобы не оставлять "висящую" сессию
        // (если хочешь подтверждение через alert — сделаем отдельно)
        try? safeStopRecording()
        router?.pop()
    }

    // MARK: - UI Actions

    func onStaredTap() {
        isBookmarked.toggle()

        // Если метаданные уже созданы — обновим сразу.
        if var meta = currentMetadata {
            meta = copyMetadata(meta, isStarred: isBookmarked, title: effectiveTitle(), updatedAt: Date())
            do { try facade.updateMetadata(meta); currentMetadata = meta } catch { }
        }
    }

    func onStopContinueTap() {
        if isPaused {
            resumeRecording()
        } else {
            pauseRecording()
        }
    }

    func onStopRecordTap() {
        stopRecordingAndSave()
    }

    // MARK: - Recording

    private func startNewRecording() {
        elapsedSeconds = 0
        isPaused = false
        isBookmarked = false
        recordingName = ""
        neuralStatue = .idle

        do {
            let created = try facade.createRecording(
                preferredName: nil,
                fileExtension: "m4a",
                makeMetadata: { [weak self] audioURL in
                    guard let self else {
                        // fallback
                        return RecordingMetadata(
                            id: UUID(),
                            title: audioURL.deletingPathExtension().lastPathComponent,
                            note: nil,
                            isStarred: false,
                            createdAt: Date(),
                            updatedAt: Date(),
                            relativePath: "Recordings/\(audioURL.lastPathComponent)",
                            fileExt: audioURL.pathExtension.lowercased(),
                            fileSizeBytes: 0,
                            durationSec: 0,
                            lastPlaybackPositionSec: 0,
                            playbackRate: 1.0,
                            transcript: nil,
                            summary: nil,
                            keywords: [],
                            neuralStatus: .idle,
                            neuralErrorMessage: nil,
                            modelName: nil,
                            modelVersion: nil
                        )
                    }
                    return self.makeInitialMetadata(audioURL: audioURL)
                }
            )

            currentAudioURL = created.audio.audioURL
            currentMetadata = created.metadata
            startedAt = Date()

            try recorder.startRecording(to: created.audio.audioURL, settings: nil)

            startSecondsTimer()
            startPulseTimer()
            isPulsingAnimation = true

        } catch {
            // можно показать ошибку/алерт — пока просто останавливаем
            stopAllTimers()
            isPulsingAnimation = false
            isPaused = false
        }
    }

    private func pauseRecording() {
        do {
            try recorder.pauseRecording()
            isPaused = true
            stopSecondsTimer()
            // пульсацию можно остановить на паузе
            isPulsingAnimation = false
        } catch { }
    }

    private func resumeRecording() {
        do {
            try recorder.resumeRecording()
            isPaused = false
            startSecondsTimer()
            isPulsingAnimation = true
        } catch { }
    }

    private func stopRecordingAndSave() {
        do {
            try safeStopRecording()
            stopAllTimers()
            isPulsingAnimation = false
            isPaused = false

            if let url = currentAudioURL {
                finalizeMetadataIfPossible(fileURL: url)
            }

            // после остановки — уходим назад (или на Detail, как хочешь)
            router?.pop()
        } catch {
            // если stop упал — тоже сбросим UI, чтобы не зависло
            stopAllTimers()
            isPulsingAnimation = false
            isPaused = false
        }
    }

    private func safeStopRecording() throws {
        // если уже остановлено — будет исключение, поэтому ловим мягко
        do { try recorder.stopRecording() } catch { }
        // закончить сессию
    }

    // MARK: - Timers

    private func startSecondsTimer() {
        stopSecondsTimer()
        secondsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedSeconds += 1
                self.updateLiveMetadataIfNeeded()
            }
        }
    }

    private func stopSecondsTimer() {
        secondsTimer?.invalidate()
        secondsTimer = nil
    }

    private func startPulseTimer() {
        stopPulseTimer()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                // простой триггер для анимации: UI может реагировать на изменение булевки
                self.isPulsingAnimation.toggle()
            }
        }
    }

    private func stopPulseTimer() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }

    private func stopAllTimers() {
        stopSecondsTimer()
        stopPulseTimer()
    }

    // MARK: - Metadata

    /// Заголовок записи: если пользователь ввёл имя — используем его, иначе дефолт из файла
    private func effectiveTitle() -> String {
        let t = recordingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        return currentAudioURL?.deletingPathExtension().lastPathComponent ?? "Recording"
    }

    private func makeInitialMetadata(audioURL: URL) -> RecordingMetadata {
        let now = Date()
        return RecordingMetadata(
            id: UUID(),
            title: audioURL.deletingPathExtension().lastPathComponent,
            note: nil,
            isStarred: false,
            createdAt: now,
            updatedAt: now,
            relativePath: "Recordings/\(audioURL.lastPathComponent)",
            fileExt: audioURL.pathExtension.lowercased(),
            fileSizeBytes: 0,
            durationSec: 0,
            lastPlaybackPositionSec: 0,
            playbackRate: 1.0,
            transcript: nil,
            summary: nil,
            keywords: [],
            neuralStatus: .idle,
            neuralErrorMessage: nil,
            modelName: nil,
            modelVersion: nil
        )
    }

    /// Пока идёт запись: обновляем title / isStarred / durationSec
    private func updateLiveMetadataIfNeeded() {
        guard var meta = currentMetadata else { return }
        let newTitle = effectiveTitle()

        let newDuration = Double(elapsedSeconds)

        // обновляем не чаще, чем раз в 3 секунды, чтобы не долбить JSON постоянно
        if elapsedSeconds % 3 != 0 { return }

        meta = RecordingMetadata(
            id: meta.id,
            title: newTitle,
            note: meta.note,
            isStarred: isBookmarked,
            createdAt: meta.createdAt,
            updatedAt: Date(),
            relativePath: meta.relativePath,
            fileExt: meta.fileExt,
            fileSizeBytes: meta.fileSizeBytes,
            durationSec: max(meta.durationSec, newDuration),
            lastPlaybackPositionSec: meta.lastPlaybackPositionSec,
            playbackRate: meta.playbackRate,
            transcript: meta.transcript,
            summary: meta.summary,
            keywords: meta.keywords,
            neuralStatus: meta.neuralStatus,
            neuralErrorMessage: meta.neuralErrorMessage,
            modelName: meta.modelName,
            modelVersion: meta.modelVersion
        )

        do {
            try facade.updateMetadata(meta)
            currentMetadata = meta
        } catch { }
    }

    /// После стопа: финализируем size/duration/title в метаданных
    private func finalizeMetadataIfPossible(fileURL: URL) {
        guard var meta = currentMetadata else { return }

        let title = effectiveTitle()
        let duration = Double(elapsedSeconds)

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? meta.fileSizeBytes

        meta = RecordingMetadata(
            id: meta.id,
            title: title,
            note: meta.note,
            isStarred: isBookmarked,
            createdAt: meta.createdAt,
            updatedAt: Date(),
            relativePath: meta.relativePath,
            fileExt: meta.fileExt,
            fileSizeBytes: max(meta.fileSizeBytes, fileSize),
            durationSec: max(meta.durationSec, duration),
            lastPlaybackPositionSec: 0,
            playbackRate: meta.playbackRate,
            transcript: meta.transcript,
            summary: meta.summary,
            keywords: meta.keywords,
            neuralStatus: meta.neuralStatus,
            neuralErrorMessage: meta.neuralErrorMessage,
            modelName: meta.modelName,
            modelVersion: meta.modelVersion
        )

        do {
            try facade.updateMetadata(meta)
            currentMetadata = meta
        } catch { }
    }

    private func copyMetadata(_ m: RecordingMetadata, isStarred: Bool, title: String, updatedAt: Date) -> RecordingMetadata {
        RecordingMetadata(
            id: m.id,
            title: title,
            note: m.note,
            isStarred: isStarred,
            createdAt: m.createdAt,
            updatedAt: updatedAt,
            relativePath: m.relativePath,
            fileExt: m.fileExt,
            fileSizeBytes: m.fileSizeBytes,
            durationSec: m.durationSec,
            lastPlaybackPositionSec: m.lastPlaybackPositionSec,
            playbackRate: m.playbackRate,
            transcript: m.transcript,
            summary: m.summary,
            keywords: m.keywords,
            neuralStatus: m.neuralStatus,
            neuralErrorMessage: m.neuralErrorMessage,
            modelName: m.modelName,
            modelVersion: m.modelVersion
        )
    }
}
