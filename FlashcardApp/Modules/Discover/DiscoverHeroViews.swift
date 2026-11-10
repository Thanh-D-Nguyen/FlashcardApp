import UIKit

//  The top of the Discover tab: an indigo "expedition" block with drifting light, the time left to the next Loto draw and a
//  sealed card that holds one word from today's Magazine. The word comes from the server; when it cannot be read the card is
//  not shown (nothing is made up). Motion is skipped under Reduce Motion.

/// Drifting specks of light. Decorative.
final class DiscoverStarfieldView: UIView {
    private let emitter = CAEmitterLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        layer.addSublayer(emitter)
        emitter.renderMode = .additive
        emitter.emitterShape = .line
        emitter.emitterCells = [Self.cell(color: LotoPalette.gold, scale: 0.05, velocity: 14, birth: 5),
                                Self.cell(color: .white, scale: 0.03, velocity: 8, birth: 7)]
        // Under Reduce Motion the specks are not emitted at all.
        emitter.birthRate = UIAccessibility.isReduceMotionEnabled ? 0 : 1
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private static func cell(color: UIColor, scale: CGFloat, velocity: CGFloat, birth: Float) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = dot.cgImage
        cell.birthRate = birth
        cell.lifetime = 9
        cell.velocity = velocity
        cell.velocityRange = velocity / 2
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = .pi / 5
        cell.scale = scale
        cell.scaleRange = scale / 2
        cell.alphaSpeed = -0.1
        cell.alphaRange = 0.4
        cell.color = color.withAlphaComponent(0.85).cgColor
        return cell
    }

    private static let dot: UIImage = {
        UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 32, height: 32))
        }
    }()

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.maxY + 4)
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
    }
}

/// The sealed card: tap to break the seal, it turns over and shows today's word; tap again to read the article.
final class DiscoverFindCard: UIControl {
    private let sealedFace = UIView()
    private let openFace = UIView()
    private let wordLabel = UILabel()
    private let articleLabel = UILabel()
    private let shimmer = CAGradientLayer()
    private(set) var isRevealed = false

    init() {
        super.init(frame: .zero)
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        buildSealedFace()
        buildOpenFace()
        for face in [sealedFace, openFace] {
            face.isUserInteractionEnabled = false
            face.translatesAutoresizingMaskIntoConstraints = false
            addSubview(face)
            NSLayoutConstraint.activate([face.topAnchor.constraint(equalTo: topAnchor), face.bottomAnchor.constraint(equalTo: bottomAnchor),
                                         face.leadingAnchor.constraint(equalTo: leadingAnchor), face.trailingAnchor.constraint(equalTo: trailingAnchor)])
        }
        openFace.isHidden = true
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "discover_find"
        accessibilityLabel = NSLocalizedString("Today's find", comment: "Discover: the sealed card")
        accessibilityHint = NSLocalizedString("Sealed card. Double tap to reveal today's find.", comment: "VoiceOver hint of the sealed card")
        addAction(UIAction { [weak self] _ in self?.tapped() }, for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(word: String, article: String) {
        wordLabel.text = word
        articleLabel.text = article
    }

    private func buildSealedFace() {
        sealedFace.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        sealedFace.layer.borderWidth = 1.5
        sealedFace.layer.borderColor = LotoPalette.gold.withAlphaComponent(0.7).cgColor
        sealedFace.layer.cornerRadius = 20
        sealedFace.layer.cornerCurve = .continuous
        let icon = UIImageView(image: UIImage(systemName: "sparkles"))
        icon.tintColor = LotoPalette.gold
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title2, scale: .large)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let title = UILabel()
        title.apply(.title)
        title.textColor = Design.Color.onHero
        title.text = NSLocalizedString("Today's find", comment: "Discover: the sealed card")
        let hint = UILabel()
        hint.apply(.metadata)
        hint.textColor = LotoPalette.gold
        hint.text = NSLocalizedString("Tap to break the seal", comment: "Discover: the sealed card")
        let text = UIStackView(arrangedSubviews: [title, hint])
        text.axis = .vertical
        text.spacing = 2
        let seal = UILabel()
        seal.text = "封"
        seal.font = UIFont(name: "HiraMinProN-W6", size: 22) ?? .systemFont(ofSize: 22, weight: .bold)
        seal.textColor = Design.Color.hero
        seal.textAlignment = .center
        seal.backgroundColor = LotoPalette.gold
        seal.layer.cornerRadius = 20
        seal.layer.masksToBounds = true
        seal.widthAnchor.constraint(equalToConstant: 40).isActive = true
        seal.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let row = UIStackView(arrangedSubviews: [icon, text, UIView(), seal])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Design.Spacing.m
        row.translatesAutoresizingMaskIntoConstraints = false
        sealedFace.addSubview(row)
        pin(row, in: sealedFace)
        shimmer.colors = [UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.28).cgColor, UIColor.clear.cgColor]
        shimmer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmer.locations = [0, 0.5, 1]
        sealedFace.layer.addSublayer(shimmer)
    }

    private func buildOpenFace() {
        openFace.backgroundColor = Design.Color.onHero
        wordLabel.apply(.entryHeadword)
        wordLabel.textColor = Design.Color.hero
        wordLabel.adjustsFontSizeToFitWidth = true
        wordLabel.minimumScaleFactor = 0.5
        wordLabel.numberOfLines = 2
        articleLabel.apply(.reading)
        articleLabel.textColor = Design.Color.hero.withAlphaComponent(0.75)
        articleLabel.numberOfLines = 2
        let stack = UIStackView(arrangedSubviews: [wordLabel, articleLabel])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        openFace.addSubview(stack)
        pin(stack, in: openFace)
    }

    private func pin(_ view: UIView, in container: UIView) {
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: Design.Spacing.l),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Design.Spacing.l),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Design.Spacing.l),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Design.Spacing.l)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shimmer.frame = CGRect(x: -bounds.width, y: 0, width: bounds.width * 3, height: bounds.height)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !isRevealed, !UIAccessibility.isReduceMotionEnabled else { return }
        let sweep = CABasicAnimation(keyPath: "transform.translation.x")
        sweep.fromValue = -bounds.width
        sweep.toValue = bounds.width
        sweep.duration = 2.4
        sweep.repeatCount = .infinity
        shimmer.add(sweep, forKey: "sweep")
    }

    private func tapped() {
        reveal()
    }

    /// Breaks the seal. Public so the launch argument and tests can open it without a touch.
    func reveal() {
        guard !isRevealed else { return }
        isRevealed = true
        shimmer.removeAllAnimations()
        accessibilityLabel = wordLabel.text
        accessibilityValue = articleLabel.text
        accessibilityHint = nil
        accessibilityTraits = .staticText
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let swap = { [self] in sealedFace.isHidden = true; openFace.isHidden = false }
        guard !UIAccessibility.isReduceMotionEnabled else { swap(); return }
        UIView.transition(with: self, duration: 0.6, options: [.transitionFlipFromRight, .curveEaseInOut], animations: swap)
        burst()
    }

    /// A short fountain of gold from the middle of the card.
    private func burst() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emitter.emitterShape = .point
        emitter.renderMode = .additive
        let cell = CAEmitterCell()
        cell.contents = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 16, height: 16))
        }.cgImage
        cell.birthRate = 160
        cell.lifetime = 1.2
        cell.velocity = 150
        cell.velocityRange = 80
        cell.emissionRange = .pi * 2
        cell.scale = 0.35
        cell.scaleRange = 0.2
        cell.alphaSpeed = -0.9
        cell.yAcceleration = 120
        cell.color = LotoPalette.gold.cgColor
        emitter.emitterCells = [cell]
        emitter.zPosition = 10
        layer.masksToBounds = false
        layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            emitter.removeFromSuperlayer()
            self?.layer.masksToBounds = true
        }
    }

    override var isHighlighted: Bool {
        didSet {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            UIView.animate(withDuration: 0.18, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: [.allowUserInteraction]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}

/// The expedition block at the top of the hub.
final class DiscoverHeroView: UIView {
    private let gradient = CAGradientLayer()
    private let starfield = DiscoverStarfieldView()
    private let watermark = UILabel()
    private let eyebrow = UILabel()
    private let headline = UILabel()
    let findCard = DiscoverFindCard()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 28
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradient, at: 0)
        starfield.translatesAutoresizingMaskIntoConstraints = false
        addSubview(starfield)

        watermark.text = "探検"
        watermark.font = UIFont(name: "HiraMinProN-W6", size: 96) ?? .systemFont(ofSize: 96, weight: .bold)
        watermark.textColor = LotoPalette.gold.withAlphaComponent(0.16)
        watermark.isAccessibilityElement = false
        watermark.translatesAutoresizingMaskIntoConstraints = false
        addSubview(watermark)

        eyebrow.apply(.eyebrow)
        eyebrow.textColor = LotoPalette.gold
        eyebrow.text = NSLocalizedString("Today's expedition", comment: "Discover: hero eyebrow").uppercased() + " · 探検"
        headline.apply(.display)
        headline.textColor = Design.Color.onHero
        headline.numberOfLines = 0
        headline.text = NSLocalizedString("Every day hides something new", comment: "Discover: hero headline")
        headline.accessibilityTraits = .header

        findCard.isHidden = true
        let stack = UIStackView(arrangedSubviews: [eyebrow, headline, findCard])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.s
        stack.setCustomSpacing(Design.Spacing.l, after: headline)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.xl),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.l),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.l),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.l),
            starfield.topAnchor.constraint(equalTo: topAnchor), starfield.bottomAnchor.constraint(equalTo: bottomAnchor),
            starfield.leadingAnchor.constraint(equalTo: leadingAnchor), starfield.trailingAnchor.constraint(equalTo: trailingAnchor),
            watermark.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.m),
            watermark.topAnchor.constraint(equalTo: topAnchor, constant: -8)
        ])
        applyColors()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: DiscoverHeroView, _) in view.applyColors() }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func applyColors() {
        gradient.colors = [Design.Color.hero.resolvedColor(with: traitCollection).cgColor, LotoPalette.rgb(0x142548).cgColor]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    func show(find: DiscoverFind?, animated: Bool) {
        guard let find else { findCard.isHidden = true; return }
        findCard.configure(word: find.word, article: find.articleJapanese)
        guard findCard.isHidden else { return }
        findCard.isHidden = false
        guard animated, !UIAccessibility.isReduceMotionEnabled else { return }
        findCard.alpha = 0
        findCard.transform = CGAffineTransform(translationX: 0, y: 18)
        UIView.animate(withDuration: 0.6, delay: 0.1, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.4) {
            self.findCard.alpha = 1
            self.findCard.transform = .identity
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startBreathing() }
    }

    /// The headline's watermark slowly breathes, so the block is never quite still.
    private func startBreathing() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let breathe = CABasicAnimation(keyPath: "opacity")
        breathe.fromValue = 0.55
        breathe.toValue = 1
        breathe.duration = 3
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        watermark.layer.add(breathe, forKey: "breathe")
    }
}
