//
//  MainViewModel.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import Foundation
import Combine

@MainActor
final class MainViewModel: ObservableObject {

    @Published var filteredItems: [RecordingViewItem] = []
    @Published var neuralStatus: NeuralStatus = .idle
    @Published var currentStatusProgress: Double = .zero
    @Published var selectedFilter: Filter = .all
    @Published var items: [RecordingViewItem] = []

    @Published var isSearchPresented: Bool = false
    @Published var searchText: String = ""

    private weak var router: Router?

    private let facade: FileManagerFacadeProtocol
    private let player: RecordingService
    private let calendar: Calendar

    private var bundles: [RecordingBundle] = []
    private var currentlyPlayingId: String?
    private var progressTimer: Timer?
    
    private var bag = Set<AnyCancellable>()

    init(
        router: Router?,
        facade: FileManagerFacadeProtocol,
        player: RecordingService,
        calendar: Calendar = .current
    ) {
        self.router = router
        self.facade = facade
        self.player = player
        self.calendar = calendar

        self.player.onFinishPlayback = { [weak self] in
            Task { @MainActor in
                self?.stopProgressTimer()
                self?.currentlyPlayingId = nil
                self?.rebuildItemsKeepingPlayState()
            }
        }
        
        Task(priority: .userInitiated) {
            try await AiFacade.shared.loadModels()
        }
    }

    func onAppear() {
        reload()
        bindAI()
    }

    func reload() {
        do {
            bundles = try facade.listRecordingsMerged(
                allowedExtensions: ["m4a", "wav", "caf", "aac", "mp3"],
                sortNewestFirst: true
            )
            rebuildItemsKeepingPlayState()
        } catch {
            bundles = []
            items = []
            filteredItems = []
        }
    }

    func onChipTap(filter: Filter) {
        selectedFilter = filter
        isSearchPresented = false
        searchText = ""
        applyCurrentMode()
    }

    func onPlayPauseTap(id: String) {
        guard let item = items.first(where: { $0.id == id }) else { return }

        do {
            if currentlyPlayingId == id {
                if isPlayerPlaying {
                    try player.pausePlayback()
                    stopProgressTimer()
                } else {
                    try player.play()
                    startProgressTimer()
                }
                return
            }

            stopProgressTimer()
            try? player.stopPlayback()

            try player.preparePlayback(from: item.audioURL)
            try player.play()

            currentlyPlayingId = id
            startProgressTimer()
        } catch {
            stopProgressTimer()
            currentlyPlayingId = nil
        }

        rebuildItemsKeepingPlayState()
    }

    func onStaredTap(id: String) {
        guard let bundle = bundle(for: id) else { return }

        do {
            if var m = bundle.metadata {
                m = copyMetadata(m, isStarred: !m.isStarred, updatedAt: Date())
                try facade.updateMetadata(m)
            } else {
                let meta = makeDefaultMetadata(for: bundle, isStarred: true)
                try facade.updateMetadata(meta)
            }
            reload()
        } catch { }
    }

    func onRecordTap(id: String) {
        router?.push(viewController: DetailFactory.getDetailViewController(parentRouter: router, itemId: id))
    }

    func onNewRecordTap() {
        router?.push(viewController: NewRecordingFactory.getNewRecordingViewController(parentRouter: router))
    }

    // MARK: - Search

    /// Тап по иконке поиска.
    /// Если поиск был закрыт — открываем.
    /// Если поиск уже открыт — закрываем и сбрасываем фильтр в .all
    func onSearchTap() {
        if isSearchPresented {
            closeSearch()
        } else {
            openSearch()
        }
    }

    func openSearch() {
        isSearchPresented = true
        searchText = ""
        applyCurrentMode()
    }

    func closeSearch() {
        isSearchPresented = false
        searchText = ""
        selectedFilter = .all
        applyCurrentMode()
    }

    /// Вызывай из UI на каждый ввод текста (onChange в SwiftUI / editingChanged в UIKit)
    func onSearchTextChanged(_ text: String) {
        searchText = text
        applyCurrentMode()
    }

    // MARK: - Private

    private func bindAI() {
        AiFacade.shared.progressSubject
            .share()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ev in
                self?.neuralStatus = mapStageToNeuralStatus(ev.stage)
                self?.currentStatusProgress = ev.fraction
            }
            .store(in: &bag)
    }

    private var isPlayerPlaying: Bool {
        if case .playing = player.state { return true }
        return false
    }

    private func bundle(for itemId: String) -> RecordingBundle? {
        bundles.first { b in (b.metadata?.id.uuidString ?? b.audio.id) == itemId }
    }

    private func rebuildItemsKeepingPlayState() {
        items = bundles.map { mapBundleToItem($0) }
        applyCurrentMode()
    }

    private func applyCurrentMode() {
        if isSearchPresented, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filteredItems = smartSearch(text: searchText)
            return
        }
        applyFilter()
    }

    private func applyFilter() {
        switch selectedFilter {
        case .all:
            filteredItems = items
        case .starred:
            filteredItems = items.filter { $0.isStarred }
        case .today:
            filteredItems = items.filter { $0.dateText == L10n.filterToday.text }
        case .thisWeek:
            filteredItems = items.filter { isInThisWeek(itemId: $0.id) }
        }
    }

    private func isInThisWeek(itemId: String) -> Bool {
        guard let b = bundle(for: itemId) else { return false }
        return calendar.isDate(b.audio.createdAt, equalTo: Date(), toGranularity: .weekOfYear)
    }

    // MARK: - Smart search

    /// “Умный” поиск:
    /// - разбивает ввод на слова (токены)
    /// - ищет по title / transcript / summary
    /// - запись подходит, если ВСЕ токены найдены хотя бы в одном из полей (AND)
    private func smartSearch(text: String) -> [RecordingViewItem] {
        let tokens = tokenize(text)
        guard !tokens.isEmpty else { return items }

        // Для поиска нужны метаданные -> работаем по bundles, а в конце возвращаем view items
        let matchedBundles: [RecordingBundle] = bundles.filter { b in
            let title = normalize(b.title)
            let transcript = normalize(b.metadata?.transcript ?? "")
            let summary = normalize(b.metadata?.summary ?? "")

            return tokens.allSatisfy { t in
                title.contains(t) || transcript.contains(t) || summary.contains(t)
            }
        }

        // Порядок сохраняем как в bundles (sortNewestFirst уже учтён)
        return matchedBundles.map { mapBundleToItem($0) }
    }

    private func tokenize(_ text: String) -> [String] {
        let s = normalize(text)
        // разделители: пробелы/переносы/пунктуация
        let parts = s.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let tokens = parts.filter { !$0.isEmpty }
        // можно добавить дедупликацию
        return Array(Set(tokens)).sorted()
    }

    private func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    // MARK: - Mapping

    private func mapBundleToItem(_ b: RecordingBundle) -> RecordingViewItem {
        let id = b.metadata?.id.uuidString ?? b.audio.id

        let dateText = humanDateText(for: b.audio.createdAt)

        let durationSec: Int = {
            if let d = b.metadata?.durationSec, d > 0 { return Int(d.rounded()) }
            return 0
        }()

        let progress: Double = {
            guard let m = b.metadata, m.durationSec > 0 else { return 0 }
            return max(0, min(1, m.lastPlaybackPositionSec / m.durationSec))
        }()

        let isTranscribed = (b.metadata?.transcript?.isEmpty == false)
        let isSummurized = (b.metadata?.summary?.isEmpty == false)

        return RecordingViewItem(
            id: id,
            title: b.title,
            dateText: dateText,
            duration: durationSec,
            progress: progress,
            isStarred: b.isStarred,
            isTranscribed: isTranscribed,
            isSummurized: isSummurized,
            audioURL: b.audio.audioURL,
            metadataId: b.metadata?.id
        )
    }

    private func humanDateText(for date: Date) -> String {
        if calendar.isDateInToday(date) { return L10n.filterToday.text }
        if calendar.isDateInYesterday(date) { return L10n.recordingYesterday.text }

        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    // MARK: - Progress tracking

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tickProgress() }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func tickProgress() {
        guard let playingId = currentlyPlayingId else { return }
        guard let idx = items.firstIndex(where: { $0.id == playingId }) else { return }

        do {
            let t = try player.currentPlaybackTime()
            let d = try player.duration()
            let p = (d > 0) ? max(0, min(1, t / d)) : 0

            let old = items[idx]
            items[idx] = RecordingViewItem(
                id: old.id,
                title: old.title,
                dateText: old.dateText,
                duration: Int(d.rounded()),
                progress: p,
                isStarred: old.isStarred,
                isTranscribed: old.isTranscribed,
                isSummurized: old.isSummurized,
                audioURL: old.audioURL,
                metadataId: old.metadataId
            )

            applyCurrentMode()

            if let metaId = old.metadataId {
                try savePlaybackPosition(metaId: metaId, position: t, duration: d)
            }
        } catch { }
    }

    private func savePlaybackPosition(metaId: UUID, position: TimeInterval, duration: TimeInterval) throws {
        guard var m = try? facade.loadMetadata(for: metaId) else { return }
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
            durationSec: max(m.durationSec, duration),
            lastPlaybackPositionSec: position,
            playbackRate: m.playbackRate,
            transcript: m.transcript,
            summary: m.summary,
            keywords: m.keywords,
            neuralStatus: m.neuralStatus,
            neuralErrorMessage: m.neuralErrorMessage,
            modelName: m.modelName,
            modelVersion: m.modelVersion
        )
        try facade.updateMetadata(m)
    }

    // MARK: - Metadata helpers

    private func makeDefaultMetadata(for bundle: RecordingBundle, isStarred: Bool) -> RecordingMetadata {
        let fileName = bundle.audio.audioURL.lastPathComponent
        let relativePath = "Recordings/\(fileName)"
        let ext = bundle.audio.audioURL.pathExtension.lowercased()

        return RecordingMetadata(
            id: UUID(),
            title: bundle.title,
            note: nil,
            isStarred: isStarred,
            createdAt: bundle.audio.createdAt,
            updatedAt: Date(),
            relativePath: relativePath,
            fileExt: ext,
            fileSizeBytes: bundle.audio.sizeBytes,
            durationSec: bundle.metadata?.durationSec ?? 0,
            lastPlaybackPositionSec: 0,
            playbackRate: 1.0,
            transcript: bundle.metadata?.transcript,
            summary: bundle.metadata?.summary,
            keywords: bundle.metadata?.keywords ?? [],
            neuralStatus: .idle,
            neuralErrorMessage: nil,
            modelName: bundle.metadata?.modelName,
            modelVersion: bundle.metadata?.modelVersion
        )
    }

    private func copyMetadata(_ m: RecordingMetadata, isStarred: Bool, updatedAt: Date) -> RecordingMetadata {
        RecordingMetadata(
            id: m.id,
            title: m.title,
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

