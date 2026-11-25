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
    private let inlineBadge = UILabel()
    private let inlineBadgeBox = UIView()
    private let inlineBadgeRow = UIStackView()
    private let eyebrow = UILabel()
    private let headline = UILabel()
    private let reading = UILabel()
    private let summary = UILabel()
    private let chips = UIStackView()
    private let bottomSpacer = UIView()
    private let meta = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let sheen = CAGradientLayer()
    private let button = UIButton(configuration: Design.Button.primary(title: " "))
    private let content = UIStackView()
    private var sceneHeightConstraint: NSLayoutConstraint!
    private var card: LifeFeedCard?

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyCardSurface(radius: Design.Radius.card)
        clipsToBounds = true

        scene.translatesAutoresizingMaskIntoConstraints = false
        for (lbl, box) in [(badge, badgeBox), (inlineBadge, inlineBadgeBox)] {
            lbl.apply(.eyebrow)
            lbl.translatesAutoresizingMaskIntoConstraints = false
            box.layer.cornerRadius = Design.Radius.badge
            box.layer.cornerCurve = .continuous
            box.translatesAutoresizingMaskIntoConstraints = false
            box.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.topAnchor.constraint(equalTo: box.topAnchor, constant: 4),
                lbl.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -4),
                lbl.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: Design.Spacing.s),
                lbl.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -Design.Spacing.s)
            ])
        }
        inlineBadgeRow.axis = .horizontal
        inlineBadgeRow.addArrangedSubview(inlineBadgeBox)
        inlineBadgeRow.addArrangedSubview(UIView())
        inlineBadgeRow.isHidden = true

        eyebrow.apply(.eyebrow)
        headline.apply(.headword)
        headline.font = Design.TextRole.weighted(.title2, weight: .semibold)
        reading.apply(.reading)
        summary.apply(.meaning)
        summary.numberOfLines = 2
        meta.apply(.metadata)
        meta.numberOfLines = 1
        meta.lineBreakMode = .byTruncatingTail
        chips.axis = .horizontal
        chips.distribution = .fillProportionally
        chips.alignment = .top
        chips.spacing = Design.Spacing.m
        bottomSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        bottomSpacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        spinner.hidesWhenStopped = true
        sheen.colors = [UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.55).cgColor, UIColor.clear.cgColor]
        sheen.startPoint = CGPoint(x: 0, y: 0.5)
        sheen.endPoint = CGPoint(x: 1, y: 0.5)
        sheen.isHidden = true
        layer.addSublayer(sheen)

        button.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        button.enableAdaptiveCornerStyle()
        button.addAction(UIAction { [weak self] _ in self?.fire() }, for: .primaryActionTriggered)
        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        addGestureRecognizer(tap)

        content.axis = .vertical
        content.spacing = Design.Spacing.xs
        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = UIEdgeInsets(top: Design.Spacing.m, left: Design.Spacing.l, bottom: Design.Spacing.l, right: Design.Spacing.l)
        [inlineBadgeRow, eyebrow, headline, reading, summary, chips, spinner, bottomSpacer, meta, button].forEach(content.addArrangedSubview)
        content.setCustomSpacing(Design.Spacing.s, after: inlineBadgeRow)
        content.setCustomSpacing(Design.Spacing.s, after: summary)
        content.setCustomSpacing(Design.Spacing.s, after: meta)
        let column = UIStackView(arrangedSubviews: [scene, content])
        column.axis = .vertical
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        addSubview(badgeBox)
        sceneHeightConstraint = scene.heightAnchor.constraint(equalToConstant: 120)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            sceneHeightConstraint,
            badgeBox.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            badgeBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.m),
            badgeBox.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Design.Spacing.m)
        ])
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: LifeTopicCardView, _) in
            view.updateDensity()
        }
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
        let badgeCopy = Self.badgeText(card.provenance)
        let tint = card.provenance == .sample ? Design.Color.warning : card.provenance == .live ? Design.Color.success : Design.Color.accent
        badge.text = badgeCopy
        badge.textColor = tint
        badgeBox.backgroundColor = Design.Color.surface.withAlphaComponent(0.92)
        inlineBadge.text = badgeCopy
        inlineBadge.textColor = tint
        inlineBadgeBox.backgroundColor = Design.Color.statusFill(tint)
        updateDensity()
        eyebrow.text = card.eyebrow
        headline.text = card.headlineJapanese
        reading.text = card.reading
        reading.isHidden = card.reading.isEmpty
        summary.text = card.summary
        meta.text = card.meta
        meta.isHidden = card.meta.isEmpty
        chips.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for chip in card.chips.prefix(2) { chips.addArrangedSubview(chipRow(chip)) }
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
            configuration = Design.Button.primary(title: card.ctaTitle, traits: traitCollection)
            configuration.image = UIImage(systemName: "arrow.right")
        case .needsLocation:
            configuration = Design.Button.primary(title: card.ctaTitle, traits: traitCollection)
            configuration.image = UIImage(systemName: "location.fill")
        case .failed, .locationDenied:
            configuration = Design.Button.secondary(title: card.ctaTitle, traits: traitCollection)
        case .loading, .locating:
            configuration = Design.Button.primary(title: " ", traits: traitCollection)
        }
        configuration.imagePlacement = .trailing
        configuration.imagePadding = Design.Spacing.s
        button.configuration = configuration
        button.accessibilityIdentifier = "life_card_action_\(card.id)"
        updateActions()
        accessibilityIdentifier = "life_card_\(card.id)"

        let facts = card.chips.map(\.text).joined(separator: ", ")
        headline.accessibilityLabel = [card.eyebrow.capitalized, card.headlineJapanese, card.summary, facts, card.meta].filter { !$0.isEmpty }.joined(separator: ". ")
        [eyebrow, reading, summary, meta, chips, badgeBox, inlineBadgeRow].forEach { $0.isAccessibilityElement = false }
        headline.isAccessibilityElement = true
        headline.accessibilityTraits = card.status == .ready ? .button : .staticText
        headline.accessibilityHint = card.status == .ready ? card.ctaTitle : nil
        updateActions()
    }

    /// A ready lesson is opened by a tap on the whole card, so it needs no button of its own (VoiceOver: the headline, with the action as
    /// its hint). A card that waits for its data or a location shows a labelled button, which is hidden while the card is busy.
    private func updateActions() {
        guard let card else { return }
        let busy = card.status == .loading || card.status == .locating
        button.isHidden = busy || card.status == .ready || card.ctaTitle.isEmpty
        accessibilityElements = [headline] + (button.isHidden ? [] : [button])
    }

    /// Keep the default card compact, but never trade away readable content at accessibility text sizes.
    private func updateDensity() {
        let accessibilityText = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        chips.axis = accessibilityText ? .vertical : .horizontal
        chips.distribution = accessibilityText ? .fill : .fillProportionally
        chips.spacing = accessibilityText ? Design.Spacing.xs : Design.Spacing.m
        badgeBox.isHidden = accessibilityText
        inlineBadgeRow.isHidden = !accessibilityText
        updateActions()
        summary.numberOfLines = accessibilityText ? 0 : 2
        meta.numberOfLines = accessibilityText ? 0 : 1
        meta.lineBreakMode = accessibilityText ? .byWordWrapping : .byTruncatingTail
        content.layoutMargins.top = Design.Spacing.m
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
    private let row = UIStackView()
    private let texts = UIStackView()
    private let compactHeader = UIStackView()
    private let compactSpacer = UIView()
    private var shownDay = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        tile.applyCardSurface(radius: Design.Radius.control)
        tile.translatesAutoresizingMaskIntoConstraints = false
        let strip = UIView()
        strip.backgroundColor = Design.Color.hero
        strip.translatesAutoresizingMaskIntoConstraints = false
        month.font = Design.TextRole.weighted(.caption2, weight: .bold, maximum: 16)
        month.adjustsFontForContentSizeCategory = true
        month.textColor = Design.Color.onHero
        month.textAlignment = .center
        month.translatesAutoresizingMaskIntoConstraints = false
        day.font = Design.TextRole.mincho(size: 30, style: .title1, maximum: 40)
        day.adjustsFontForContentSizeCategory = true
        day.textColor = Design.Color.textPrimary
        day.textAlignment = .center
        day.adjustsFontSizeToFitWidth = true
        day.minimumScaleFactor = 0.6
        day.translatesAutoresizingMaskIntoConstraints = false
        [strip, month, day].forEach(tile.addSubview)
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: 56),
            tile.heightAnchor.constraint(equalToConstant: 64),
            strip.topAnchor.constraint(equalTo: tile.topAnchor),
            strip.leadingAnchor.constraint(equalTo: tile.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: tile.trailingAnchor),
            strip.heightAnchor.constraint(equalToConstant: 20),
            month.centerYAnchor.constraint(equalTo: strip.centerYAnchor),
            month.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 2),
            month.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -2),
            day.topAnchor.constraint(equalTo: strip.bottomAnchor, constant: 2),
            day.bottomAnchor.constraint(equalTo: tile.bottomAnchor, constant: -4),
            day.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 4),
            day.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -4)
        ])
        tile.clipsToBounds = true

        greeting.apply(.headword)
        greeting.font = Design.TextRole.weighted(.title2, weight: .semibold)
        greetingReading.apply(.reading)
        dateLabel.apply(.meaning)
        partOfDay.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        partOfDay.tintColor = Design.Color.warning
        partOfDay.setContentHuggingPriority(.required, for: .horizontal)
        partOfDay.isAccessibilityElement = false

        texts.axis = .vertical
        texts.spacing = 2
        [greeting, greetingReading, dateLabel].forEach(texts.addArrangedSubview)

        compactHeader.axis = .horizontal
        compactHeader.alignment = .center
        compactHeader.spacing = Design.Spacing.m

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
        applyLayout()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TodayDateHeaderView, _) in
            view.applyLayout()
        }
    }

    private func applyLayout() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        row.arrangedSubviews.forEach { row.removeArrangedSubview($0); $0.removeFromSuperview() }
        compactHeader.arrangedSubviews.forEach { compactHeader.removeArrangedSubview($0); $0.removeFromSuperview() }
        if isAX {
            row.axis = .vertical
            row.alignment = .fill
            [tile, compactSpacer, partOfDay].forEach(compactHeader.addArrangedSubview)
            [compactHeader, texts].forEach(row.addArrangedSubview)
        } else {
            row.axis = .horizontal
            row.alignment = .center
            [tile, texts, partOfDay].forEach(row.addArrangedSubview)
        }
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

/// The life hub: the city and cards in a paged strip the learner scrolls by hand (never on its own).
final class TodayLifeHubView: UIView, UIScrollViewDelegate {
    var onCardAction: ((String) -> Void)?
    var onChangeCity: (() -> Void)?

    private let titleLabel = UILabel()
    private let cityButton = UIButton(type: .system)
    private let headerBar = UIStackView()
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
        titleLabel.text = NSLocalizedString("TODAY IN JAPAN", comment: "Section label on Today")
        titleLabel.accessibilityTraits = .header
        var city = UIButton.Configuration.plain()
        city.image = UIImage(systemName: "mappin.and.ellipse")
        city.imagePadding = Design.Spacing.xs
        city.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.s, leading: Design.Spacing.s, bottom: Design.Spacing.s, trailing: 0)
        cityButton.configuration = city
        cityButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        cityButton.accessibilityIdentifier = "today_life_city"
        cityButton.addAction(UIAction { [weak self] _ in self?.onChangeCity?() }, for: .primaryActionTriggered)
        cityButton.setContentHuggingPriority(.required, for: .horizontal)
        cityButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        [titleLabel, cityButton].forEach(headerBar.addArrangedSubview)
        headerBar.spacing = Design.Spacing.xs
        updateHeaderBarLayout()

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

        let column = UIStackView(arrangedSubviews: [headerBar, scroll, pages])
        column.axis = .vertical
        column.spacing = Design.Spacing.s
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
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TodayLifeHubView, _) in
            view.updateHeaderBarLayout()
        }
    }

    private func updateHeaderBarLayout() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        headerBar.axis = isAX ? .vertical : .horizontal
        headerBar.alignment = isAX ? .leading : .center
        var config = cityButton.configuration
        config?.contentInsets = isAX
            ? NSDirectionalEdgeInsets(top: Design.Spacing.xs, leading: 0, bottom: Design.Spacing.xs, trailing: Design.Spacing.s)
            : NSDirectionalEdgeInsets(top: Design.Spacing.s, leading: Design.Spacing.s, bottom: Design.Spacing.s, trailing: 0)
        cityButton.configuration = config
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var cardWidth: CGFloat { max(240, min(bounds.width - 40, 360)) }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The cards follow the width the hub really has (it is not known when they are made).
        for view in views.values where view.widthConstraint?.constant != cardWidth { view.widthConstraint?.constant = cardWidth }
    }

    func configure(_ section: TodayHubSection) {
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
