import UIKit

extension DictionaryEntryViewController {
    func vocabularyContents(_ vocabulary: VocabularyDetail, state: DictionaryEntryState) -> [UIView] {
        var views: [UIView] = []
        if let reading = vocabulary.reading {
            let readingLabel = label(.reading, reading)
            readingLabel.accessibilityIdentifier = "entry_reading"
            views.append(readingLabel)
        }
        let headword = label(.entryHeadword, vocabulary.headword)
        headword.accessibilityIdentifier = "entry_title"
        headword.accessibilityTraits = .header
        views.append(headword)
        if let metadata = metadataLine(level: vocabulary.level, hanViet: vocabulary.hanViet) { views.append(spaced(metadata, before: Design.Spacing.xs)) }
        for pattern in vocabulary.pitch { views.append(pitchBlock(pattern)) }
        let spoken = (vocabulary.reading?.split(separator: " ").first).map(String.init) ?? vocabulary.headword
        views.append(actionRow(speak: spoken, state: state))

        views += meaningSection(vocabulary.meanings)
        views += kanjiSection(title: NSLocalizedString("Kanji in this word", comment: "Section title"), state: state.kanji)
        views += examplesSection(state: state, terms: TextHighlight.terms(forHeadword: vocabulary.headword),
                                 title: NSLocalizedString("Example sentences", comment: "Section title"))
        return views
    }

    // MARK: Pieces shared by the entry kinds

    func metadataLine(level: String?, hanViet: String?, extra: [String] = []) -> UIView? {
        var parts: [String] = []
        if let level { parts.append(String(format: NSLocalizedString("JLPT level %@", comment: "Level tag; %@ is N5…N1"), level)) }
        if let hanViet { parts.append(String(format: NSLocalizedString("Sino-Vietnamese: %@", comment: "Hán Việt reading; %@ is the reading"), hanViet)) }
        parts += extra
        guard !parts.isEmpty else { return nil }
        let line = label(.metadata, parts.joined(separator: "  ·  "))
        line.accessibilityIdentifier = "entry_metadata"
        return line
    }

    func pitchBlock(_ pattern: PitchPattern) -> UIView {
        let drawing = PitchAccentView(pattern: pattern)
        drawing.translatesAutoresizingMaskIntoConstraints = false
        // A long word may be wider than the screen: the drawing scrolls sideways instead of squeezing the kana together.
        let scroller = UIScrollView()
        scroller.showsHorizontalScrollIndicator = false
        scroller.addSubview(drawing)
        NSLayoutConstraint.activate([
            drawing.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor),
            drawing.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor),
            drawing.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
            drawing.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
            scroller.heightAnchor.constraint(equalToConstant: drawing.intrinsicContentSize.height + 2)
        ])
        let caption = label(.metadata, PitchAccentView.caption(for: pattern))
        caption.isAccessibilityElement = false
        let row = UIStackView(arrangedSubviews: [scroller, caption])
        row.axis = useVerticalActions ? .vertical : .horizontal
        row.alignment = useVerticalActions ? .fill : .bottom
        row.spacing = Design.Spacing.m
        scroller.setContentHuggingPriority(.defaultLow, for: .horizontal)
        caption.setContentHuggingPriority(.required, for: .horizontal)
        return spaced(row, before: Design.Spacing.m)
    }

    func meaningSection(_ meanings: [VocabularyDetail.Meaning]) -> [UIView] {
        guard !meanings.isEmpty else { return [] }
        let rows = meanings.enumerated().map { index, meaning -> UIView in
            let text = NSMutableAttributedString()
            if meanings.count > 1 {
                text.append(NSAttributedString(string: "\(index + 1)  ", attributes: [.font: Design.TextRole.sentence.font.withWeight(.semibold), .foregroundColor: Design.Color.accent]))
            }
            if let pos = meaning.partOfSpeech {
                text.append(NSAttributedString(string: pos + "  ", attributes: [.font: Design.TextRole.metadata.font, .foregroundColor: Design.Color.textSecondary]))
            }
            text.append(NSAttributedString(string: meaning.text, attributes: [.font: Design.TextRole.sentence.font, .foregroundColor: Design.Color.textPrimary]))
            let body = UILabel()
            body.numberOfLines = 0
            body.adjustsFontForContentSizeCategory = true
            body.attributedText = text
            body.accessibilityIdentifier = "entry_meaning_\(index + 1)"
            guard let note = meaning.note else { return body }
            let box = UIStackView(arrangedSubviews: [body, label(.metadata, note)])
            box.axis = .vertical
            box.spacing = Design.Spacing.xs
            return box
        }
        return section(NSLocalizedString("Meaning", comment: "Section title"), rows)
    }

    func kanjiSection(title: String, state: Loadable<[KanjiReference]>) -> [UIView] {
        switch state {
        case .idle, .failed: return []
        case .loading: return section(title, [loadingRow()])
        case .loaded(let kanji):
            guard !kanji.isEmpty else { return [] }
            let flow = ChipFlowView()
            flow.setChips(kanji.map { reference in
                chip(glyph: reference.character, caption: reference.meaning, identifier: "entry_kanji_\(reference.character)") { [weak self] in
                    self?.presenter.openKanji(reference)
                }
            })
            return section(title, [flow])
        }
    }

    /// One kanji (or component) as a tappable chip: the character large, its Sino-Vietnamese reading under it.
    func chip(glyph: String, caption: String?, identifier: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.gray()
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        var title = AttributedString(glyph)
        title.font = Design.TextRole.numeral.font.withSize(30)
        title.foregroundColor = Design.Color.textPrimary
        configuration.attributedTitle = title
        if let caption {
            var subtitle = AttributedString(caption)
            subtitle.font = UIFont.preferredFont(forTextStyle: .caption1)
            subtitle.foregroundColor = Design.Color.textSecondary
            configuration.attributedSubtitle = subtitle
            configuration.titlePadding = 2
        }
        button.configuration = configuration
        button.accessibilityLabel = [glyph, caption].compactMap { $0 }.joined(separator: ", ")
        button.accessibilityTraits = .button
        button.accessibilityIdentifier = identifier
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    // MARK: Example sentences

    func examplesSection(state: DictionaryEntryState, terms: [String], title: String) -> [UIView] {
        switch state.examples {
        case .idle:
            return []
        case .loading:
            return section(title, [loadingRow()])
        case .failed(let message):
            return section(title, [errorBlock(message: message, retry: { [weak self] in self?.presenter.retryExamples() }, identifier: "entry_examples_retry")])
        case .loaded(let examples):
            guard !examples.isEmpty else {
                return section(title, [quietNote(NSLocalizedString("No example sentences found for this entry.", comment: ""))])
            }
            let hasReadings = examples.contains { !$0.reading.isEmpty }
            let toggleTitle = state.showReadings ? NSLocalizedString("Hide readings", comment: "") : NSLocalizedString("Show readings", comment: "")
            let rows = examples.enumerated().map { index, example in
                exampleRow(example, index: index, terms: terms, showReading: state.showReadings)
            }
            return section(title, actionTitle: hasReadings ? toggleTitle : nil,
                           action: hasReadings ? { [weak self] in self?.presenter.setShowReadings(!state.showReadings) } : nil,
                           actionIdentifier: "entry_readings_toggle", separatedRows(rows))
        }
    }

    func exampleRow(_ example: CardExample, index: Int, terms: [String], showReading: Bool) -> UIView {
        let row = EntryRowControl()
        let lead = TextHighlight.attributed(example.japanese, terms: terms, font: Design.TextRole.sentence.font, color: Design.Color.textPrimary)
        let reading = showReading && !example.reading.isEmpty
            ? NSAttributedString(string: example.reading, attributes: [.font: Design.TextRole.metadata.font, .foregroundColor: Design.Color.textSecondary]) : nil
        let translation = example.translation.isEmpty ? nil
            : NSAttributedString(string: example.translation, attributes: [.font: Design.TextRole.meaning.font, .foregroundColor: Design.Color.textSecondary])
        row.configure(lead: lead, second: reading, third: translation,
                      accessibilityLabel: [example.japanese, example.translation].filter { !$0.isEmpty }.joined(separator: ". "),
                      speak: { [weak self] in self?.presenter.speak(example.japanese) },
                      speakLabel: NSLocalizedString("Listen", comment: ""),
                      onOpen: { [weak self] in self?.presenter.open(example: example) })
        row.accessibilityIdentifier = "entry_example_\(index + 1)"
        row.menuProvider = { [weak self] in
            UIMenu(children: [
                UIAction(title: NSLocalizedString("Copy sentence", comment: ""), image: UIImage(systemName: "doc.on.doc")) { _ in
                    self?.presenter.copy(example.japanese, what: NSLocalizedString("Sentence", comment: ""))
                },
                UIAction(title: NSLocalizedString("Copy all", comment: ""), image: UIImage(systemName: "doc.on.doc")) { _ in
                    self?.presenter.copy(example.copyText, what: NSLocalizedString("Sentence", comment: ""))
                },
                UIAction(title: NSLocalizedString("Listen", comment: ""), image: UIImage(systemName: "speaker.wave.2")) { _ in self?.presenter.speak(example.japanese) },
                UIAction(title: NSLocalizedString("Share", comment: ""), image: UIImage(systemName: "square.and.arrow.up")) { _ in self?.presenter.share(example.copyText) }
            ])
        }
        return row
    }
}
