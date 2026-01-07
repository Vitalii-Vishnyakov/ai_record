//
//  FileManagerServiceLogger.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import Foundation

struct FileManagerServiceLogger {
    enum Level: String { case debug = "DEBUG", info = "INFO", warning = "WARN", error = "ERROR" }

    /// Включено/выключено логирование
    var isEnabled: Bool = true

    /// Куда писать логи
    var sink: (Level, String) -> Void = { level, message in
        print("[FileManagerService][\(level.rawValue)] \(message)")
    }

    func log(_ level: Level, _ message: String) {
        guard isEnabled else { return }
        sink(level, message)
    }

    func debug(_ message: String) { log(.debug, message) }
    func info(_ message: String) { log(.info, message) }
    func warning(_ message: String) { log(.warning, message) }
    func error(_ message: String) { log(.error, message) }
}
