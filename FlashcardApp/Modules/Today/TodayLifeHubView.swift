import UIKit

/// One card of the life hub: the animated scene, what the lesson is, a few facts, where they come from, and one action.
final class LifeTopicCardView: UIView {
    var onAction: ((String) -> Void)?
    private(set) var cardID = ""
    /// The width the hub gives the card; it follows the screen width.
    var widthConstraint: NSLayoutConstraint?

    private let scene = LifeSceneView()
    private let badge = UILabel()
    private let badgeBox = UIView()
    private let eyebrow = UILabel()
    private let headline = UILabel()
    private let reading = UILabel()
    private let summary = UILabel()
    private let chips = UIStackView()
    private let meta = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let sheen = CAGradientLayer()
    private let button = UIButton(configuration: Design.Button.primary(title: " "))
    private let content = UIStackView()
    private var card: LifeFeedCard?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Design.Color.surface
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        clipsToBounds = true

        scene.translatesAutoresizingMaskIntoConstraints = false
        badge.font = Design.TextRole.eyebrow.font
        badge.adjustsFontForContentSizeCategory = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeBox.layer.cornerRadius = 9
        badgeBox.layer.cornerCurve = .continuous
        badgeBox.translatesAutoresizingMaskIntoConstraints = false
        badgeBox.addSubview(badge)
        scene.addSubview(badgeBox)
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: badgeBox.topAnchor, constant: 3),
            badge.bottomAnchor.constraint(equalTo: badgeBox.bottomAnchor, constant: -3),
            badge.leadingAnchor.constraint(equalTo: badgeBox.leadingAnchor, constant: 8),
            badge.trailingAnchor.constraint(equalTo: badgeBox.trailingAnchor, constant: -8),
            badgeBox.topAnchor.constraint(equalTo: scene.topAnchor, constant: Design.Spacing.m),
            badgeBox.leadingAnchor.constraint(equalTo: scene.leadingAnchor, constant: Design.Spacing.m)
        ])

        eyebrow.apply(.eyebrow)
        headline.apply(.headword)
        headline.font = Design.TextRole.headword.font.withWeight(.semibold)
        reading.apply(.reading)
        summary.apply(.meaning)
        meta.apply(.metadata)
        chips.axis = .vertical
        chips.spacing = Design.Spacing.xs
        spinner.hidesWhenStopped = true
        sheen.colors = [UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.55).cgColor, UIColor.clear.cgColor]
        sheen.startPoint = CGPoint(x: 0, y: 0.5)
        sheen.endPoint = CGPoint(x: 1, y: 0.5)
        sheen.isHidden = true
        layer.addSublayer(sheen)

        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.fire() }, for: .primaryActionTriggered)
        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        addGestureRecognizer(tap)

        content.axis = .vertical
        content.spacing = Design.Spacing.xs
        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = UIEdgeInsets(top: Design.Spacing.m, left: Design.Spacing.l, bottom: Design.Spacing.l, right: Design.Spacing.l)
        [eyebrow, headline, reading, summary, chips, spinner, meta, button].forEach(content.addArrangedSubview)
        content.setCustomSpacing(Design.Spacing.s, after: summary)
        content.setCustomSpacing(Design.Spacing.m, after: meta)
        let column = UIStackView(arrangedSubviews: [scene, content])
        column.axis = .vertical
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            scene.heightAnchor.constraint(equalToConstant: 124)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        sheen.frame = CGRect(x: 0, y: scene.frame.maxY, width: bounds.width, height: bounds.height - scene.frame.height)
    }

    @objc private func cardTapped() {
        guard card?.status == .ready else { return }
        fire()
    }

    private func fire() { onAction?(cardID) }

    func configure(_ card: LifeFeedCard) {
        self.card = card
        cardID = card.id
        scene.configure(scene: card.scene, topic: card.topic)
        badge.text = Self.badgeText(card.provenance)
        let tint = card.provenance == .sample ? Design.Color.warning : card.provenance == .live ? Design.Color.success : Design.Color.accent
        badge.textColor = tint
        badgeBox.backgroundColor = Design.Color.surface.withAlphaComponent(0.88)
        eyebrow.text = card.eyebrow
        headline.text = card.headlineJapanese
        reading.text = card.reading
        reading.isHidden = card.reading.isEmpty
        summary.text = card.summary
        meta.text = card.meta
        meta.isHidden = card.meta.isEmpty
        chips.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for chip in card.chips.prefix(3) { chips.addArrangedSubview(chipRow(chip)) }
        chips.isHidden = card.chips.isEmpty

        let busy = card.status == .loading || card.status == .locating
        busy ? spinner.startAnimating() : spinner.stopAnimating()
        sheen.isHidden = !busy || UIAccessibility.isReduceMotionEnabled
        sheen.removeAllAnimations()
        if !sheen.isHidden {
            let slide = CABasicAnimation(keyPath: "locations")
            slide.fromValue = [-0.6, -0.3, 0]
            slide.toValue = [1, 1.3, 1.6]
            slide.duration = 1.4
            slide.repeatCount = .infinity
            sheen.add(slide, forKey: "sheen")
        }

        var configuration: UIButton.Configuration
        switch card.status {
        case .ready:
            configuration = Design.Button.primary(title: card.ctaTitle)
            configuration.image = UIImage(systemName: "arrow.right")
        case .needsLocation:
            configuration = Design.Button.primary(title: card.ctaTitle)
            configuration.image = UIImage(systemName: "location.fill")
        case .failed, .locationDenied:
            configuration = UIButton.Configuration.tinted()
            configuration.title = card.ctaTitle
            configuration.cornerStyle = .capsule
            configuration.buttonSize = .large
            configuration.baseForegroundColor = Design.Color.accent
            configuration.baseBackgroundColor = Design.Color.accent
        case .loading, .locating:
            configuration = Design.Button.primary(title: " ")
        }
        configuration.imagePlacement = .trailing
        configuration.imagePadding = Design.Spacing.s
        button.configuration = configuration
        button.isHidden = busy || card.ctaTitle.isEmpty
        button.accessibilityIdentifier = "life_card_action_\(card.id)"
        accessibilityIdentifier = "life_card_\(card.topic.rawValue)"

        let facts = card.chips.map(\.text).joined(separator: ", ")
        headline.accessibilityLabel = [card.eyebrow.capitalized, card.headlineJapanese, card.summary, facts, card.meta].filter { !$0.isEmpty }.joined(separator: ". ")
        [eyebrow, reading, summary, meta, chips, badgeBox].forEach { $0.isAccessibilityElement = false }
        headline.isAccessibilityElement = true
        headline.accessibilityTraits = card.status == .ready ? .button : .staticText
        accessibilityElements = [headline] + (button.isHidden ? [] : [button])
    }

    private func chipRow(_ chip: LifeChip) -> UIView {
        let label = UILabel()
        label.apply(.metadata)
        label.textColor = Design.Color.textPrimary
        label.text = chip.text
        let image = UIImageView(image: chip.symbol.flatMap { UIImage(systemName: $0) })
        image.tintColor = Design.Color.accent
        image.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)
        image.setContentHuggingPriority(.required, for: .horizontal)
        image.widthAnchor.constraint(equalToConstant: 20).isActive = true
        image.contentMode = .center
        let row = UIStackView(arrangedSubviews: [image, label])
        row.spacing = Design.Spacing.s
        row.alignment = .firstBaseline
        return row
    }

    private static func badgeText(_ provenance: LifeProvenance) -> String {
        switch provenance {
        case .live: return "● " + NSLocalizedString("LIVE", comment: "Badge on a life card from a real data source")
        case .onDevice: return NSLocalizedString("ON THIS DEVICE", comment: "Badge on a life card worked out on the device")
        case .sample: return NSLocalizedString("SAMPLE", comment: "Badge on a life card with example content")
        }
    }
}

/// The date at the top of the hub: a calendar tile that flips in, the greeting and the Reiwa date, and the part of the day.
final class TodayDateHeaderView: UIView {
    private let tile = UIView()
    private let month = UILabel()
    private let day = CountUpLabel()
    private let greeting = UILabel()
    private let greetingReading = UILabel()
    private let dateLabel = UILabel()
    private let partOfDay = UIImageView()
    private var shownDay = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        tile.backgroundColor = Design.Color.surface
        tile.layer.cornerRadius = 16
        tile.layer.cornerCurve = .continuous
        tile.translatesAutoresizingMaskIntoConstraints = false
        let strip = UIView()
        strip.backgroundColor = Design.Color.hero
        strip.translatesAutoresizingMaskIntoConstraints = false
        month.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        month.textColor = Design.Color.onHero
        month.textAlignment = .center
        month.translatesAutoresizingMaskIntoConstraints = false
        day.font = UIFont(name: "HiraMinProN-W6", size: 32) ?? .systemFont(ofSize: 32, weight: .bold)
        day.textColor = Design.Color.textPrimary
        day.textAlignment = .center
        day.adjustsFontSizeToFitWidth = true
        day.minimumScaleFactor = 0.6
        day.translatesAutoresizingMaskIntoConstraints = false
        [strip, month, day].forEach(tile.addSubview)
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: 64),
            tile.heightAnchor.constraint(equalToConstant: 72),
            strip.topAnchor.constraint(equalTo: tile.topAnchor),
            strip.leadingAnchor.constraint(equalTo: tile.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: tile.trailingAnchor),
            strip.heightAnchor.constraint(equalToConstant: 20),
            month.centerYAnchor.constraint(equalTo: strip.centerYAnchor),
            month.leadingAnchor.constraint(equalTo: tile.leadingAnchor),
            month.trailingAnchor.constraint(equalTo: tile.trailingAnchor),
            day.topAnchor.constraint(equalTo: strip.bottomAnchor, constant: 2),
            day.bottomAnchor.constraint(equalTo: tile.bottomAnchor, constant: -4),
            day.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 4),
            day.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -4)
        ])
        tile.clipsToBounds = true

        greeting.apply(.headword)
        greeting.font = Design.TextRole.headword.font.withWeight(.semibold)
        greetingReading.apply(.reading)
        dateLabel.apply(.meaning)
        partOfDay.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        partOfDay.tintColor = Design.Color.warning
        partOfDay.setContentHuggingPriority(.required, for: .horizontal)
        partOfDay.isAccessibilityElement = false
        let texts = UIStackView(arrangedSubviews: [greeting, greetingReading, dateLabel])
        texts.axis = .vertical
        texts.spacing = 2
        let row = UIStackView(arrangedSubviews: [tile, texts, partOfDay])
        row.alignment = .center
        row.spacing = Design.Spacing.m
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .header
        accessibilityIdentifier = "today_date_header"
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ header: TodayDateHeader, monthNumber: Int) {
        month.text = "\(monthNumber)月"
        greeting.text = header.greeting
        greetingReading.text = header.greeting == header.greetingReading ? nil : header.greetingReading
        greetingReading.isHidden = header.greeting == header.greetingReading
        dateLabel.text = "\(header.dateText) · \(header.eraText)"
        partOfDay.image = UIImage(systemName: header.symbol)
        accessibilityLabel = header.accessibilityLabel
        if shownDay != header.day {
            let first = shownDay == 0
            shownDay = header.day
            day.format = { "\($0)" }
            day.setValue(header.day, animated: true)
            if !UIAccessibility.isReduceMotionEnabled, first {
                var transform = CATransform3DIdentity
                transform.m34 = -1 / 400
                tile.layer.transform = transform
                let flip = CASpringAnimation(keyPath: "transform.rotation.x")
                flip.fromValue = -Double.pi / 2.2
                flip.toValue = 0
                flip.damping = 11
                flip.duration = flip.settlingDuration
                tile.layer.add(flip, forKey: "flip")
            }
        }
        partOfDay.removeAllSymbolEffects()
        if !UIAccessibility.isReduceMotionEnabled { partOfDay.addSymbolEffect(.variableColor.iterative.reversing, options: .repeating) }
    }
}

/// The whole hub: the date header, the city, and the cards in a paged strip the learner scrolls by hand (never on its own).
final class TodayLifeHubView: UIView, UIScrollViewDelegate {
    var onCardAction: ((String) -> Void)?
    var onChangeCity: (() -> Void)?

    private let header = TodayDateHeaderView()
    private let titleLabel = UILabel()
    private let cityButton = UIButton(type: .system)
    private let scroll = UIScrollView()
    private let strip = UIStackView()
    private let pages = UIPageControl()
    private var views: [String: LifeTopicCardView] = [:]
    private var order: [String] = []
    private var introduced = Set<String>()
    private let selection = UISelectionFeedbackGenerator()
    private var lastPage = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.apply(.eyebrow)
        titleLabel.text = NSLocalizedString("LEARN FROM LIFE", comment: "Section label on Today")
        titleLabel.accessibilityTraits = .header
        var city = UIButton.Configuration.plain()
        city.image = UIImage(systemName: "mappin.and.ellipse")
        city.imagePadding = Design.Spacing.xs
        city.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 0)
        cityButton.configuration = city
        cityButton.accessibilityIdentifier = "today_life_city"
        cityButton.addAction(UIAction { [weak self] _ in self?.onChangeCity?() }, for: .primaryActionTriggered)
        cityButton.setContentHuggingPriority(.required, for: .horizontal)
        let bar = UIStackView(arrangedSubviews: [titleLabel, cityButton])
        bar.alignment = .center

        scroll.showsHorizontalScrollIndicator = false
        scroll.delegate = self
        scroll.clipsToBounds = false
        scroll.decelerationRate = .fast
        scroll.accessibilityIdentifier = "today_life_cards"
        strip.axis = .horizontal
        strip.spacing = Design.Spacing.m
        strip.alignment = .fill
        strip.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(strip)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        pages.currentPageIndicatorTintColor = Design.Color.accent
        pages.pageIndicatorTintColor = Design.Color.separator
        pages.isUserInteractionEnabled = false
        pages.isAccessibilityElement = false

        let column = UIStackView(arrangedSubviews: [header, bar, scroll, pages])
        column.axis = .vertical
        column.spacing = Design.Spacing.s
        column.setCustomSpacing(Design.Spacing.l, after: header)
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            strip.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            strip.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            strip.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            scroll.heightAnchor.constraint(equalTo: strip.heightAnchor)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var cardWidth: CGFloat { max(240, min(bounds.width - 40, 360)) }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The cards follow the width the hub really has (it is not known when they are made).
        for view in views.values where view.widthConstraint?.constant != cardWidth { view.widthConstraint?.constant = cardWidth }
    }

    func configure(_ section: TodayHubSection, monthNumber: Int) {
        header.configure(section.header, monthNumber: monthNumber)
        var config = cityButton.configuration
        config?.title = section.cityName
        config?.baseForegroundColor = Design.Color.accent
        cityButton.configuration = config
        cityButton.accessibilityLabel = String(format: NSLocalizedString("City: %@. Change", comment: "Accessibility label of the city button"), section.cityName)

        let ids = section.cards.map(\.id)
        if ids != order {
            // Views are reused by id, so a card that did not change does not flicker; new ones are introduced with motion.
            let removed = Set(order).subtracting(ids)
            removed.forEach { views[$0]?.removeFromSuperview(); views[$0] = nil }
            order = ids
            for card in section.cards where views[card.id] == nil {
                let view = LifeTopicCardView()
                view.onAction = { [weak self] id in self?.onCardAction?(id) }
                let width = view.widthAnchor.constraint(equalToConstant: cardWidth)
                width.isActive = true
                view.widthConstraint = width
                views[card.id] = view
            }
            strip.arrangedSubviews.forEach { strip.removeArrangedSubview($0) }
            for id in ids { if let view = views[id] { strip.addArrangedSubview(view) } }
        }
        for card in section.cards { views[card.id]?.configure(card) }
        pages.numberOfPages = ids.count
        pages.currentPage = min(lastPage, max(ids.count - 1, 0))
        pages.isHidden = ids.count < 2
        introduceNewCards(section.cards)
    }

    private func introduceNewCards(_ cards: [LifeFeedCard]) {
        let fresh = cards.filter { introduced.insert($0.id).inserted }
        guard !fresh.isEmpty else { return }
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        for (index, card) in fresh.enumerated() {
            guard let view = views[card.id] else { continue }
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 36, y: 14).scaledBy(x: 0.94, y: 0.94)
            UIView.animate(withDuration: 0.7, delay: 0.08 * Double(index), usingSpringWithDamping: 0.78, initialSpringVelocity: 0.4, options: [.allowUserInteraction]) {
                view.alpha = 1
                view.transform = .identity
            } completion: { [weak self] _ in self?.applyParallax() }
        }
    }

    // MARK: Paging and depth

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        applyParallax()
        let page = currentPage(for: scrollView.contentOffset.x)
        if page != lastPage {
            lastPage = page
            pages.currentPage = page
            selection.selectionChanged()
        }
    }

    private func currentPage(for offset: CGFloat) -> Int {
        let step = cardWidth + Design.Spacing.m
        return max(0, min(Int((offset / step).rounded()), max(order.count - 1, 0)))
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let step = cardWidth + Design.Spacing.m
        var page = (targetContentOffset.pointee.x / step).rounded()
        if abs(velocity.x) > 0.3 { page = (scrollView.contentOffset.x / step) + (velocity.x > 0 ? 0.6 : -0.6); page = page.rounded() }
        page = max(0, min(page, CGFloat(max(order.count - 1, 0))))
        targetContentOffset.pointee.x = min(page * step, max(0, scrollView.contentSize.width - scrollView.bounds.width))
    }

    /// Cards shrink and fade a little as they leave the left edge: depth without a rendering cost.
    private func applyParallax() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let step = cardWidth + Design.Spacing.m
        for (index, id) in order.enumerated() {
            guard let view = views[id], view.alpha > 0.05 else { continue }
            let distance = min(1, abs(scroll.contentOffset.x - CGFloat(index) * step) / step)
            let scale = 1 - 0.05 * distance
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
            view.alpha = 1 - 0.2 * distance
        }
    }
}
