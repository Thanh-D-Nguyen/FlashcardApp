import UIKit

/// Building blocks of the article screen. Each function turns a piece of state into views; none of them decides anything.
enum MagazineArticleViews {

    // MARK: Primitives

    static func label(_ text: String, role: Design.TextRole, color: UIColor? = nil, japanese: Bool = false, traits: UIAccessibilityTraits? = nil) -> UILabel {
        let label = UILabel()
        label.apply(role)
        label.text = text
        if let color { label.textColor = color }
        if japanese { label.markJapanese() }
        if let traits { label.accessibilityTraits = traits }
        return label
    }

    static func sectionTitle(_ text: String, symbol: String? = nil, tint: UIColor = Design.Color.accent) -> UIView {
        let title = label(text, role: .headword, traits: .header)
        title.font = Design.TextRole.headword.font.withWeight(.semibold)
        guard let symbol else { return title }
        let tile = MagazineSymbolTile(side: 32)
        tile.configure(symbol: symbol, tint: tint)
        let row = UIStackView(arrangedSubviews: [tile, title])
        row.alignment = .center
        row.spacing = Design.Spacing.m
        return row
    }

    static func card(_ views: [UIView], spacing: CGFloat = Design.Spacing.s, fill: UIColor = Design.Color.surface) -> UIView {
        let container = UIView()
        container.backgroundColor = fill
        container.layer.cornerRadius = 20
        container.layer.cornerCurve = .continuous
        let inner = UIStackView(arrangedSubviews: views)
        inner.axis = .vertical
        inner.spacing = spacing
        inner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: container.topAnchor, constant: Design.Spacing.l),
            inner.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Design.Spacing.l),
            inner.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Design.Spacing.l),
            inner.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Design.Spacing.l)
        ])
        return container
    }

    /// A short outlined label, such as a JLPT level.
    static func tag(_ text: String, color: UIColor = Design.Color.textSecondary) -> UIView {
        let tagLabel = label(text, role: .metadata, color: color)
        tagLabel.font = Design.TextRole.metadata.font.withWeight(.semibold)
        tagLabel.numberOfLines = 1
        let box = UIView()
        box.layer.cornerRadius = 6
        box.layer.borderWidth = 1
        box.layer.borderColor = color.cgColor
        tagLabel.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(tagLabel)
        NSLayoutConstraint.activate([
            tagLabel.topAnchor.constraint(equalTo: box.topAnchor, constant: 2),
            tagLabel.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -2),
            tagLabel.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: Design.Spacing.s),
            tagLabel.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -Design.Spacing.s)
        ])
        box.setContentHuggingPriority(.required, for: .horizontal)
        box.setContentCompressionResistancePriority(.required, for: .horizontal)
        return box
    }

    static func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = Design.Color.separator
        line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return line
    }

    /// A Japanese line with its Vietnamese translation under it.
    static func pair(japanese: String?, meaning: String?, japaneseRole: Design.TextRole = .sentence) -> [UIView] {
        var views: [UIView] = []
        if let japanese { views.append(label(japanese, role: japaneseRole, japanese: true)) }
        if let meaning { views.append(label(meaning, role: .reading)) }
        return views
    }

    // MARK: Header

    static func header(_ header: MagazineArticleState.Header) -> UIView {
        let kind = label(header.eyebrow.uppercased(), role: .eyebrow, color: header.kind.tint)
        let kindIcon = UIImageView(image: UIImage(systemName: header.kind.symbol))
        kindIcon.tintColor = header.kind.tint
        kindIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .small)
        kindIcon.setContentHuggingPriority(.required, for: .horizontal)
        var eyebrowViews: [UIView] = [kindIcon, kind]
        if let level = header.level { eyebrowViews += [UIView(), tag(level)] }
        let eyebrow = UIStackView(arrangedSubviews: eyebrowViews)
        eyebrow.alignment = .center
        eyebrow.spacing = Design.Spacing.xs

        var views: [UIView] = [eyebrow]
        if let date = header.dateText { views.append(label(date, role: .metadata)) }
        views.append(label(header.titleJapanese, role: .articleTitle, japanese: true, traits: .header))
        if !header.titleVietnamese.isEmpty { views.append(label(header.titleVietnamese, role: .meaning, color: Design.Color.textSecondary)) }
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = Design.Spacing.s
        stack.setCustomSpacing(Design.Spacing.m, after: eyebrow)
        if let summary = summary(header), let last = stack.arrangedSubviews.last {
            stack.setCustomSpacing(Design.Spacing.l, after: last)
            stack.addArrangedSubview(summary)
        }
        return stack
    }

    /// The summary set apart by a rule on the left, like the standfirst of a printed article.
    private static func summary(_ header: MagazineArticleState.Header) -> UIView? {
        let views = pair(japanese: header.summaryJapanese, meaning: header.summaryVietnamese, japaneseRole: .explanation)
        guard !views.isEmpty else { return nil }
        let text = UIStackView(arrangedSubviews: views)
        text.axis = .vertical
        text.spacing = Design.Spacing.xs
        let rule = UIView()
        rule.backgroundColor = header.kind.tint
        rule.layer.cornerRadius = 1.5
        rule.translatesAutoresizingMaskIntoConstraints = false
        rule.widthAnchor.constraint(equalToConstant: 3).isActive = true
        let row = UIStackView(arrangedSubviews: [rule, text])
        row.spacing = Design.Spacing.m
        return row
    }

    // MARK: Body

    static func blocks(_ blocks: [MagazineArticle.Block], kind: MagazineKind) -> [UIView] {
        blocks.flatMap { block -> [UIView] in
            switch block {
            case .phrase(let japanese, let reading, let literal, let formality):
                return [phrase(japanese: japanese, reading: reading, literal: literal, formality: formality, kind: kind)]
            case .weather(let weather):
                return [self.weather(weather, kind: kind)]
            case .passage(let japanese, let meaning):
                let stack = UIStackView(arrangedSubviews: pair(japanese: japanese, meaning: meaning))
                stack.axis = .vertical
                stack.spacing = Design.Spacing.xs
                return [stack]
            case .dialogue(let lines):
                return [dialogue(lines, kind: kind)]
            case .usage(let japanese, let meaning):
                let views = [label(NSLocalizedString("Usage note", comment: "Magazine"), role: .eyebrow, traits: .header)] + pair(japanese: japanese, meaning: meaning, japaneseRole: .explanation)
                return [card(views, spacing: Design.Spacing.xs)]
            case .situations(let situations):
                return [self.situations(situations)]
            case .horoscope(let fortunes):
                return [horoscope(fortunes, kind: kind)]
            }
        }
    }

    private static func phrase(japanese: String, reading: String?, literal: String?, formality: MagazineArticle.Formality?, kind: MagazineKind) -> UIView {
        var views: [UIView] = [label(NSLocalizedString("Phrase of the day", comment: "Magazine"), role: .eyebrow, traits: .header),
                               label(japanese, role: .articleTitle, japanese: true)]
        if let reading { views.append(label(reading, role: .reading, japanese: true)) }
        if let literal { views.append(label(String(format: NSLocalizedString("Literally: %@", comment: "Magazine: literal meaning of a phrase"), literal), role: .meaning)) }
        if let formality {
            // Left aligned, at its own width.
            views.append(UIStackView(arrangedSubviews: [tag(formalityName(formality), color: kind.tint), UIView()]))
        }
        return card(views, spacing: Design.Spacing.xs)
    }

    static func formalityName(_ formality: MagazineArticle.Formality) -> String {
        switch formality {
        case .polite: return NSLocalizedString("Polite", comment: "Magazine: level of formality")
        case .casual: return NSLocalizedString("Casual", comment: "Magazine: level of formality")
        case .formal: return NSLocalizedString("Formal", comment: "Magazine: level of formality")
        case .humble: return NSLocalizedString("Humble", comment: "Magazine: level of formality")
        }
    }

    private static func weather(_ weather: MagazineArticle.Weather, kind: MagazineKind) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: weather.symbol))
        icon.tintColor = kind.tint
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.isAccessibilityElement = false
        var headline: [UIView] = []
        if let city = weather.city { headline.append(label(city, role: .eyebrow, japanese: true)) }
        headline.append(label(weather.descriptionJapanese, role: .headword, japanese: true))
        if let description = weather.description { headline.append(label(description, role: .reading)) }
        let titleStack = UIStackView(arrangedSubviews: headline)
        titleStack.axis = .vertical
        titleStack.spacing = 2
        let top = UIStackView(arrangedSubviews: [icon, titleStack])
        top.alignment = .center
        top.spacing = Design.Spacing.l

        var facts: [String] = []
        if let high = weather.highC { facts.append(String(format: NSLocalizedString("High %lld°", comment: "Magazine weather"), high)) }
        if let low = weather.lowC { facts.append(String(format: NSLocalizedString("Low %lld°", comment: "Magazine weather"), low)) }
        if let humidity = weather.humidityPercent { facts.append(String(format: NSLocalizedString("Humidity %lld%%", comment: "Magazine weather"), humidity)) }
        if let uv = weather.uvIndex { facts.append(String(format: NSLocalizedString("UV %lld", comment: "Magazine weather: UV index"), uv)) }
        var views: [UIView] = [top]
        if !facts.isEmpty { views.append(DiscoverTagFlow(tags: facts)) }
        if weather.adviceJapanese != nil || weather.advice != nil {
            views.append(separator())
            views.append(label(NSLocalizedString("Advice", comment: "Magazine weather"), role: .eyebrow, traits: .header))
            views += pair(japanese: weather.adviceJapanese, meaning: weather.advice, japaneseRole: .explanation)
        }
        return card(views, spacing: Design.Spacing.m)
    }

    private static func dialogue(_ lines: [MagazineArticle.DialogueLine], kind: MagazineKind) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.addArrangedSubview(sectionTitle(NSLocalizedString("Dialogue", comment: "Magazine"), symbol: "bubble.left.and.bubble.right.fill", tint: kind.tint))
        for line in lines {
            var views: [UIView] = []
            if let speaker = line.speaker { views.append(label(speaker, role: .eyebrow, color: kind.tint, japanese: true)) }
            views += pair(japanese: line.japanese, meaning: line.meaning)
            stack.addArrangedSubview(card(views, spacing: Design.Spacing.xs))
        }
        return stack
    }

    private static func situations(_ situations: [MagazineArticle.Situation]) -> UIView {
        var views: [UIView] = [label(NSLocalizedString("When to use it", comment: "Magazine"), role: .eyebrow, traits: .header)]
        for situation in situations {
            let bullet = label("•", role: .meaning, color: Design.Color.textSecondary)
            bullet.isAccessibilityElement = false
            bullet.setContentHuggingPriority(.required, for: .horizontal)
            let text = UIStackView(arrangedSubviews: pair(japanese: situation.japanese, meaning: situation.meaning, japaneseRole: .meaning))
            text.axis = .vertical
            text.spacing = 0
            let row = UIStackView(arrangedSubviews: [bullet, text])
            row.alignment = .firstBaseline
            row.spacing = Design.Spacing.s
            views.append(row)
        }
        return card(views, spacing: Design.Spacing.s)
    }

    private static func horoscope(_ fortunes: [MagazineArticle.Fortune], kind: MagazineKind) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.addArrangedSubview(sectionTitle(NSLocalizedString("Today's fortunes", comment: "Magazine"), symbol: "sparkles", tint: kind.tint))
        for fortune in fortunes {
            var head: [UIView] = [label(fortune.sign, role: .headword, japanese: true)]
            if let reading = fortune.reading { head.append(label(reading, role: .reading, japanese: true)) }
            let name = UIStackView(arrangedSubviews: head)
            name.axis = .vertical
            var top: [UIView] = [name, UIView()]
            if let result = fortune.fortune { top.append(tag(result, color: kind.tint)) }
            let row = UIStackView(arrangedSubviews: top)
            row.alignment = .top
            row.spacing = Design.Spacing.s
            var views: [UIView] = [row]
            if let meaning = fortune.signMeaning ?? fortune.fortuneMeaning {
                let caption = fortune.signMeaning != nil && fortune.fortuneMeaning != nil ? "\(fortune.signMeaning ?? "") · \(fortune.fortuneMeaning ?? "")" : meaning
                views.append(label(caption, role: .reading))
            }
            views += pair(japanese: fortune.message, meaning: fortune.messageMeaning, japaneseRole: .explanation)
            var lucky: [String] = []
            if let color = fortune.luckyColor { lucky.append(String(format: NSLocalizedString("Lucky colour: %@", comment: "Magazine horoscope"), color)) }
            if let number = fortune.luckyNumber { lucky.append(String(format: NSLocalizedString("Lucky number: %lld", comment: "Magazine horoscope"), number)) }
            if !lucky.isEmpty { views.append(label(lucky.joined(separator: "  ·  "), role: .metadata)) }
            stack.addArrangedSubview(card(views, spacing: Design.Spacing.xs))
        }
        return stack
    }
}
