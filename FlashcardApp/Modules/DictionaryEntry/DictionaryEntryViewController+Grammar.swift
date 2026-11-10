import UIKit

extension DictionaryEntryViewController {
    func grammarContents(_ grammar: GrammarDetail, state: DictionaryEntryState) -> [UIView] {
        var views: [UIView] = []
        let pattern = label(.entryHeadword, grammar.pattern)
        pattern.accessibilityIdentifier = "entry_title"
        pattern.accessibilityTraits = .header
        views.append(pattern)
        let meaning = label(.sentence, grammar.meaning)
        meaning.accessibilityIdentifier = "entry_meaning_1"
        views.append(spaced(meaning, before: Design.Spacing.s))
        if let metadata = metadataLine(level: grammar.level, hanViet: nil, extra: grammar.category.map { [$0] } ?? []) {
            views.append(spaced(metadata, before: Design.Spacing.xs))
        }
        views.append(actionRow(speak: nil, state: state))

        for (index, part) in grammar.sections.enumerated() {
            var body: [UIView] = []
            if let formation = part.formation {
                let formationLabel = label(.headword, formation)
                formationLabel.accessibilityIdentifier = "entry_formation_\(index + 1)"
                body.append(labeled(NSLocalizedString("Structure", comment: "Grammar: how the pattern is formed"), formationLabel))
            }
            if let own = part.meaning, own != grammar.meaning {
                body.append(labeled(NSLocalizedString("Meaning", comment: ""), label(.explanation, own)))
            }
            if let explanation = part.explanation {
                body.append(labeled(NSLocalizedString("Explanation", comment: ""), label(.explanation, explanation)))
            }
            if let note = part.note {
                body.append(labeled(NSLocalizedString("Notes", comment: "Grammar: exceptions and cautions"), label(.explanation, note)))
            }
            guard !body.isEmpty else { continue }
            let title = grammar.sections.count > 1
                ? String(format: NSLocalizedString("Usage %lld", comment: "Section title for the n-th usage of a grammar point"), index + 1)
                : NSLocalizedString("Usage", comment: "Section title")
            views += section(title, body.flatMap { [$0] })
        }
        if let term = grammar.exampleTerm {
            views += examplesSection(state: state, terms: [term],
                                     title: String(format: NSLocalizedString("Sentences containing “%@”", comment: "Section title; %@ is the grammar pattern"), term))
        }
        return views
    }

    /// A small heading over a block of text.
    private func labeled(_ title: String, _ body: UILabel) -> UIView {
        let heading = label(.metadata, title)
        heading.font = UIFont.preferredFont(forTextStyle: .footnote).withWeight(.semibold)
        let box = UIStackView(arrangedSubviews: [heading, body])
        box.axis = .vertical
        box.spacing = Design.Spacing.xs
        return spaced(box, before: Design.Spacing.s)
    }
}
