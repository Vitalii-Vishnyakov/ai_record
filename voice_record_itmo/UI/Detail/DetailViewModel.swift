//
//  DetailViewModel.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import Foundation
import AVFoundation
import UIKit
import Combine

@MainActor
final class DetailViewModel: ObservableObject {
    
    @Published var neuralStatus: NeuralStatus = .idle
    @Published var tab: SummaryTab = .transcript
    @Published var playback: PlaybackState = PlaybackState()
    @Published var transcript: String = ""
    @Published var summary: AISummary = AISummary()
    @Published var currentStatusProgress: Double = .zero
    @Published var isAiActionEnabled: Bool = false
    
    private weak var router: Router?
    
    private let facade: FileManagerFacadeProtocol
    private let player: RecordingService
    
    private let itemId: String
    private var bundle: RecordingBundle?
    private var metadata: RecordingMetadata?
    
    private let calendar: Calendar
    private var timer: Timer?
    private var isAIBound = false
    
    private var bag = Set<AnyCancellable>()
    
    init(
        router: Router?,
        facade: FileManagerFacadeProtocol,
        player: RecordingService,
        itemId: String,
        calendar: Calendar = .current
    ) {
        self.router = router
        self.facade = facade
        self.player = player
        self.itemId = itemId
        self.calendar = calendar

        syncAIStatusWithCurrentEvent()
    }
    
    func onGetTranscriptionAndSummarizationTap() {
        if let audio = bundle?.audio.audioURL {
            Task { [weak self] in
                do {
                    let result = try await AiFacade.shared.transcribeAndSummarize(
                        audioURL: audio
                    )
                    
                    self?.transcript = result.transcript
                    self?.summary = AISummary(
                        text: result.summary,
                        keyWords: ["какие", "то", "слова"] // если позже добавишь keywords из LLM
                    )
                    self?.saveSummaryIfPossible()
                } catch {
                    // Статус ошибки приходит из общего AiFacade.progressSubject.
                }
            }
        }
    }
    
    func onAppear() {
        load()
        bindAI()
    }
    
    func onDisappear() {
        saveProgressIfPossible()
        stopTimer()
        bag.removeAll()
        isAIBound = false
    }
    
    func onGoBack() {
        saveProgressIfPossible()
        stopTimer()
        try? player.stopPlayback()
        router?.pop()
    }
    
    // MARK: - Load
    
    func load() {
        do {
            let bundles = try facade.listRecordingsMerged(
                allowedExtensions: ["m4a", "wav", "caf", "aac", "mp3"],
                sortNewestFirst: true
            )
            
            guard let b = bundles.first(where: { ($0.metadata?.id.uuidString ?? $0.audio.id) == itemId }) else {
                // Нет записи — оставим дефолты
                return
            }
            
            self.bundle = b
            self.metadata = b.metadata
            
            playback.title = b.title
            playback.dateLine = makeDateLine(for: b.audio.createdAt, duration: b.metadata?.durationSec)
            transcript = b.metadata?.transcript ?? ""
            summary = AISummary(
                text: b.metadata?.summary ?? "",
                keyWords: b.metadata?.keywords ?? []
            )
            
            playback.speed = Double(b.metadata?.playbackRate ?? 1.0)
            
            // Подготовим плеер и установим позицию
            try preparePlayerIfPossible()
            syncPlaybackFromPlayer()
            syncPlaybackBindingFromPlayer()
            
        } catch {
            // можно показать ошибку
        }
    }
    
    private func preparePlayerIfPossible() throws {
        guard let audioURL = bundle?.audio.audioURL else { return }
        if player.currentPlaybackURL == audioURL {
            if playback.speed > 0 {
                try? player.setPlaybackRate(Float(playback.speed))
            }
            return
        }

        try player.preparePlayback(from: audioURL)
        
        // Если есть мета — восстановим позицию
        if let m = metadata, m.lastPlaybackPositionSec > 0, m.lastPlaybackPositionSec < m.durationSec - 10 {
            try? player.seek(to: m.lastPlaybackPositionSec)
        }
        
        // Скорость
        try? player.setPlaybackRate(Float(playback.speed))
    }
    
    // MARK: - Share
    
    /// Возвращает объект для UIActivityViewController.
    /// Удобно: View сможет вызвать этот метод и открыть share sheet.
    func makeShareItems() -> [Any] {
        guard let audioURL = bundle?.audio.audioURL else { return [] }
        
        var items: [Any] = [audioURL]
        
        if !transcript.isEmpty {
            items.append(transcript)
        }
        if !summary.text.isEmpty {
            items.append(summary.text)
        }
        return items
    }
    
    func onShareTap() {
        // Здесь навигация зависит от твоей архитектуры.
        // Обычно: router?.presentShare(items: makeShareItems())
        // Поэтому оставляю безопасно пустым, чтобы не сломать проект.
    }
    
    private func bindAI() {
        guard !isAIBound else { return }
        isAIBound = true
        syncAIStatusWithCurrentEvent()

        AiFacade.shared.progressSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ev in
                let status = mapStageToNeuralStatus(ev.stage)
                self?.neuralStatus = status
                self?.currentStatusProgress = ev.fraction
                self?.isAiActionEnabled = status != .loadingModel
            }
            .store(in: &bag)
    }

    private func syncAIStatusWithCurrentEvent() {
        let event = AiFacade.shared.progressSubject.value
        let status = mapStageToNeuralStatus(event.stage)
        neuralStatus = status
        currentStatusProgress = event.fraction
        isAiActionEnabled = status != .loadingModel
    }
    
    // MARK: - Playback controls
    
    func onPlayPauseTap() {
        guard let audioURL = bundle?.audio.audioURL else { return }
        
        do {
            if playback.isPlaying {
                try player.pausePlayback()
                playback.isPlaying = false
                stopTimer()
                saveProgressIfPossible()
            } else {
                // Если плеер не подготовлен (например после ошибки) — попробуем ещё раз
                if player.currentPlaybackURL != audioURL || !isPlayerReady {
                    try preparePlayerIfPossible()
                }
                try player.setPlaybackRate(Float(playback.speed))
                try player.play()
                playback.isPlaying = true
                startTimer()
            }
            syncPlaybackFromPlayer()
            syncPlaybackBindingFromPlayer()
        } catch {
            playback.isPlaying = false
            stopTimer()
        }
    }
    
    func onSeekToStartTap() { seekToStart() }
    func onBackwardTap15() { skip(seconds: -15) }
    func onForwardTap15() { skip(seconds: 15) }
    func onSeekToEndTap() { seekToEnd() }
    
    private func skip(seconds: TimeInterval) {
        do {
            guard let audioURL = bundle?.audio.audioURL else { return }
            if player.currentPlaybackURL != audioURL || !isPlayerReady {
                try preparePlayerIfPossible()
            }
            try player.skip(by: seconds)
            syncPlaybackFromPlayer()
            syncPlaybackBindingFromPlayer()
            saveProgressIfPossible()
        } catch { }
    }

    private func seekToStart() {
        seek(to: 0)
    }

    private func seekToEnd() {
        do {
            guard let audioURL = bundle?.audio.audioURL else { return }
            if player.currentPlaybackURL != audioURL || !isPlayerReady {
                try preparePlayerIfPossible()
            }
            let total = try player.duration()
            seek(to: total)
        } catch { }
    }

    private func seek(to position: TimeInterval) {
        do {
            guard let audioURL = bundle?.audio.audioURL else { return }
            if player.currentPlaybackURL != audioURL || !isPlayerReady {
                try preparePlayerIfPossible()
            }
            let total = try player.duration()
            let clamped = max(0, min(total, position))
            try player.seek(to: clamped)
            syncPlaybackFromPlayer()
            syncPlaybackBindingFromPlayer()
            saveProgressIfPossible()
        } catch { }
    }
    
    func onSpeedTap() {
        // цикл скоростей как в большинстве диктофонов
        let options: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        let current = playback.speed
        let next = nextValue(in: options, current: current)
        
        playback.speed = next
        
        do {
            try player.setPlaybackRate(Float(next))
            saveSpeedIfPossible()
        } catch { }
    }
    
    // MARK: - Tabs
    
    func onTagTap(tab: SummaryTab) {
        self.tab = tab
    }
    
    // MARK: - Copy
    
    func copyTap() {
        let textToCopy: String
        switch tab {
        case .summary:
            textToCopy = summary.text
        case .transcript:
            textToCopy = transcript
        }
        
        guard !textToCopy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        UIPasteboard.general.string = textToCopy
    }
    
    // MARK: - Timer
    
    private var isPlayerReady: Bool {
        // грубая проверка: если можем получить duration — значит player есть
        (try? player.duration()) != nil
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        syncPlaybackFromPlayer()
        syncPlaybackBindingFromPlayer()
        // не пишем в json каждую 0.35с. Лучше редко.
        // Поэтому сохраняем раз в несколько секунд:
        throttledSaveProgress()
    }
    
    private var lastSavedAt: Date?
    private func throttledSaveProgress() {
        let now = Date()
        if let last = lastSavedAt, now.timeIntervalSince(last) < 3.0 { return }
        lastSavedAt = now
        saveProgressIfPossible()
    }
    
    // MARK: - Sync state
    
    private func syncPlaybackFromPlayer() {
        do {
            let current = try player.currentPlaybackTime()
            let total = try player.duration()
            
            playback.currentTime = Int(current.rounded())
            playback.totalTime = Int(total.rounded())
            playback.progress = total > 0 ? max(0, min(1, current / total)) : 0
        } catch {
            if !isCurrentBundlePreparedInPlayer {
                playback.isPlaying = false
            }
        }
    }

    private var isCurrentBundlePreparedInPlayer: Bool {
        guard let audioURL = bundle?.audio.audioURL else { return false }
        return player.currentPlaybackURL == audioURL
    }

    private func syncPlaybackBindingFromPlayer() {
        guard isCurrentBundlePreparedInPlayer else {
            playback.isPlaying = false
            stopTimer()
            return
        }

        if case .playing = player.state {
            playback.isPlaying = true
            if timer == nil {
                startTimer()
            }
        } else {
            playback.isPlaying = false
            if timer != nil {
                stopTimer()
            }
        }
    }
    
    // MARK: - Persist metadata updates
    
    private func saveProgressIfPossible() {
        guard var m = metadata else { return }
        
        let current = TimeInterval(playback.currentTime)
        let total = TimeInterval(playback.totalTime)
        
        m = RecordingMetadata(
            id: m.id,
            title: m.title,
            note: m.note,
            isStarred: m.isStarred,
            createdAt: m.createdAt,
            updatedAt: Date(),
            relativePath: m.relativePath,
            fileExt: m.fileExt,
            fileSizeBytes: m.fileSizeBytes,
            durationSec: max(m.durationSec, total),
            lastPlaybackPositionSec: current,
            playbackRate: Float(playback.speed),
            transcript: m.transcript,
            summary: m.summary,
            keywords: m.keywords,
            neuralStatus: m.neuralStatus,
            neuralErrorMessage: m.neuralErrorMessage,
            modelName: m.modelName,
            modelVersion: m.modelVersion
        )
        
        do {
            try facade.updateMetadata(m)
            metadata = m
        } catch { }
    }
    
    private func saveSpeedIfPossible() {
        guard var m = metadata else { return }
        
        m = RecordingMetadata(
            id: m.id,
            title: m.title,
            note: m.note,
            isStarred: m.isStarred,
            createdAt: m.createdAt,
            updatedAt: Date(),
            relativePath: m.relativePath,
            fileExt: m.fileExt,
            fileSizeBytes: m.fileSizeBytes,
            durationSec: m.durationSec,
            lastPlaybackPositionSec: m.lastPlaybackPositionSec,
            playbackRate: Float(playback.speed),
            transcript: m.transcript,
            summary: m.summary,
            keywords: m.keywords,
            neuralStatus: m.neuralStatus,
            neuralErrorMessage: m.neuralErrorMessage,
            modelName: m.modelName,
            modelVersion: m.modelVersion
        )
        
        do {
            try facade.updateMetadata(m)
            metadata = m
        } catch { }
    }
    
    private func saveSummaryIfPossible() {
        guard var m = metadata else { return }
        
        m = RecordingMetadata(
            id: m.id,
            title: m.title,
            note: m.note,
            isStarred: m.isStarred,
            createdAt: m.createdAt,
            updatedAt: Date(),
            relativePath: m.relativePath,
            fileExt: m.fileExt,
            fileSizeBytes: m.fileSizeBytes,
            durationSec: m.durationSec,
            lastPlaybackPositionSec: m.lastPlaybackPositionSec,
            playbackRate: Float(playback.speed),
            transcript: transcript,
            summary: summary.text,
            keywords: summary.keyWords,
            neuralStatus: m.neuralStatus,
            neuralErrorMessage: m.neuralErrorMessage,
            modelName: m.modelName,
            modelVersion: m.modelVersion
        )
        
        do {
            try facade.updateMetadata(m)
            metadata = m
        } catch { }
    }
    
    // MARK: - Helpers
    
    private func nextValue(in options: [Double], current: Double) -> Double {
        if let idx = options.firstIndex(where: { abs($0 - current) < 0.001 }) {
            let nextIdx = (idx + 1) % options.count
            return options[nextIdx]
        }
        return 1.0
    }
    
    private func makeDateLine(for date: Date, duration: Double?) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = .current
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = .current
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        let left = "\(dateFormatter.string(from: date)) • \(timeFormatter.string(from: date))"
        
        let dur = Int((duration ?? 0).rounded())
        if dur > 0 {
            return "\(left) • \(formatTime(dur))"
        }
        return left
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
