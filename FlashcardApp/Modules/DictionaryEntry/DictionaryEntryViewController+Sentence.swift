import UIKit

extension DictionaryEntryViewController {
    func sentenceContents(_ sentence: SentenceDetail, state: DictionaryEntryState) -> [UIView] {
        var views: [UIView] = []
        let text = UITextView()
        text.isEditable = false
        text.isSelectable = true
        text.isScrollEnabled = false
        text.backgroundColor = .clear
        text.textContainerInset = .zero
        text.textContainer.lineFragmentPadding = 0
        text.adjustsFontForContentSizeCategory = true
        text.font = Design.TextRole.sentence.font.withSize(Design.TextRole.sentence.font.pointSize + 4)
        text.text = sentence.japanese
        text.delegate = self
        text.accessibilityIdentifier = "entry_title"
        text.accessibilityLabel = sentence.japanese
        views.append(text)
        if let reading = sentence.reading, state.showReadings {
            views.append(spaced(label(.reading, reading), before: Design.Spacing.s))
        }
        if let translation = sentence.translation {
            let translationLabel = label(.sentence, translation, color: Design.Color.textSecondary)
            translationLabel.accessibilityIdentifier = "entry_translation"
            views.append(spaced(translationLabel, before: Design.Spacing.m))
        }
        views.append(actionRow(speak: sentence.japanese, state: state))
        if sentence.reading != nil {
            let toggleTitle = state.showReadings ? NSLocalizedString("Hide readings", comment: "") : NSLocalizedString("Show readings", comment: "")
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.plain()
            configuration.title = toggleTitle
            configuration.baseForegroundColor = Design.Color.accent
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 8)
            button.configuration = configuration
            button.contentHorizontalAlignment = .leading
            button.accessibilityIdentifier = "entry_readings_toggle"
            button.addAction(UIAction { [weak self] _ in self?.presenter.setShowReadings(!state.showReadings) }, for: .touchUpInside)
            views.append(button)
        }
        views += kanjiSection(title: NSLocalizedString("Kanji in this sentence", comment: "Section title"), state: state.kanji)
        views.append(spaced(quietNote(NSLocalizedString("Select any part of the sentence and choose “Look up in dictionary”.", comment: "Hint under a sentence")), before: Design.Spacing.xl))
        return views
    }
}
