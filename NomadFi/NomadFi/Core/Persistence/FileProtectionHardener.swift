// FileProtectionHardener.swift
// NomadFi
//
// Brings files created before Complete Data Protection up to it.

import Foundation
import OSLog

/// Applies `FileProtectionType.complete` to NomadFi's existing files.
///
/// The app's data-protection entitlement makes every new file
/// unreadable while the iPhone is locked, but files created earlier
/// (the SwiftData store, its journal, receipt images) keep the class
/// they were born with. This upgrades them in place at launch, when
/// the device is necessarily unlocked. Failures are logged and never
/// block launch: an unprotected file is better than no app.
enum FileProtectionHardener {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "FileProtection")

    /// Upgrades every file under Application Support and Documents.
    /// - Returns: How many files changed class, for tests and logs.
    @discardableResult
    static func protectAppFiles(
        in directories: [URL] = [.applicationSupportDirectory, .documentsDirectory],
        fileManager: FileManager = .default
    ) -> Int {
        var upgraded = 0
        for directory in directories {
            guard let files = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) else { continue }
            for case let file as URL in files {
                guard (try? file.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
                let current = (try? fileManager.attributesOfItem(atPath: file.path))?[.protectionKey] as? FileProtectionType
                guard current != .complete else { continue }
                do {
                    try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
                    upgraded += 1
                } catch {
                    logger.error("Could not apply complete protection: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        if upgraded > 0 { logger.info("Applied complete protection to \(upgraded, privacy: .public) files") }
        return upgraded
    }
}
