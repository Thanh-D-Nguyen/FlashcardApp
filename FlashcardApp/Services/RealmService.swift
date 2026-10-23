import RealmSwift
import Foundation

/// The local store: the learner's own decks and cards. Dictionary content (words, kanji, grammar, examples)
/// is not stored here; it comes from the API. No database is bundled with the app.
final class RealmService {
    static let databaseName = "flash_card.realm"
    /// 1: the bundled database, which also held the dictionary tables. 2: decks and cards only.
    /// 3: adds `RCardExample`, the learner's own example sentences (additive, nothing to migrate).
    /// 4: adds `RReviewAttempt`, the learner's answered questions (additive, nothing to migrate).
    /// 5: adds `RReviewState`, when each card is next due (additive, nothing to migrate).
    /// 6: `RReviewState` loses `lastAttemptId`, a column nothing read that the first schema-5 build had written. Realm drops it
    /// during the version bump; every row is kept (a store written by that build would otherwise not open).
    static let schemaVersion: UInt64 = 6
    static let storedTypes: [Object.Type] = [RDesk.self, RCard.self, RCardExample.self, RReviewAttempt.self, RReviewState.self]
    /// Tables of the retired bundled dictionary. An upgraded install empties them; the decks are untouched.
    static let retiredDictionaryTables: [Object.Type] = [RetiredJaVi.self, RetiredViJa.self, RetiredKanji.self, RetiredGrammar.self, RetiredExample.self]
    /// How those tables are named in the file (the stand-in classes map to them with `_realmObjectName`).
    static let retiredDictionaryTableNames = ["RJaVi", "RViJa", "RKanji", "RGrammar", "RExample"]

    static let shared = RealmService()
    var realm: Realm!

    static var defaultFileURL: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent(databaseName)
    }

    static func makeConfiguration(fileURL: URL = defaultFileURL) -> Realm.Configuration {
        Realm.Configuration(fileURL: fileURL, schemaVersion: schemaVersion, migrationBlock: migrate,
                            shouldCompactOnLaunch: shouldCompact, objectTypes: storedTypes)
    }

    func configuration(onComplete: @escaping () -> Void = {}, onError: ((AppError) -> Void)? = nil) {
        let config = Self.makeConfiguration()
        do {
            realm = try Realm(configuration: config)
            Realm.Configuration.defaultConfiguration = config
            onComplete()
        } catch {
            logger.error("Database open failed: \(error.localizedDescription)")
            onError?(.databaseInitializationFailed(NSLocalizedString("Couldn't open the offline data. Existing data was kept.", comment: "")))
        }
    }

    static func migrate(migration: Migration, oldVersion: UInt64) {
        guard oldVersion < 2 else { return }
        retiredDictionaryTableNames.forEach { _ = migration.deleteData(forType: $0) }
    }

    /// Dropping the dictionary tables frees most of a 100+ MB file; compact it on a later launch (the check
    /// runs before the upgrade commits) so the space is returned to the device.
    static func shouldCompact(totalBytes: Int, usedBytes: Int) -> Bool {
        let threshold = 20 * 1024 * 1024
        return totalBytes > threshold && Double(usedBytes) / Double(totalBytes) < 0.5
    }
}
