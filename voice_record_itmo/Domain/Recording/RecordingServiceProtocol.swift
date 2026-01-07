//
//  RecordingServiceProtocol.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import Foundation
import AVFoundation

protocol RecordingServiceProtocol: AnyObject {

    var state: RecordingState { get }
    var onStateChange: ((RecordingState) -> Void)? { get set }
    var onFinishPlayback: (() -> Void)? { get set }
    var onFinishRecording: ((URL?) -> Void)? { get set }

    func setLogger(_ logger: RecordingServiceLogger)

    func startRecording(to fileURL: URL, settings: [String: Any]?) throws
    func pauseRecording() throws
    func resumeRecording() throws
    func stopRecording() throws
    func currentRecordingTime() throws -> TimeInterval
    func currentPower() throws -> Float

    func preparePlayback(from fileURL: URL) throws
    func play() throws
    func pausePlayback() throws
    func stopPlayback() throws
    func duration() throws -> TimeInterval
    func currentPlaybackTime() throws -> TimeInterval
    func seek(to time: TimeInterval) throws
    func skip(by delta: TimeInterval) throws
    func setPlaybackRate(_ rate: Float) throws
}
