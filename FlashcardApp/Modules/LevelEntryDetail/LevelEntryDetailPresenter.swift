import AVFoundation
import Foundation
import UIKit

/// A single vocabulary, kanji, or grammar item opened from a BJT level list.
/// Built from the level endpoint's decoded DTOs; never invents meanings, readings, or examples.
struct LevelEntry: Equatable {
    let id: String
    let kind: HomeContentKind
    let levelCode: String
    let levelName: String
    let title: String
    let reading: String?
    let onyomi: String?
    let kunyomi: String?
    let shortMeaning: String?
    let explanations: [String]
    let hasLessons: Bool

    /// Non-nil when `id` is a valid backend UUID that can be opened in `DictionaryEntry`.
    var dictionaryItem: DictionaryItem? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: id) != nil, !trimmedTitle.isEmpty else { return nil }
        let dictionaryKind: DictionaryItemKind
        let combinedReading: String?
        switch kind {
        case .vocabulary:
            dictionaryKind = .vocabulary
            combinedReading = Self.clean(reading)
        case .kanji:
            dictionaryKind = .kanji
            let parts = [Self.clean(onyomi), Self.clean(kunyomi)].compactMap { $0 }
            combinedReading = parts.isEmpty ? Self.clean(reading) : parts.joined(separator: " · ")
        case .grammar:
            dictionaryKind = .grammar
            combinedReading = nil
        }
        return DictionaryItem(kind: dictionaryKind, id: id, title: trimmedTitle,
                              reading: combinedReading, meaning: Self.clean(shortMeaning), level: levelCode)
    }

    /// Plain summary for Copy and Share actions.
    var summaryText: String {
        var lines: [String] = []
        var head = title
        if let reading = Self.clean(reading), reading != title { head += "（\(reading)）" }
        lines.append(head)
        if let shortMeaning = Self.clean(shortMeaning) { lines.append(shortMeaning) }
        if let on = Self.clean(onyomi) {
            lines.append("\(NSLocalizedString("On’yomi (Chinese reading)", comment: "")): \(on)")
        }
        if let kun = Self.clean(kunyomi) {
            lines.append("\(NSLocalizedString("Kun’yomi (Japanese reading)", comment: "")): \(kun)")
        }
        let extra = filteredExplanations
        lines.append(contentsOf: extra)
        return lines.joined(separator: "\n")
    }

    /// Explanations/senses trimmed of whitespace and excluding an exact duplicate of `shortMeaning`.
    var filteredExplanations: [String] {
        let normalizedShort = Self.clean(shortMeaning)?.lowercased()
        var seen = Set<String>()
        return explanations.compactMap { raw in
            guard let text = Self.clean(raw) else { return nil }
            let key = text.lowercased()
            if explanations.count == 1, let normalizedShort, key == normalizedShort { return nil }
            guard seen.insert(key).inserted else { return nil }
            return text
        }
    }

    /// Text sent to Japanese TTS when the learner taps Listen.
    var spokenText: String? {
        switch kind {
        case .vocabulary, .grammar:
            return Self.clean(title)
        case .kanji:
            if let kun = Self.clean(kunyomi) { return Self.firstSpokenToken(kun) }
            if let on = Self.clean(onyomi) { return Self.firstSpokenToken(on) }
            return Self.clean(title)
        }
    }

    private static func clean(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func firstSpokenToken(_ readings: String) -> String? {
        let token = readings.split(whereSeparator: { $0 == " " || $0 == "、" || $0 == "·" || $0 == "," }).first.map(String.init) ?? readings
        let stripped = token.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: "-", with: "")
        return clean(stripped)
    }
}

struct LevelEntryDetailState: Equatable {
    let eyebrow: String
    let title: String
    let isKanjiGlyph: Bool
    let reading: String?
    let onyomi: String?
    let kunyomi: String?
    let shortMeaning: String?
    let detailSectionTitle: String?
    let detailItems: [String]
    let hasBodyContent: Bool
    let canSpeak: Bool
    let canOpenDictionary: Bool
    let lessonsButtonTitle: String?
}

protocol LevelEntryDetailViewInterface: AnyObject {
    func render(_ state: LevelEntryDetailState)
    func showToast(_ message: String)
    func showVoiceUnavailable()
}

protocol LevelEntryDetailPresenterInterface: AnyObject {
    func viewDidLoad()
    func viewWillDisappear()
    func speak()
    func openDictionaryEntry()
    func openLessons()
    func copySummary()
    func share()
    func openSystemSettings()
}

final class LevelEntryDetailPresenter: LevelEntryDetailPresenterInterface {
    private let entry: LevelEntry
    private let wireframe: LevelEntryDetailWireframeInterface
    private let speech: SpeechServiceInterface
    private let hasJapaneseVoice: () -> Bool
    private let copyToPasteboard: (String) -> Void
    weak var view: LevelEntryDetailViewInterface?

    init(entry: LevelEntry,
         wireframe: LevelEntryDetailWireframeInterface,
         speech: SpeechServiceInterface = SystemSpeechService.shared,
         hasJapaneseVoice: @escaping () -> Bool = { AVSpeechSynthesisVoice(language: "ja-JP") != nil },
         copyToPasteboard: @escaping (String) -> Void = { UIPasteboard.general.string = $0 }) {
        self.entry = entry
        self.wireframe = wireframe
        self.speech = speech
        self.hasJapaneseVoice = hasJapaneseVoice
        self.copyToPasteboard = copyToPasteboard
    }

    func viewDidLoad() {
        view?.render(Self.makeState(for: entry))
    }

    func viewWillDisappear() {
        speech.stop()
    }

    func speak() {
        guard let text = entry.spokenText else { return }
        guard hasJapaneseVoice() else {
            view?.showVoiceUnavailable()
            return
        }
        speech.speak(text, languageCode: "ja-JP")
    }

    func openDictionaryEntry() {
        guard let item = entry.dictionaryItem else { return }
        wireframe.showDictionaryEntry(item)
    }

    func openLessons() {
        guard entry.hasLessons else { return }
        wireframe.showLessons()
    }

    func copySummary() {
        copyToPasteboard(entry.summaryText)
        view?.showToast(NSLocalizedString("Copied", comment: ""))
    }

    func share() {
        wireframe.share(entry.summaryText)
    }

    func openSystemSettings() {
        wireframe.openSystemSettings()
    }

    static func makeState(for entry: LevelEntry) -> LevelEntryDetailState {
        let shortMeaning = entry.shortMeaning?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonEmptyShort = (shortMeaning?.isEmpty == false) ? shortMeaning : nil
        let reading = entry.reading?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonEmptyReading = (reading?.isEmpty == false && entry.kind != .kanji) ? reading : nil
        let onyomi = entry.onyomi?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonEmptyOn = (onyomi?.isEmpty == false) ? onyomi : nil
        let kunyomi = entry.kunyomi?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonEmptyKun = (kunyomi?.isEmpty == false) ? kunyomi : nil
        let details = entry.filteredExplanations

        let sectionTitle: String?
        if details.isEmpty {
            sectionTitle = nil
        } else {
            switch entry.kind {
            case .vocabulary: sectionTitle = NSLocalizedString("Meanings", comment: "Level entry detail: vocabulary senses section")
            case .grammar: sectionTitle = NSLocalizedString("Explanation", comment: "Level entry detail: grammar explanation section")
            case .kanji: sectionTitle = NSLocalizedString("Explanation", comment: "Level entry detail: explanation section")
            }
        }

        let hasBody = nonEmptyShort != nil || !details.isEmpty || nonEmptyOn != nil || nonEmptyKun != nil || nonEmptyReading != nil
        let lessonsTitle = entry.hasLessons
            ? String(format: NSLocalizedString("Lessons for %@", comment: "Level entry detail: open structured lessons for this level"), entry.levelCode)
            : nil

        return LevelEntryDetailState(
            eyebrow: "\(entry.levelCode) · \(entry.kind.title)",
            title: entry.title,
            isKanjiGlyph: entry.kind == .kanji,
            reading: nonEmptyReading,
            onyomi: nonEmptyOn,
            kunyomi: nonEmptyKun,
            shortMeaning: nonEmptyShort,
            detailSectionTitle: sectionTitle,
            detailItems: details,
            hasBodyContent: hasBody,
            canSpeak: entry.spokenText != nil,
            canOpenDictionary: entry.dictionaryItem != nil,
            lessonsButtonTitle: lessonsTitle
        )
    }
}
