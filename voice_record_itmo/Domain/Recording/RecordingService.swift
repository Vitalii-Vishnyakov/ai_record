//
//  RecordingService.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//
import Foundation
import AVFoundation

final class RecordingService: NSObject, RecordingServiceProtocol {

    private let session: AVAudioSession
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?

    private(set) var state: RecordingState = .idle
    private var logger: RecordingServiceLogger

    var onStateChange: ((RecordingState) -> Void)?
    var onFinishPlayback: (() -> Void)?
    var onFinishRecording: ((URL?) -> Void)?

    init(session: AVAudioSession = .sharedInstance(), logger: RecordingServiceLogger = RecordingServiceLogger()) {
        self.session = session
        self.logger = logger
        super.init()
    }

    func setLogger(_ logger: RecordingServiceLogger) {
        self.logger = logger
        self.logger.info("Logger updated (isEnabled=\(logger.isEnabled))")
    }

    // MARK: - Recording

    func startRecording(to fileURL: URL, settings: [String: Any]? = nil) throws {
        guard fileURL.isFileURL else { throw RecordingServiceError.invalidURL }

        stopPlaybackIfNeeded()
        try requestMicPermissionIfNeeded()

        do {
            try activateSessionForRecording()
        } catch {
            logger.error("AudioSession activate(record) failed: \(error)")
            throw RecordingServiceError.audioSession(error)
        }

        let defaultSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let rec = try AVAudioRecorder(url: fileURL, settings: settings ?? defaultSettings)
            rec.delegate = self
            rec.isMeteringEnabled = true
            recorder = rec
        } catch {
            logger.error("Recorder init failed: \(error)")
            throw RecordingServiceError.recorderInit(error)
        }

        let ok = recorder?.record() ?? false
        if !ok {
            logger.error("Recorder record() returned false")
            throw RecordingServiceError.recorderStartFailed
        }

        setState(.recording)
        logger.info("Recording started: \(fileURL.lastPathComponent)")
    }

    func pauseRecording() throws {
        guard let recorder else { throw RecordingServiceError.noRecorder }
        guard state == .recording else { return }
        recorder.pause()
        setState(.pausedRecording)
        logger.info("Recording paused")
    }

    func resumeRecording() throws {
        guard let recorder else { throw RecordingServiceError.noRecorder }
        guard state == .pausedRecording else { return }

        do {
            try activateSessionForRecording()
        } catch {
            logger.error("AudioSession re-activate(record) failed: \(error)")
            throw RecordingServiceError.audioSession(error)
        }

        recorder.record()
        setState(.recording)
        logger.info("Recording resumed")
    }

    func stopRecording() throws {
        guard let recorder else { throw RecordingServiceError.noRecorder }
        recorder.stop()
        logger.info("Recording stop requested")
    }

    func currentRecordingTime() throws -> TimeInterval {
        guard let recorder else { throw RecordingServiceError.noRecorder }
        return recorder.currentTime
    }

    func currentPower() throws -> Float {
        guard let recorder else { throw RecordingServiceError.noRecorder }
        recorder.updateMeters()
        return recorder.averagePower(forChannel: 0)
    }

    // MARK: - Playback

    func preparePlayback(from fileURL: URL) throws {
        guard fileURL.isFileURL else { throw RecordingServiceError.invalidURL }

        stopRecordingIfNeeded()

        do {
            try activateSessionForPlayback()
        } catch {
            logger.error("AudioSession activate(playback) failed: \(error)")
            throw RecordingServiceError.audioSession(error)
        }

        do {
            let p = try AVAudioPlayer(contentsOf: fileURL)
            p.delegate = self
            p.enableRate = true
            p.prepareToPlay()
            player = p
            logger.info("Playback prepared: \(fileURL.lastPathComponent)")
        } catch {
            logger.error("Player init failed: \(error)")
            throw RecordingServiceError.playerInit(error)
        }
    }

    func play() throws {
        guard let player else { throw RecordingServiceError.noPlayer }

        do {
            try activateSessionForPlayback()
        } catch {
            logger.error("AudioSession activate(playback) failed: \(error)")
            throw RecordingServiceError.audioSession(error)
        }

        let ok = player.play()
        if ok {
            setState(.playing)
            logger.info("Playback started")
        } else {
            logger.warning("player.play() returned false")
        }
    }

    func pausePlayback() throws {
        guard let player else { throw RecordingServiceError.noPlayer }
        guard state == .playing else { return }
        player.pause()
        setState(.pausedPlayback)
        logger.info("Playback paused")
    }

    func stopPlayback() throws {
        guard let player else { throw RecordingServiceError.noPlayer }
        player.stop()
        player.currentTime = 0
        setState(.idle)
        logger.info("Playback stopped")
        deactivateSessionIfIdle()
    }

    func duration() throws -> TimeInterval {
        guard let player else { throw RecordingServiceError.noPlayer }
        return player.duration
    }

    func currentPlaybackTime() throws -> TimeInterval {
        guard let player else { throw RecordingServiceError.noPlayer }
        return player.currentTime
    }

    func seek(to time: TimeInterval) throws {
        guard let player else { throw RecordingServiceError.noPlayer }
        guard time.isFinite, time >= 0, time <= player.duration else { throw RecordingServiceError.invalidTime }
        player.currentTime = time
        logger.info("Seek to \(String(format: "%.2f", time))s")
    }

    func skip(by delta: TimeInterval) throws {
        let t = try currentPlaybackTime()
        try seek(to: t + delta)
    }

    func setPlaybackRate(_ rate: Float) throws {
        guard let player else { throw RecordingServiceError.noPlayer }
        let clamped = max(0.5, min(rate, 2.0))
        player.enableRate = true
        player.rate = clamped
        logger.info("Playback rate set to \(clamped)x")
    }

    // MARK: - AudioSession (FIX)

    private func activateSessionForRecording() throws {
        try runOnMainSync {
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        }
    }

    private func activateSessionForPlayback() throws {
        try runOnMainSync {
            try session.setCategory(
                .playback,
                mode: .default,
                options: []
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        }
    }

    private func deactivateSessionIfIdle() {
        guard recorder == nil, player == nil else { return }
        runOnMainAsync {
            do {
                try self.session.setActive(false, options: .notifyOthersOnDeactivation)
                self.logger.debug("AudioSession deactivated (idle)")
            } catch {
                self.logger.warning("AudioSession deactivation failed: \(error)")
            }
        }
    }

    private func requestMicPermissionIfNeeded() throws {
        let perm = session.recordPermission
        switch perm {
        case .granted:
            return
        case .denied:
            throw RecordingServiceError.microphonePermissionDenied
        case .undetermined:
            let sema = DispatchSemaphore(value: 0)
            var granted = false
            session.requestRecordPermission { ok in
                granted = ok
                sema.signal()
            }
            sema.wait()
            if !granted {
                throw RecordingServiceError.microphonePermissionDenied
            }
        @unknown default:
            throw RecordingServiceError.microphonePermissionDenied
        }
    }

    private func runOnMainAsync(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block(); return }
        DispatchQueue.main.async(execute: block)
    }

    private func runOnMainSync<T>(_ block: () throws -> T) throws -> T {
        if Thread.isMainThread { return try block() }
        var result: Result<T, Error>!
        DispatchQueue.main.sync {
            result = Result { try block() }
        }
        return try result.get()
    }

    // MARK: - Internals

    private func setState(_ newState: RecordingState) {
        if state != newState {
            state = newState
            onStateChange?(newState)
        }
    }

    private func stopPlaybackIfNeeded() {
        if let player, player.isPlaying || state == .pausedPlayback || state == .playing {
            player.stop()
            player.currentTime = 0
            self.player = nil
            setState(.idle)
            logger.debug("Playback stopped (auto)")
            deactivateSessionIfIdle()
        }
    }

    private func stopRecordingIfNeeded() {
        if let recorder, recorder.isRecording || state == .recording || state == .pausedRecording {
            recorder.stop()
            self.recorder = nil
            setState(.idle)
            logger.debug("Recording stopped (auto)")
            deactivateSessionIfIdle()
        }
    }
}

extension RecordingService: AVAudioRecorderDelegate, AVAudioPlayerDelegate {

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        logger.info("Recorder finished. success=\(flag)")
        let url = flag ? recorder.url : nil
        self.recorder = nil
        setState(.idle)
        deactivateSessionIfIdle()
        onFinishRecording?(url)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        logger.info("Player finished. success=\(flag)")
        self.player = nil
        setState(.idle)
        deactivateSessionIfIdle()
        onFinishPlayback?()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        logger.error("Player decode error: \(String(describing: error))")
        self.player = nil
        setState(.idle)
        deactivateSessionIfIdle()
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        logger.error("Recorder encode error: \(String(describing: error))")
        self.recorder = nil
        setState(.idle)
        deactivateSessionIfIdle()
    }
}
