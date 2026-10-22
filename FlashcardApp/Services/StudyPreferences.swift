import Foundation

/// How the learner likes to study. Device-local, like the other settings; never synchronised.
protocol StudyPreferencesInterface: AnyObject {
    var isReadingVisible: Bool { get set }
    var areImagesVisible: Bool { get set }
    var autoSpeak: Bool { get set }
    var isShuffled: Bool { get set }
    var mode: StudyMode { get set }
}

final class UserDefaultsStudyPreferences: StudyPreferencesInterface {
    static let shared = UserDefaultsStudyPreferences()

    private let defaults: UserDefaults
    private enum Keys {
        static let reading = "com.flashcardapp.study.readingVisible"
        static let images = "com.flashcardapp.study.imagesVisible"
        static let autoSpeak = "com.flashcardapp.study.autoSpeak"
        static let shuffled = "com.flashcardapp.study.shuffled"
        static let mode = "com.flashcardapp.study.mode"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isReadingVisible: Bool {
        get { defaults.object(forKey: Keys.reading) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.reading) }
    }

    var areImagesVisible: Bool {
        get { defaults.object(forKey: Keys.images) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.images) }
    }

    var autoSpeak: Bool {
        get { defaults.bool(forKey: Keys.autoSpeak) }
        set { defaults.set(newValue, forKey: Keys.autoSpeak) }
    }

    var isShuffled: Bool {
        get { defaults.bool(forKey: Keys.shuffled) }
        set { defaults.set(newValue, forKey: Keys.shuffled) }
    }

    var mode: StudyMode {
        get { defaults.string(forKey: Keys.mode).flatMap(StudyMode.init(rawValue:)) ?? .flip }
        set { defaults.set(newValue.rawValue, forKey: Keys.mode) }
    }
}
