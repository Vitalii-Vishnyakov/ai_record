//
//  RecordingServiceLogger.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import Foundation

struct RecordingServiceLogger {
    enum Level: String { case debug = "DEBUG", info = "INFO", warning = "WARN", error = "ERROR" }
    var isEnabled: Bool = true
    var sink: (Level, String) -> Void = { level, msg in
        print("[RecordingService][\(level.rawValue)] \(msg)")
    }

    func log(_ level: Level, _ msg: String) {
        guard isEnabled else { return }
        sink(level, msg)
    }
    func debug(_ msg: String) { log(.debug, msg) }
    func info(_ msg: String) { log(.info, msg) }
    func warning(_ msg: String) { log(.warning, msg) }
    func error(_ msg: String) { log(.error, msg) }
}
