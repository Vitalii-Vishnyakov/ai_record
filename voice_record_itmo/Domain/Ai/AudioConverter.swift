//
//  AudioConverter.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 13.01.26.
//

import AVFoundation

enum AudioConvertError: Error {
    case noAudioTrack
    case cannotAddOutput
    case cannotAddInput
    case failedToStart
    case readerFailed
    case writerFailed
}

final class AudioConverter {

    /// Конвертирует любой аудиофайл (m4a/aac/caf/wav) в WAV PCM 16kHz mono 16-bit
    static func convertToWav16kMono(inputURL: URL, outputURL: URL) async throws {
        // Удалим старый файл
        try? FileManager.default.removeItem(at: outputURL)

        let asset = AVURLAsset(url: inputURL)
        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw AudioConvertError.noAudioTrack
        }

        let reader = try AVAssetReader(asset: asset)

        // На выходе reader хотим PCM (float или int) — удобнее float, потом writer сделает int16
        let readerOutputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey: 1,      // попросим mono
            AVSampleRateKey: 16_000        // попросим 16k
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: readerOutputSettings)
        readerOutput.alwaysCopiesSampleData = false
        if reader.canAdd(readerOutput) {
            reader.add(readerOutput)
        } else {
            throw AudioConvertError.cannotAddOutput
        }

        // Пишем WAV PCM 16-bit 16k mono
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .wav)

        let writerInputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: writerInputSettings)
        writerInput.expectsMediaDataInRealTime = false

        if writer.canAdd(writerInput) {
            writer.add(writerInput)
        } else {
            throw AudioConvertError.cannotAddInput
        }

        guard reader.startReading() else { throw AudioConvertError.failedToStart }
        guard writer.startWriting() else { throw AudioConvertError.failedToStart }

        writer.startSession(atSourceTime: .zero)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let queue = DispatchQueue(label: "wav.convert.queue")

            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if reader.status == .failed {
                        writerInput.markAsFinished()
                        writer.cancelWriting()
                        cont.resume(throwing: reader.error ?? AudioConvertError.readerFailed)
                        return
                    }

                    if let sample = readerOutput.copyNextSampleBuffer() {
                        if !writerInput.append(sample) {
                            writerInput.markAsFinished()
                            writer.cancelWriting()
                            cont.resume(throwing: writer.error ?? AudioConvertError.writerFailed)
                            return
                        }
                    } else {
                        // samples закончились
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            if writer.status == .completed {
                                cont.resume(returning: ())
                            } else {
                                cont.resume(throwing: writer.error ?? AudioConvertError.writerFailed)
                            }
                        }
                        return
                    }
                }
            }
        }
    }
}
