import RealmSwift
import Foundation

final class RealmService {
    private let databaseName = "flash_card.realm"
    private let databaseVersion: UInt64 = 1
    static let shared = RealmService()
    var realm: Realm!
    var copyProgress: ((Double) -> Void)?

    func copyBundleData(completion: @escaping (URL) -> Void, onError: ((AppError) -> Void)? = nil) {
        guard let source = Bundle.main.url(forResource: databaseName, withExtension: nil) else {
            onError?(.databaseInitializationFailed(NSLocalizedString("The bundled offline data was not found.", comment: "")))
            return
        }
        let destination = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(databaseName)
        copyProgress?(0)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try Self.installBundleDatabase(from: source, to: destination)
                DispatchQueue.main.async {
                    self.copyProgress?(100)
                    completion(destination)
                }
            } catch {
                logger.error("Database copy failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    onError?(.databaseInitializationFailed(NSLocalizedString("Couldn't prepare the offline data. Existing data was kept.", comment: "")))
                }
            }
        }
    }

    static func installBundleDatabase(from source: URL, to destination: URL) throws {
        let manager = FileManager.default
        let temporary = destination.appendingPathExtension("importing")
        if manager.fileExists(atPath: temporary.path) { try manager.removeItem(at: temporary) }
        let sourceData = try Data(contentsOf: source, options: .mappedIfSafe)
        let exists = manager.fileExists(atPath: destination.path)
        if exists {
            let existing = try Data(contentsOf: destination, options: .mappedIfSafe)
            // Repair only an exact, truncated bundle copy; never replace a modified user store.
            guard existing.count < sourceData.count, sourceData.starts(with: existing) else { return }
        }
        defer { if manager.fileExists(atPath: temporary.path) { try? manager.removeItem(at: temporary) } }
        try manager.copyItem(at: source, to: temporary)
        if exists {
            _ = try manager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try manager.moveItem(at: temporary, to: destination)
        }
    }

    func configuration(onComplete: @escaping () -> Void = {}, onError: ((AppError) -> Void)? = nil) {
        copyBundleData(completion: { [self] url in
            let config = Realm.Configuration(fileURL: url, schemaVersion: databaseVersion,
                                             migrationBlock: RealmService.migrate)
            do {
                realm = try Realm(configuration: config)
                Realm.Configuration.defaultConfiguration = config
                onComplete()
            } catch {
                logger.error("Database open failed: \(error.localizedDescription)")
                onError?(.databaseInitializationFailed(NSLocalizedString("Couldn't open the offline data. Existing data was kept.", comment: "")))
            }
        }, onError: onError)
    }

    static func migrate(migration: Migration, oldVersion: UInt64) {}
}
