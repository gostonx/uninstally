import Foundation
import os

/// Shared logging subsystem. Using `os.Logger` gives us free Console.app
/// integration, privacy handling, and negligible overhead when disabled.
extension Logger {
    private static let subsystem = "com.codenta.uninstally"

    static let scanner = Logger(subsystem: subsystem, category: "scanner")
    static let engine = Logger(subsystem: subsystem, category: "engine")
    static let app = Logger(subsystem: subsystem, category: "app")
    static let homebrew = Logger(subsystem: subsystem, category: "homebrew")
    static let language = Logger(subsystem: subsystem, category: "language")
}
