import XCTest
@testable import FlashcardApp

final class RealmBootstrapTests: XCTestCase {
    private var folder: URL!
    private var source: URL!
    private var destination: URL!
    private let bundle = Data("bundled offline database contents".utf8)

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        source = folder.appendingPathComponent("bundle.realm")
        destination = folder.appendingPathComponent("installed.realm")
        try bundle.write(to: source)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: folder) }

    func testFreshInstallCopiesCompleteBundle() throws {
        try RealmService.installBundleDatabase(from: source, to: destination)
        XCTAssertEqual(try Data(contentsOf: destination), bundle)
    }

    func testInterruptedBundlePrefixIsRepaired() throws {
        try bundle.prefix(12).write(to: destination)
        try RealmService.installBundleDatabase(from: source, to: destination)
        XCTAssertEqual(try Data(contentsOf: destination), bundle)
    }

    func testStagingLeftByTerminatedProcessIsRemovedOnNextLaunch() throws {
        let staging = destination.appendingPathExtension("importing")
        try bundle.prefix(12).write(to: staging)
        try RealmService.installBundleDatabase(from: source, to: destination)
        XCTAssertEqual(try Data(contentsOf: destination), bundle)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))
    }

    func testModifiedUserStoreIsNeverReplacedEvenIfSmaller() throws {
        let userData = Data("saved user deck".utf8)
        try userData.write(to: destination)
        try RealmService.installBundleDatabase(from: source, to: destination)
        XCTAssertEqual(try Data(contentsOf: destination), userData)
    }

    func testMissingBundleDoesNotDestroyExistingStore() throws {
        let userData = Data("saved user deck".utf8)
        try userData.write(to: destination)
        try FileManager.default.removeItem(at: source)
        XCTAssertThrowsError(try RealmService.installBundleDatabase(from: source, to: destination))
        XCTAssertEqual(try Data(contentsOf: destination), userData)
    }
}
