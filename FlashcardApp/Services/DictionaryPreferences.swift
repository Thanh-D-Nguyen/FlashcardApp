import Foundation

/// How the dictionary shows its text on this device.
protocol DictionaryPreferencesInterface: AnyObject {
    /// The hiragana line under a sentence ("furigana" as a whole-sentence reading; the content has no per-word ruby).
    var showReadings: Bool { get set }
}

final class UserDefaultsDictionaryPreferences: DictionaryPreferencesInterface {
    static let shared = UserDefaultsDictionaryPreferences()

    private let defaults: UserDefaults
    private let readingsKey = "com.flashcardapp.dictionary.showReadings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var showReadings: Bool {
        get { defaults.object(forKey: readingsKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: readingsKey) }
    }
}
