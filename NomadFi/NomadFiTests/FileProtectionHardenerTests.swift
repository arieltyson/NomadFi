import Foundation
import Testing
@testable import NomadFi

struct FileProtectionHardenerTests {

    /// The Simulator's file system has no Data Protection classes.
    private static let isSimulator: Bool = {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }()

    @Test(.disabled(if: isSimulator, "Data Protection classes exist only on a device"))
    func upgradesExistingFilesAndLeavesProtectedOnesAlone() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let nested = directory.appending(path: "receipts")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appending(path: "default.store")
        let receipt = nested.appending(path: "receipt.jpg")
        try Data("store".utf8).write(to: store)
        try Data("image".utf8).write(to: receipt)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: store.path)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: receipt.path)

        #expect(FileProtectionHardener.protectAppFiles(in: [directory]) == 2)
        for file in [store, receipt] {
            let protection = try FileManager.default.attributesOfItem(atPath: file.path)[.protectionKey] as? FileProtectionType
            #expect(protection == .complete)
        }
        #expect(FileProtectionHardener.protectAppFiles(in: [directory]) == 0)
    }
}
