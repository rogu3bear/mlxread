import Foundation
import os

/// Central loggers. Privacy rule: selected text must NEVER be logged.
/// Log lengths, counts, durations, and error descriptions only.
enum AppLogger {
    static let app = Logger(subsystem: Constants.logSubsystem, category: "app")
    static let hotkey = Logger(subsystem: Constants.logSubsystem, category: "hotkey")
    static let selection = Logger(subsystem: Constants.logSubsystem, category: "selection")
    static let speech = Logger(subsystem: Constants.logSubsystem, category: "speech")
    static let audio = Logger(subsystem: Constants.logSubsystem, category: "audio")
    static let models = Logger(subsystem: Constants.logSubsystem, category: "models")
    static let permissions = Logger(subsystem: Constants.logSubsystem, category: "permissions")
}
