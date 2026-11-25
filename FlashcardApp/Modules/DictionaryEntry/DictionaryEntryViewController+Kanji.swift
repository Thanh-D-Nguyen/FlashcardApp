import UIKit

extension DictionaryEntryViewController {
    func kanjiContents(_ kanji: KanjiDetail, state: DictionaryEntryState) -> [UIView] {
        var views: [UIView] = []

        let glyph = label(.kanjiGlyph, kanji.character)
        glyph.textAlignment = .center
        glyph.accessibilityIdentifier = "entry_title"
        glyph.accessibilityTraits = .header
        glyph.accessibilityLabel = [kanji.character, kanji.meaning].compactMap { $0 }.joined(separator: ", ")
        glyph.setContentHuggingPriority(.required, for: .horizontal)
        glyph.setContentCompressionResistancePriority(.required, for: .horizontal)

        let facts = UIStackView()
        facts.axis = .vertical
        facts.spacing = Design.Spacing.xs
        if let meaning = kanji.meaning {
            let meaningLabel = label(.answer, meaning)
            meaningLabel.font = meaningLabel.font.withWeight(.semibold)
            meaningLabel.accessibilityIdentifier = "entry_meaning_1"
            facts.addArrangedSubview(meaningLabel)
        }
        var numbers: [String] = []
        if let count = kanji.strokeCount { numbers.append(String.localizedStringWithFormat(NSLocalizedString("%lld strokes", comment: "Stroke count of a kanji"), count)) }
        if let level = kanji.level { numbers.append(String(format: NSLocalizedString("JLPT level %@", comment: "Level tag; %@ is N5…N1"), level)) }
        if !numbers.isEmpty { facts.addArrangedSubview(label(.metadata, numbers.joined(separator: "  ·  "))) }
        if let frequency = kanji.frequency {
            facts.addArrangedSubview(label(.metadata, String(format: NSLocalizedString("Frequency rank %@", comment: "Kanji frequency rank; %@ is a number"),
                                                              frequency.formatted(.number.locale(AppLanguage.current.locale)))))
        }

        let header = UIStackView(arrangedSubviews: [glyph, facts])
        header.axis = useVerticalActions ? .vertical : .horizontal
        header.alignment = useVerticalActions ? .leading : .center
        header.spacing = Design.Spacing.l
        views.append(header)
        views.append(actionRow(speak: nil, state: state))

        views += readingsSection(kanji)
        views += strokeSection(kanji, state: state)
        if !kanji.components.isEmpty {
            let flow = ChipFlowView()
            flow.setChips(kanji.components.map { component in
                chip(glyph: component.character, caption: component.hanViet, identifier: "entry_component_\(component.character)") { [weak self] in
                    self?.presenter.openKanji(character: component.character)
                }
            })
            views += section(NSLocalizedString("Components", comment: "Section title: the parts a kanji is built from"), [flow])
        }
        if !kanji.mnemonic.isEmpty { views += mnemonicSection(kanji.mnemonic) }
        views += wordsSection(kanji)
        views += explanationSection(kanji)
        return views
    }

    // MARK: Readings

    private func readingsSection(_ kanji: KanjiDetail) -> [UIView] {
        var rows: [UIView] = []
        func group(_ title: String, _ readings: [String], identifier: String) {
            guard !readings.isEmpty else { return }
            let flow = ChipFlowView()
            flow.setChips(readings.map { reading in readingChip(reading, identifier: "\(identifier)_\(reading)") })
            let heading = label(.metadata, title)
            heading.font = Design.TextRole.weighted(.footnote, weight: .semibold)
            let box = UIStackView(arrangedSubviews: [heading, flow])
            box.axis = .vertical
            box.spacing = Design.Spacing.s
            rows.append(box)
        }
        group(NSLocalizedString("On’yomi (Chinese reading)", comment: ""), kanji.onyomi, identifier: "entry_on")
        group(NSLocalizedString("Kun’yomi (Japanese reading)", comment: ""), kanji.kunyomi, identifier: "entry_kun")
        guard !rows.isEmpty else { return [] }
        return section(NSLocalizedString("Readings", comment: "Section title"), rows)
    }

    /// A reading in kana; tapping it speaks it. The dots and the leading dash of dictionary notation are not spoken.
    private func readingChip(_ reading: String, identifier: String) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .large
        configuration.background.cornerRadius = Design.Radius.chip
        configuration.background.strokeColor = Design.Color.border
        configuration.background.strokeWidth = 1
        configuration.baseBackgroundColor = Design.Color.surface
        configuration.baseForegroundColor = Design.Color.textPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.s, leading: Design.Spacing.m, bottom: Design.Spacing.s, trailing: Design.Spacing.m)
        configuration.title = reading
        configuration.image = UIImage(systemName: "speaker.wave.1")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = Design.Spacing.xs + 2
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .title3)
            return attributes
        }
        button.configuration = configuration
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        let spoken = reading.filter { $0 != "." && $0 != "-" && $0 != "・" }
        button.accessibilityLabel = String(format: NSLocalizedString("Listen to %@", comment: "VoiceOver; %@ is a kana reading"), spoken)
        button.accessibilityIdentifier = identifier
        button.addAction(UIAction { [weak self] _ in self?.presenter.speak(spoken) }, for: .touchUpInside)
        return button
    }

    // MARK: Stroke order

    private func strokeSection(_ kanji: KanjiDetail, state: DictionaryEntryState) -> [UIView] {
        let title = NSLocalizedString("Stroke order", comment: "Section title")
        switch state.stroke {
        case .idle:
            return []
        case .loading:
            return section(title, [loadingRow()])
        case .failed(let message):
            return section(title, [errorBlock(message: message, retry: { [weak self] in self?.presenter.retryStroke() }, identifier: "entry_stroke_retry")])
        case .loaded(let drawing):
            if strokeView == nil || strokeKanjiID != kanji.id {
                strokeView?.pause()
                let canvas = StrokeOrderView(drawing: drawing)
                canvas.onChange = { [weak self] in self?.refreshStrokeControls() }
                strokeView = canvas
                strokeKanjiID = kanji.id
                if !UIAccessibility.isReduceMotionEnabled { canvas.showAll() }
            }
            guard let canvas = strokeView else { return [] }
            canvas.translatesAutoresizingMaskIntoConstraints = false
            let size = canvas.widthAnchor.constraint(equalToConstant: 300)
            size.priority = .defaultHigh
            NSLayoutConstraint.activate([canvas.heightAnchor.constraint(equalTo: canvas.widthAnchor), size,
                                         canvas.widthAnchor.constraint(lessThanOrEqualToConstant: 340)])
            let holder = UIView()
            holder.addSubview(canvas)
            NSLayoutConstraint.activate([
                canvas.topAnchor.constraint(equalTo: holder.topAnchor),
                canvas.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
                canvas.centerXAnchor.constraint(equalTo: holder.centerXAnchor),
                canvas.leadingAnchor.constraint(greaterThanOrEqualTo: holder.leadingAnchor)
            ])
            let credit = label(.metadata, NSLocalizedString("Stroke data: KanjiVG, CC BY-SA 3.0", comment: "Attribution under the stroke order drawing"))
            credit.font = UIFont.preferredFont(forTextStyle: .caption2)
            return section(title, [holder, strokeControlsRow(), credit])
        }
    }

    private func strokeControlsRow() -> UIView {
        func button(_ symbol: String, _ label: String, _ identifier: String, _ action: @escaping () -> Void) -> UIButton {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(systemName: symbol)
            configuration.baseForegroundColor = Design.Color.accent
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .title3)
            button.configuration = configuration
            button.accessibilityLabel = label
            button.accessibilityIdentifier = identifier
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            return button
        }
        let back = button("backward.frame.fill", NSLocalizedString("Previous stroke", comment: ""), "stroke_back") { [weak self] in self?.strokeView?.stepBack() }
        let play = button("play.fill", NSLocalizedString("Play", comment: ""), "stroke_play") { [weak self] in
            guard let canvas = self?.strokeView else { return }
            canvas.isPlaying ? canvas.pause() : canvas.play()
        }
        let forward = button("forward.frame.fill", NSLocalizedString("Next stroke", comment: ""), "stroke_forward") { [weak self] in self?.strokeView?.stepForward() }
        let replay = button("arrow.counterclockwise", NSLocalizedString("Replay", comment: ""), "stroke_replay") { [weak self] in self?.strokeView?.replay() }
        let progress = label(.figure, nil)
        progress.textAlignment = .center
        progress.accessibilityIdentifier = "stroke_progress"
        strokeControls = StrokeControls(play: play, back: back, forward: forward, replay: replay, progress: progress)
        refreshStrokeControls()
        let buttons = UIStackView(arrangedSubviews: [back, play, forward, replay])
        buttons.distribution = .equalSpacing
        buttons.spacing = Design.Spacing.l
        let box = UIStackView(arrangedSubviews: [progress, buttons])
        box.axis = .vertical
        box.alignment = .center
        box.spacing = Design.Spacing.xs
        return box
    }

    func refreshStrokeControls() {
        guard let canvas = strokeView, let controls = strokeControls else { return }
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        controls.play.configuration?.image = UIImage(systemName: canvas.isPlaying ? "pause.fill" : "play.fill")
        controls.play.accessibilityLabel = canvas.isPlaying ? NSLocalizedString("Pause", comment: "") : NSLocalizedString("Play", comment: "")
        controls.play.isEnabled = !reduceMotion
        controls.replay.isEnabled = !reduceMotion
        controls.back.isEnabled = canvas.completedStrokes > 0
        controls.forward.isEnabled = canvas.completedStrokes < canvas.strokeCount
        controls.progress.text = String(format: NSLocalizedString("Stroke %1$lld of %2$lld", comment: "Stroke order progress"), canvas.completedStrokes, canvas.strokeCount)
    }

    // MARK: Mnemonic, words, explanation

    private func mnemonicSection(_ segments: [TextSegment]) -> [UIView] {
        let text = NSMutableAttributedString()
        let font = Design.TextRole.sentence.font
        for segment in segments {
            text.append(NSAttributedString(string: segment.text, attributes: [
                .font: segment.isEmphasised ? font.withWeight(.bold) : font,
                .foregroundColor: segment.isEmphasised ? Design.Color.accent : Design.Color.textPrimary
            ]))
        }
        let body = UILabel()
        body.numberOfLines = 0
        body.adjustsFontForContentSizeCategory = true
        body.attributedText = text
        body.accessibilityIdentifier = "entry_mnemonic"
        return section(NSLocalizedString("Memory aid", comment: "Section title: a mnemonic for remembering the kanji"), [body])
    }

    private func wordsSection(_ kanji: KanjiDetail) -> [UIView] {
        guard !kanji.words.isEmpty else { return [] }
        let visible = expandedWords ? kanji.words : Array(kanji.words.prefix(8))
        let rows = visible.enumerated().map { index, word -> UIView in
            let row = EntryRowControl()
            let lead = NSAttributedString(string: word.word, attributes: [.font: Design.TextRole.headword.font, .foregroundColor: Design.Color.textPrimary])
            let reading = [word.reading, word.hanViet].compactMap { $0 }.joined(separator: "  ·  ")
            let second = reading.isEmpty ? nil : NSAttributedString(string: reading, attributes: [.font: Design.TextRole.metadata.font, .foregroundColor: Design.Color.textSecondary])
            let third = word.meaning.map { NSAttributedString(string: $0, attributes: [.font: Design.TextRole.meaning.font, .foregroundColor: Design.Color.textPrimary]) }
            row.configure(lead: lead, second: second, third: third,
                          accessibilityLabel: [word.word, word.reading, word.meaning].compactMap { $0 }.joined(separator: ", "),
                          onOpen: { [weak self] in self?.presenter.openWord(word.word, reading: word.reading) })
            row.accessibilityIdentifier = "entry_word_\(index + 1)"
            return row
        }
        var body = separatedRows(rows)
        if kanji.words.count > visible.count {
            body.append(moreButton(title: String(format: NSLocalizedString("Show all %lld words", comment: ""), kanji.words.count), identifier: "entry_words_more") { [weak self] in
                self?.expandedWords = true
                self?.rebuild()
            })
        }
        return section(NSLocalizedString("Words with this kanji", comment: "Section title"), body)
    }

    private func explanationSection(_ kanji: KanjiDetail) -> [UIView] {
        guard !kanji.explanation.isEmpty else { return [] }
        let visible = expandedExplanation ? kanji.explanation : Array(kanji.explanation.prefix(2))
        var body: [UIView] = visible.map { label(.explanation, $0) }
        if kanji.explanation.count > visible.count {
            body.append(moreButton(title: NSLocalizedString("Read more", comment: ""), identifier: "entry_explanation_more") { [weak self] in
                self?.expandedExplanation = true
                self?.rebuild()
            })
        }
        return section(NSLocalizedString("Explanation", comment: ""), body)
    }

    private func moreButton(title: String, identifier: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.baseForegroundColor = Design.Color.accent
        configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: 0, bottom: Design.Spacing.m, trailing: Design.Spacing.s)
        button.configuration = configuration
        button.contentHorizontalAlignment = .leading
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        button.accessibilityIdentifier = identifier
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }
}
