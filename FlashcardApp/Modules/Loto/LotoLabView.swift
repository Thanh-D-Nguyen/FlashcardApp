import UIKit

// MARK: Drum

/// A glass drum with balls tumbling inside. Gravity and collisions come from UIKit Dynamics; a spin sweeps the gravity round
/// the drum and shakes the balls. Under Reduce Motion the balls rest in place and a spin only waits.
final class LotoDrumView: UIView {
    private static let ballDiameter: CGFloat = 26
    private static let ballCount = 16

    private let sphere = UIView()
    private let shine = CAGradientLayer()
    private let glow = CALayer()
    private lazy var animator = UIDynamicAnimator(referenceView: sphere)
    private let gravity = UIGravityBehavior()
    private let collision = UICollisionBehavior()
    private let material = UIDynamicItemBehavior()
    private var balls: [LotoBallView] = []
    private let poolSize: Int
    private var link: CADisplayLink?
    private var spinStart: CFTimeInterval = 0
    private var spinning = false

    init(poolSize: Int) {
        self.poolSize = poolSize
        super.init(frame: .zero)
        sphere.layer.masksToBounds = false
        sphere.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        sphere.layer.borderWidth = 2
        sphere.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        sphere.layer.shadowColor = LotoPalette.gold.cgColor
        sphere.layer.shadowOffset = .zero
        sphere.layer.shadowRadius = 18
        sphere.layer.shadowOpacity = 0
        addSubview(sphere)

        shine.type = .radial
        shine.colors = [UIColor.white.withAlphaComponent(0.28).cgColor, UIColor.white.withAlphaComponent(0).cgColor]
        shine.startPoint = CGPoint(x: 0.3, y: 0.22)
        shine.endPoint = CGPoint(x: 1, y: 1)
        shine.isHidden = true
        sphere.layer.addSublayer(shine)

        gravity.gravityDirection = CGVector(dx: 0, dy: 1)
        collision.collisionMode = .everything
        material.elasticity = 0.82
        material.friction = 0.05
        material.density = 1
        material.allowsRotation = true
        isAccessibilityElement = false
        accessibilityElementsHidden = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 224) }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        guard side > 0 else { return }
        let frame = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        guard sphere.frame != frame else { return }
        sphere.frame = frame
        sphere.layer.cornerRadius = side / 2
        shine.frame = sphere.bounds
        shine.cornerRadius = side / 2
        shine.isHidden = false
        rebuildBoundary()
        if balls.isEmpty { populate() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopSpinning()
            animator.removeAllBehaviors()
        } else {
            attachBehaviors()
        }
    }

    deinit { link?.invalidate() }

    /// Centre of the drum in `view`'s coordinates.
    func center(in view: UIView) -> CGPoint { sphere.convert(CGPoint(x: sphere.bounds.midX, y: sphere.bounds.midY), to: view) }

    /// Where the balls are right now, as a factor of the chaos system. nil under Reduce Motion: the balls are then not moving,
    /// so their places say nothing.
    func restingFactor() -> LotoChaosFactor? {
        guard !UIAccessibility.isReduceMotionEnabled, !balls.isEmpty else { return nil }
        let places = balls.sorted { $0.number < $1.number }.map { String(format: "%d:%.2f,%.2f", $0.number, $0.center.x, $0.center.y) }
        return LotoChaosFactor(kind: .drum, key: "drum", value: places.joined(separator: ";"),
                               display: String(format: NSLocalizedString("%d balls at their places in the drum", comment: "Loto chaos: drum summary"), balls.count))
    }

    /// 0…1: how strongly the drum glows. Full at pure randomness.
    func setGlow(_ level: CGFloat) {
        sphere.layer.shadowOpacity = Float(0.9 * level)
        sphere.layer.borderColor = (level >= 1 ? LotoPalette.gold : UIColor.white.withAlphaComponent(0.35)).cgColor
    }

    // MARK: Spinning

    func startSpinning() {
        guard !spinning else { return }
        spinning = true
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        spinStart = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stopSpinning() {
        spinning = false
        link?.invalidate()
        link = nil
        gravity.gravityDirection = CGVector(dx: 0, dy: 1)
    }

    @objc private func step() {
        let elapsed = CACurrentMediaTime() - spinStart
        // The gravity turns round the drum, faster as the spin goes on, so the balls are carried up the wall and fall back.
        let angle = elapsed * (7 + elapsed * 2)
        gravity.gravityDirection = CGVector(dx: cos(angle) * 2.4, dy: sin(angle) * 2.4)
        guard let ball = balls.randomElement() else { return }
        let push = UIPushBehavior(items: [ball], mode: .instantaneous)
        push.pushDirection = CGVector(dx: CGFloat.random(in: -0.12...0.12), dy: CGFloat.random(in: -0.12...0.12))
        animator.addBehavior(push)
        // The push is spent at once; removing it keeps the animator from collecting one behaviour per frame.
        DispatchQueue.main.async { [weak animator, weak push] in if let animator, let push { animator.removeBehavior(push) } }
    }

    // MARK: Private

    private func populate() {
        let radius = sphere.bounds.width / 2
        let numbers = Array(1...poolSize).shuffled().prefix(Self.ballCount)
        for (index, number) in numbers.enumerated() {
            let ball = LotoBallView(number: number, tag: nil, diameter: Self.ballDiameter)
            ball.isAccessibilityElement = false
            // Spread on rings so none start on top of another.
            let ring = CGFloat(index % 3 + 1) / 3.6
            let angle = Double(index) * 2.399
            ball.center = CGPoint(x: radius + cos(angle) * radius * ring, y: radius + sin(angle) * radius * ring)
            sphere.addSubview(ball)
            balls.append(ball)
        }
        attachBehaviors()
    }

    private func rebuildBoundary() {
        collision.removeBoundary(withIdentifier: "drum" as NSString)
        collision.addBoundary(withIdentifier: "drum" as NSString, for: UIBezierPath(ovalIn: sphere.bounds.insetBy(dx: 2, dy: 2)))
    }

    private func attachBehaviors() {
        guard !balls.isEmpty, window != nil, !UIAccessibility.isReduceMotionEnabled else { return }
        animator.removeAllBehaviors()
        for ball in balls {
            gravity.addItem(ball)
            collision.addItem(ball)
            material.addItem(ball)
        }
        animator.addBehavior(gravity)
        animator.addBehavior(collision)
        animator.addBehavior(material)
    }
}

// MARK: Weight strip

/// One bar per number showing its weight. The bars flatten as randomness rises and turn gold when they are all equal.
final class LotoWeightStripView: UIView {
    private static let height: CGFloat = 56
    private let bars: [UIView]
    private let colors: [UIColor]
    private var weights: [Double]
    private var uniform = false

    init(game: LotoGame, signals: LotoSignals, weights: [Double]) {
        self.weights = weights
        self.colors = (1...game.poolSize).map { number in signals.tag(of: number)?.ballColor.withAlphaComponent(1) ?? UIColor.white.withAlphaComponent(0.4) }
        self.bars = (1...game.poolSize).map { _ in
            let bar = UIView()
            bar.layer.cornerRadius = 2
            bar.layer.cornerCurve = .continuous
            return bar
        }
        super.init(frame: .zero)
        bars.forEach(addSubview)
        isAccessibilityElement = true
        accessibilityTraits = .image
        set(weights: weights, animated: false)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: Self.height) }

    override func layoutSubviews() {
        super.layoutSubviews()
        place(animated: false)
    }

    func set(weights: [Double], animated: Bool) {
        guard weights.count == bars.count else { return }
        self.weights = weights
        uniform = LotoRandomizer.isUniform(weights)
        accessibilityLabel = String(format: NSLocalizedString("Weight of each number, from 1 to %d", comment: "VoiceOver: the weight chart"), bars.count)
            + ". " + (uniform ? NSLocalizedString("Every number has the same weight", comment: "Loto lab: flat weights")
                              : NSLocalizedString("Marked numbers weigh more", comment: "Loto lab: uneven weights"))
        place(animated: animated)
    }

    private func place(animated: Bool) {
        guard bounds.width > 0 else { return }
        let gap: CGFloat = 2
        let width = max((bounds.width - gap * CGFloat(bars.count - 1)) / CGFloat(bars.count), 1)
        let apply = {
            for (index, bar) in self.bars.enumerated() {
                let height = max(CGFloat(self.weights[index]) * Self.height, 3)
                bar.frame = CGRect(x: CGFloat(index) * (width + gap), y: Self.height - height, width: width, height: height)
                bar.backgroundColor = self.uniform ? LotoPalette.gold : self.colors[index]
            }
        }
        if animated && !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: apply)
        } else {
            apply()
        }
    }
}

// MARK: Lab

/// The randomness lab: a slider from "lean on statistics" to "pure random", a drum, and sets drawn on the device.
final class LotoLabView: UIView {
    private let game: LotoGame
    private let signals: LotoSignals
    private let provider: LotoPresenterInterface
    private let copyAction: ([Int]) -> Void

    private let gradient = CAGradientLayer()
    private let drum: LotoDrumView
    private let strip: LotoWeightStripView
    private let slider = UISlider()
    private let percent = UILabel()
    private let badge = UILabel()
    private let spinButton = UIButton(type: .system)
    private let tray = LotoFlowView(views: [])
    private let moreStack = UIStackView()
    private var slots: [UIView] = []
    private var lastStep = -1
    private var spinning = false
    private(set) var randomness: Double
    /// Called with the slider's value whenever it changes, so the screen can keep it across a rebuild.
    var onRandomnessChange: ((Double) -> Void)?

    private let motion = LotoMotionSampler()
    private var trail: [Double] = []
    private var tapTime: CFTimeInterval = 0
    /// Called with every spin, so the explanation under the lab can show what went into it.
    var onResult: ((LotoChaosResult) -> Void)?

    private let selection = UISelectionFeedbackGenerator()
    private let impact = UIImpactFeedbackGenerator(style: .rigid)

    init(game: LotoGame, signals: LotoSignals, randomness: Double, presenter: LotoPresenterInterface, onCopy: @escaping ([Int]) -> Void) {
        self.game = game
        self.signals = signals
        self.provider = presenter
        self.copyAction = onCopy
        self.randomness = LotoRandomizer.clamped(randomness)
        self.drum = LotoDrumView(poolSize: game.poolSize)
        self.strip = LotoWeightStripView(game: game, signals: signals, weights: presenter.labWeights(randomness: randomness))
        super.init(frame: .zero)
        layer.cornerRadius = Design.Radius.panel
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        gradient.colors = [Design.Color.heroDeep.cgColor, Design.Color.hero.cgColor]
        gradient.startPoint = CGPoint(x: 0.2, y: 0)
        gradient.endPoint = CGPoint(x: 0.8, y: 1)
        layer.insertSublayer(gradient, at: 0)
        accessibilityIdentifier = "loto_lab"
        build()
        sync(animated: false)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    #if DEBUG
    private var debugSpun = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // `-LotoLabRandomness <0…1>` sets the slider and `-LotoLabSpin <seconds>` spins once after that delay, for screenshots.
        let arguments = ProcessInfo.processInfo.arguments
        guard window != nil, !debugSpun else { return }
        if let index = arguments.firstIndex(of: "-LotoLabRandomness"), index + 1 < arguments.count, let value = Double(arguments[index + 1]) {
            slider.value = Float(value)
            sliderChanged()
        }
        if let index = arguments.firstIndex(of: "-LotoLabSpin"), index + 1 < arguments.count, let delay = Double(arguments[index + 1]) {
            debugSpun = true
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.spinTapped() }
        }
    }
    #endif

    // MARK: Build

    private func text(_ role: Design.TextRole, _ string: String, color: UIColor = Design.Color.onHero) -> UILabel {
        let label = UILabel()
        label.apply(role)
        label.text = string
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func build() {
        let eyebrow = text(.eyebrow, NSLocalizedString("Randomness lab", comment: "Loto lab eyebrow").uppercased(), color: LotoPalette.gold)
        let title = text(.sectionTitle, NSLocalizedString("Push the randomness to the limit", comment: "Loto lab title"), color: Design.Color.onHero)
        title.font = .preferredFont(forTextStyle: .title2).withWeight(.bold)
        let intro = text(.metadata, NSLocalizedString("At 100% every number has the same weight. Lower it to lean on the frequent, rare and overdue numbers of this draw.", comment: "Loto lab intro"),
                         color: Design.Color.onHeroSecondary)

        let name = text(.title, NSLocalizedString("Randomness", comment: "Loto method factor"))
        percent.apply(.heroFigure)
        percent.textColor = LotoPalette.gold
        percent.setContentHuggingPriority(.required, for: .horizontal)
        percent.accessibilityIdentifier = "loto_lab_percent"
        let header = UIStackView(arrangedSubviews: [name, UIView(), percent])
        header.alignment = .lastBaseline

        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = Float(randomness)
        slider.minimumTrackTintColor = LotoPalette.gold
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.25)
        slider.thumbTintColor = .white
        slider.accessibilityIdentifier = "loto_lab_slider"
        slider.accessibilityLabel = NSLocalizedString("Randomness", comment: "Loto method factor")
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        let low = text(.metadata, NSLocalizedString("Lean on statistics", comment: "Loto lab slider end"), color: Design.Color.onHeroSecondary)
        let high = text(.metadata, NSLocalizedString("Pure random", comment: "Loto lab slider end"), color: Design.Color.onHeroSecondary)
        high.textAlignment = .right
        let ends = UIStackView(arrangedSubviews: [low, high])
        ends.distribution = .fillEqually

        badge.apply(.metadata)
        badge.textColor = LotoPalette.gold
        badge.numberOfLines = 0
        badge.text = NSLocalizedString("Pure random: every combination is equally likely", comment: "Loto lab badge at 100%")

        var spin = UIButton.Configuration.filled()
        spin.baseBackgroundColor = LotoPalette.gold
        spin.baseForegroundColor = LotoPalette.rgb(0x2A1D00)
        spin.cornerStyle = .capsule
        spin.buttonSize = .large
        spin.imagePadding = Design.Spacing.s
        spinButton.configuration = spin
        spinButton.accessibilityIdentifier = "loto_lab_spin"
        spinButton.addAction(UIAction { [weak self] _ in self?.spinTapped() }, for: .touchUpInside)

        tray.spacing = Design.Spacing.s
        moreStack.axis = .vertical
        moreStack.spacing = Design.Spacing.s

        let disclaimer = text(.metadata, String(format: NSLocalizedString("No setting changes your chance: every combination is still 1 in %@. This is for exploring probability, not a way to win.", comment: "Loto lab note"),
                                               game.combinations.formatted(.number.locale(AppLanguage.current.locale))), color: Design.Color.onHeroSecondary)

        let stack = UIStackView(arrangedSubviews: [eyebrow, title, intro, drum, header, slider, ends, strip, badge, spinButton, tray, moreStack, disclaimer])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.setCustomSpacing(Design.Spacing.xs, after: eyebrow)
        stack.setCustomSpacing(Design.Spacing.l, after: intro)
        stack.setCustomSpacing(Design.Spacing.xs, after: slider)
        stack.setCustomSpacing(Design.Spacing.l, after: badge)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.xl),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.xl),
            drum.heightAnchor.constraint(equalToConstant: 224),
            strip.heightAnchor.constraint(equalToConstant: 56)
        ])
        tray.isHidden = false
        showEmptySlots()
    }

    // MARK: Slider

    @objc private func sliderChanged() {
        randomness = LotoRandomizer.clamped(Double(slider.value))
        onRandomnessChange?(randomness)
        trail.append(randomness)
        let step = Int((randomness * 20).rounded())
        if step != lastStep {
            lastStep = step
            if randomness >= 1 { impact.impactOccurred(intensity: 1) } else { selection.selectionChanged() }
        }
        sync(animated: true)
    }

    private func sync(animated: Bool) {
        let value = Int((randomness * 100).rounded())
        percent.text = "\(value)%"
        slider.accessibilityValue = "\(value)%"
        let uniform = randomness >= 1
        badge.isHidden = !uniform
        drum.setGlow(uniform ? 1 : CGFloat(randomness) * 0.3)
        strip.set(weights: provider.labWeights(randomness: randomness), animated: animated)
        configureSpinButton()
    }

    private func configureSpinButton() {
        var configuration = spinButton.configuration
        configuration?.title = spinning ? NSLocalizedString("Spinning…", comment: "Loto lab button while spinning")
            : (slots.isEmpty || tray.subviews.contains { $0 is LotoBallView } ? NSLocalizedString("Spin again", comment: "Loto lab button") : NSLocalizedString("Spin the drum", comment: "Loto lab button"))
        configuration?.image = UIImage(systemName: "sparkles")
        spinButton.configuration = configuration
        spinButton.isEnabled = !spinning
    }

    // MARK: Spin

    private func spinTapped() {
        guard !spinning else { return }
        spinning = true
        tapTime = CACurrentMediaTime()
        configureSpinButton()
        showEmptySlots()
        moreStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        motion.start()
        drum.startSpinning()
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let duration: TimeInterval = reduceMotion ? 0.2 : 1.9

        if !reduceMotion {
            var ticks = 0
            let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] timer in
                guard let self, self.spinning else { timer.invalidate(); return }
                ticks += 1
                self.impact.impactOccurred(intensity: CGFloat.random(in: 0.35...0.9))
                if Double(ticks) * 0.08 >= duration { timer.invalidate() }
            }
            RunLoop.main.add(timer, forMode: .common)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            self.drum.stopSpinning()
            // The moment the drum stops is read last: it is different at every spin, down to the nanosecond.
            let result = self.provider.spin(randomness: self.randomness, local: self.localFactors())
            guard let result, let first = result.tickets.first else {
                self.spinning = false
                self.configureSpinButton()
                return
            }
            self.onResult?(result)
            self.reveal(first, others: Array(result.tickets.dropFirst()))
        }
    }

    /// The factors only this device knows at this moment. Anything that cannot be read is left out.
    private func localFactors() -> [LotoChaosFactor] {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS 'JST'"
        var factors = [
            LotoChaosFactor(kind: .moment, key: "moment",
                            value: "epochMs=\(Int64(now.timeIntervalSince1970 * 1000));uptimeNs=\(DispatchTime.now().uptimeNanoseconds)",
                            display: formatter.string(from: now)),
            LotoChaosFactor(kind: .slider, key: "slider", value: "randomness=\(randomness)", display: "\(Int((randomness * 100).rounded()))%"),
            LotoChaosFactor(kind: .touch, key: "touch", value: "tap=\(tapTime.bitPattern);moves=\(trail.count);path=\(trail.suffix(24).map { $0.bitPattern })",
                            display: String(format: NSLocalizedString("%d slider moves, spin pressed at %.3f s", comment: "Loto chaos: touch summary"), trail.count, tapTime))
        ]
        if let motion = motion.stop() { factors.append(motion) }
        if let drum = drum.restingFactor() { factors.append(drum) }
        return factors
    }

    private func showEmptySlots() {
        tray.subviews.forEach { $0.removeFromSuperview() }
        slots = (0..<game.pickCount).map { _ in
            let slot = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            slot.layer.cornerRadius = 22
            slot.layer.borderWidth = 1.5
            slot.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
            slot.isAccessibilityElement = false
            return slot
        }
        slots.forEach(tray.addSubview)
        tray.setNeedsLayout()
    }

    private func reveal(_ numbers: [Int], others: [[Int]]) {
        layoutIfNeeded()
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let origin = drum.center(in: self)
        let finish = { [weak self] in
            guard let self else { return }
            self.spinning = false
            self.showOthers(others)
            self.configureSpinButton()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let announcement = numbers.map(String.init).joined(separator: ", ")
            UIAccessibility.post(notification: .announcement, argument: announcement)
            self.tray.accessibilityLabel = announcement
        }
        for (index, number) in numbers.enumerated() where slots.indices.contains(index) {
            let slot = slots[index]
            let ball = LotoBallView(number: number, tag: signals.tag(of: number))
            if reduceMotion {
                ball.center = CGPoint(x: slot.bounds.midX, y: slot.bounds.midY)
                slot.addSubview(ball)
                continue
            }
            let target = slot.convert(CGPoint(x: slot.bounds.midX, y: slot.bounds.midY), to: self)
            ball.center = origin
            ball.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
            addSubview(ball)
            let delay = Double(index) * 0.2
            UIView.animate(withDuration: 0.7, delay: delay, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.6, options: []) {
                ball.center = target
                ball.transform = .identity
            } completion: { _ in
                ball.removeFromSuperview()
                ball.center = CGPoint(x: slot.bounds.midX, y: slot.bounds.midY)
                slot.addSubview(ball)
                slot.layer.borderWidth = 0
                if index == numbers.count - 1 { finish() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.1) { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
        if reduceMotion || numbers.isEmpty { finish() }
    }

    private func showOthers(_ sets: [[Int]]) {
        let copy = UIButton(type: .system)
        copy.configuration = {
            var configuration = UIButton.Configuration.tinted()
            configuration.title = NSLocalizedString("Copy these numbers", comment: "Loto lab: copy the main set")
            configuration.image = UIImage(systemName: "doc.on.doc")
            configuration.imagePadding = Design.Spacing.s
            configuration.baseForegroundColor = Design.Color.onHero
            configuration.cornerStyle = .capsule
            return configuration
        }()
        copy.accessibilityIdentifier = "loto_lab_copy"
        let main = tray.subviews.compactMap { $0.subviews.compactMap { $0 as? LotoBallView }.first?.number }
        copy.addAction(UIAction { [weak self] _ in self?.copyAction(main) }, for: .touchUpInside)
        moreStack.addArrangedSubview(copy)

        guard !sets.isEmpty else { return }
        moreStack.addArrangedSubview(text(.eyebrow, NSLocalizedString("Other sets", comment: "Loto lab: the remaining sets").uppercased(), color: Design.Color.onHeroSecondary))
        for numbers in sets {
            let balls = numbers.map { LotoBallView(number: $0, tag: signals.tag(of: $0), diameter: 34) }
            let row = LotoFlowView(views: balls)
            row.spacing = Design.Spacing.xs
            row.isAccessibilityElement = true
            row.accessibilityLabel = numbers.map(String.init).joined(separator: ", ")
            moreStack.addArrangedSubview(row)
            if !UIAccessibility.isReduceMotionEnabled {
                row.alpha = 0
                UIView.animate(withDuration: 0.4, delay: 0.1) { row.alpha = 1 }
            }
        }
    }
}
