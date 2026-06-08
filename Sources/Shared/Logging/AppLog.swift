// AppLog.swift – central logging; no-op when AppConfig.debugLoggingEnabled is false (e.g. Release).

import Foundation

enum AppLog {
    /// Logs only when debug logging is enabled. Use for deployment: Release builds have it disabled.
    static func log(_ tag: String, _ message: String) {
        guard AppConfig.debugLoggingEnabled else { return }
        print("[\(tag)] \(message)")
    }

    /// Format-string variant for compatibility with NSLog-style calls.
    static func log(_ tag: String, _ format: String, _ args: CVarArg...) {
        guard AppConfig.debugLoggingEnabled else { return }
        let message = String(format: format, arguments: args)
        print("[\(tag)] \(message)")
    }
}
