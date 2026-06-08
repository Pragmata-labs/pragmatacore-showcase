// AppConfig.swift – central debug/release flags for deployment
// Use for logging kill switch and feature flags.

import Foundation

enum AppConfig {
    /// When false, AppLog and APP_LOG (ObjC) do not output. Set false for Release / deployment.
    static var debugLoggingEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
