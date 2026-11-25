import UIKit

// MARK: What each factor is called, in the app's language and in Japanese

extension LotoChaosFactor.Kind {
    var title: String {
        switch self {
        case .moment: return NSLocalizedString("The exact moment", comment: "Loto chaos factor")
        case .draw: return NSLocalizedString("The draw", comment: "Loto chaos factor")
        case .weather: return NSLocalizedString("Weather in Japan", comment: "Loto chaos factor")
        case .motion: return NSLocalizedString("Shake of your phone", comment: "Loto chaos factor")
        case .touch: return NSLocalizedString("Your touches", comment: "Loto chaos factor")
        case .drum: return NSLocalizedString("Balls in the drum", comment: "Loto chaos factor")
        case .slider: return NSLocalizedString("Your randomness setting", comment: "Loto chaos factor")
        }
    }

    /// Why it can change the outcome, in a sentence.
    var why: String {
        switch self {
        case .moment: return NSLocalizedString("The clock is read to the millisecond, so no two spins start at the same time.", comment: "Loto chaos factor reason")
        case .draw: return NSLocalizedString("The game, the date and the draw number tie the system to this draw.", comment: "Loto chaos factor reason")
        case .weather: return NSLocalizedString("Read from the server for ten cities. A tenth of a degree in any one of them moves the start.", comment: "Loto chaos factor reason")
        case .motion: return NSLocalizedString("How your hand shakes the phone while the drum spins.", comment: "Loto chaos factor reason")
        case .touch: return NSLocalizedString("When and how you moved the slider and pressed the button.", comment: "Loto chaos factor reason")
        case .drum: return NSLocalizedString("Where each ball is when the drum stops. Colliding balls are a chaotic system of their own.", comment: "Loto chaos factor reason")
        case .slider: return NSLocalizedString("Your own setting joins the start as well.", comment: "Loto chaos factor reason")
        }
    }

    var symbol: String {
        switch self {
        case .moment: return "clock.fill"
        case .draw: return "ticket.fill"
        case .weather: return "cloud.sun.fill"
        case .motion: return "iphone.radiowaves.left.and.right"
        case .touch: return "hand.tap.fill"
        case .drum: return "circle.grid.3x3.fill"
        case .slider: return "slider.horizontal.3"
        }
    }

    /// The Japanese word for the factor and its reading. Written by us as study material, not taken from a dictionary service.
    var japanese: (word: String, reading: String) {
        switch self {
        case .moment: return ("日時", "にちじ")
        case .draw: return ("抽選日", "ちゅうせんび")
        case .weather: return ("天気", "てんき")
        case .motion: return ("揺れ", "ゆれ")
        case .touch: return ("操作", "そうさ")
        case .drum: return ("玉", "たま")
        case .slider: return ("設定", "せってい")
        }
    }
}

private enum CityReading {
    static let readings: [String: String] = [
        "tokyo": "とうきょう", "yokohama": "よこはま", "osaka": "おおさか", "nagoya": "なごや", "kyoto": "きょうと",
        "sapporo": "さっぽろ", "sendai": "せんだい", "hiroshima": "ひろしま", "fukuoka": "ふくおか", "naha": "なは"
    ]
}

// MARK: Study material

/// Words this page teaches. Authored here as study material (term, reading, meaning, one example sentence); it is not
/// dictionary data and the app does not look anything up for it.
struct LotoChaosTerm {
    let word: String
    let reading: String
    let meaning: String
    let example: String
    let exampleReading: String
    let translation: String

    static var all: [LotoChaosTerm] {
        [
            LotoChaosTerm(word: "バタフライ効果", reading: "バタフライこうか",
                          meaning: NSLocalizedString("Butterfly effect: a tiny change grows into a big difference.", comment: "Loto chaos term"),
                          example: "小さな変化が大きな結果を生むことを、バタフライ効果と言います。",
                          exampleReading: "ちいさなへんかがおおきなけっかをうむことを、バタフライこうかといいます。",
                          translation: NSLocalizedString("A tiny change that makes a big result is called the butterfly effect.", comment: "Loto chaos example")),
            LotoChaosTerm(word: "カオス", reading: "カオス",
                          meaning: NSLocalizedString("Chaos: a system that follows rules, yet cannot be predicted far ahead.", comment: "Loto chaos term"),
                          example: "天気はカオスの一例です。", exampleReading: "てんきはカオスのいちれいです。",
                          translation: NSLocalizedString("The weather is one example of chaos.", comment: "Loto chaos example")),
            LotoChaosTerm(word: "初期値", reading: "しょきち",
                          meaning: NSLocalizedString("Initial value: where the system starts.", comment: "Loto chaos term"),
                          example: "初期値がほんの少し違うと、結果は大きく変わります。", exampleReading: "しょきちがほんのすこしちがうと、けっかはおおきくかわります。",
                          translation: NSLocalizedString("If the starting value differs by just a little, the result changes a lot.", comment: "Loto chaos example")),
            LotoChaosTerm(word: "影響", reading: "えいきょう",
                          meaning: NSLocalizedString("Influence: an effect one thing has on another.", comment: "Loto chaos term"),
                          example: "どんな小さなことも、全体に影響します。", exampleReading: "どんなちいさなことも、ぜんたいにえいきょうします。",
                          translation: NSLocalizedString("Anything, however small, influences the whole.", comment: "Loto chaos example")),
            LotoChaosTerm(word: "天気", reading: "てんき",
                          meaning: NSLocalizedString("Weather.", comment: "Loto chaos term"),
                          example: "東京の天気が少し変わると、結果も変わります。", exampleReading: "とうきょうのてんきがすこしかわると、けっかもかわります。",
                          translation: NSLocalizedString("If the weather in Tokyo changes a little, the result changes too.", comment: "Loto chaos example")),
            LotoChaosTerm(word: "乱数", reading: "らんすう",
                          meaning: NSLocalizedString("Random number: a number with no pattern.", comment: "Loto chaos term"),
                          example: "乱数は、規則のない数のことです。", exampleReading: "らんすうは、きそくのないかずのことです。",
                          translation: NSLocalizedString("A random number is a number that has no rule.", comment: "Loto chaos example")),
            LotoChaosTerm(word: "予測", reading: "よそく",
                          meaning: NSLocalizedString("Prediction: saying in advance what will happen.", comment: "Loto chaos term"),
                          example: "宝くじの結果は予測できません。", exampleReading: "たからくじのけっかはよそくできません。",
                          translation: NSLocalizedString("The result of a lottery cannot be predicted.", comment: "Loto chaos example")),
            LotoChaosTerm(word: "確率", reading: "かくりつ",
                          meaning: NSLocalizedString("Probability: how likely something is.", comment: "Loto chaos term"),
                          example: "どの組み合わせも、確率は同じです。", exampleReading: "どのくみあわせも、かくりつはおなじです。",
                          translation: NSLocalizedString("Every combination has the same probability.", comment: "Loto chaos example"))
        ]
    }
}

// MARK: Butterfly

/// The two paths of the Lorenz system seen from the front (x across, z up): the shape of a butterfly. Gold is the system,
/// blue is a copy that started a millionth away. They run together, then part.
final class LotoButterflyView: UIView {
    private let original = CAShapeLayer()
    private let copy = CAShapeLayer()
    private let marker = CAShapeLayer()
    private var result: LotoChaosResult?

    static let goldColor = LotoPalette.gold
    static let copyColor = UIColor(red: 0.45, green: 0.80, blue: 1.0, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Design.Color.hero
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        for (shape, color) in [(copy, Self.copyColor), (original, Self.goldColor)] {
            shape.fillColor = nil
            shape.strokeColor = color.cgColor
            shape.lineWidth = 1.6
            shape.lineJoin = .round
            shape.lineCap = .round
            layer.addSublayer(shape)
        }
        marker.fillColor = nil
        marker.strokeColor = UIColor.white.cgColor
        marker.lineWidth = 2
        marker.opacity = 0
        layer.addSublayer(marker)
        isAccessibilityElement = true
        accessibilityTraits = .image
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 240) }

    override func layoutSubviews() {
        super.layoutSubviews()
        for shape in [original, copy, marker] { shape.frame = bounds }
        draw(animated: false)
    }

    func show(_ result: LotoChaosResult) {
        self.result = result
        draw(animated: true)
    }

    private func project(_ points: [LotoChaosPoint]) -> [CGPoint] {
        // The attractor always lies within these bounds, so the picture keeps its scale from one spin to the next.
        let minX = -22.0, maxX = 22.0, minZ = 0.0, maxZ = 52.0
        let inset: CGFloat = 14
        let width = bounds.width - inset * 2, height = bounds.height - inset * 2
        return points.map { CGPoint(x: inset + CGFloat((($0.x - minX) / (maxX - minX))) * width,
                                    y: inset + CGFloat(1 - (($0.z - minZ) / (maxZ - minZ))) * height) }
    }

    private func path(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        return path
    }

    private func draw(animated: Bool) {
        guard let result, bounds.width > 0 else { return }
        let a = project(result.original), b = project(result.perturbed)
        original.path = path(a)
        copy.path = path(b)
        let seconds = 4.0
        let animate = animated && !UIAccessibility.isReduceMotionEnabled
        for shape in [original, copy] {
            shape.removeAllAnimations()
            shape.strokeEnd = 1
            if animate {
                let animation = CABasicAnimation(keyPath: "strokeEnd")
                animation.fromValue = 0
                animation.toValue = 1
                animation.duration = seconds
                shape.add(animation, forKey: "draw")
            }
        }
        marker.removeAllAnimations()
        if let index = result.divergenceIndex, a.indices.contains(index) {
            marker.path = UIBezierPath(arcCenter: a[index], radius: 9, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
            let delay = animate ? seconds * Double(index) / Double(a.count) : 0
            if animate {
                marker.opacity = 0
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = 0
                fade.toValue = 1
                fade.beginTime = CACurrentMediaTime() + delay
                fade.duration = 0.4
                fade.fillMode = .both
                marker.add(fade, forKey: "fade")
                marker.opacity = 1
            } else {
                marker.opacity = 1
            }
        } else {
            marker.opacity = 0
        }
    }
}

// MARK: Panel

/// Under the lab: the butterfly effect explained, what went into the last spin, and the Japanese words of the page.
final class LotoChaosPanelView: LotoPanel {
    private let game: LotoGame
    private let resultStack = UIStackView()
    private let butterfly = LotoButterflyView()
    private let caption = UILabel()
    private let fingerprint = UILabel()
    private let factorsStack = UIStackView()

    init(game: LotoGame) {
        self.game = game
        super.init(spacing: Design.Spacing.m)
        accessibilityIdentifier = "loto_chaos"

        let eyebrow = Self.label(.eyebrow, NSLocalizedString("Butterfly effect", comment: "Loto chaos eyebrow").uppercased() + " · バタフライ効果", color: Design.Color.accent)
        let title = Self.label(.headword, NSLocalizedString("Every spin is a small chaotic system", comment: "Loto chaos title"))
        let intro = Self.label(.explanation, NSLocalizedString("In a chaotic system the rules are fixed, yet a tiny change at the start grows until the end looks nothing like it. Weather is the classic case: Edward Lorenz found it in 1963 while modelling the weather. A real draw machine, with its moving balls, is a very sensitive system too. Here every spin gathers what is really around you and in Japan at that moment, and starts a small Lorenz system from it.", comment: "Loto chaos intro"))
        [eyebrow, title, intro].forEach(content.addArrangedSubview)

        let hint = Self.label(.metadata, NSLocalizedString("Spin the drum above to see your own system.", comment: "Loto chaos before the first spin"), color: Design.Color.textSecondary)
        hint.accessibilityIdentifier = "loto_chaos_hint"

        caption.apply(.explanation)
        caption.numberOfLines = 0
        fingerprint.apply(.metadata)
        fingerprint.textColor = Design.Color.textSecondary
        fingerprint.numberOfLines = 0

        let legend = UIStackView(arrangedSubviews: [Self.legendItem(NSLocalizedString("Your system", comment: "Loto chaos legend"), color: LotoButterflyView.goldColor),
                                                    Self.legendItem(NSLocalizedString("The same system, started one millionth away", comment: "Loto chaos legend"), color: LotoButterflyView.copyColor)])
        legend.axis = .vertical
        legend.spacing = Design.Spacing.xs

        let factorsTitle = Self.label(.title, NSLocalizedString("What went into this spin", comment: "Loto chaos factors title"))
        factorsStack.axis = .vertical
        factorsStack.spacing = Design.Spacing.m
        resultStack.axis = .vertical
        resultStack.spacing = Design.Spacing.m
        [butterfly, legend, caption, fingerprint, factorsTitle, factorsStack].forEach(resultStack.addArrangedSubview)
        resultStack.isHidden = true
        content.addArrangedSubview(hint)
        content.addArrangedSubview(resultStack)
        butterfly.heightAnchor.constraint(equalToConstant: 240).isActive = true

        content.addArrangedSubview(Self.separator())
        content.addArrangedSubview(Self.label(.title, NSLocalizedString("Learn Japanese from this", comment: "Loto chaos study title")))
        content.addArrangedSubview(Self.label(.metadata, NSLocalizedString("The words of this page, with their reading and one example sentence.", comment: "Loto chaos study subtitle"), color: Design.Color.textSecondary))
        for term in LotoChaosTerm.all { content.addArrangedSubview(Self.termCard(term)) }

        content.addArrangedSubview(Self.separator())
        content.addArrangedSubview(Self.honestBox())
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show(_ result: LotoChaosResult) {
        if let hint = content.arrangedSubviews.first(where: { $0.accessibilityIdentifier == "loto_chaos_hint" }) { hint.isHidden = true }
        resultStack.isHidden = false
        butterfly.show(result)
        let language = AppLanguage.current.locale
        let start = result.perturbation.formatted(.number.precision(.fractionLength(6)).locale(language))
        let distance = result.finalDistance.formatted(.number.precision(.fractionLength(1)).locale(language))
        if let index = result.divergenceIndex {
            let steps = (index * LotoChaosEngine.stepsPerSample).formatted(.number.locale(language))
            caption.text = String(format: NSLocalizedString("The two paths started %@ apart. After %@ steps they were already more than %d apart: no longer the same story.", comment: "Loto chaos caption when the paths part"),
                                  start, steps, Int(LotoChaosEngine.divergenceDistance))
        } else {
            caption.text = String(format: NSLocalizedString("The two paths started %@ apart and ended %@ apart.", comment: "Loto chaos caption"), start, distance)
        }
        butterfly.accessibilityLabel = caption.text
        fingerprint.text = String(format: NSLocalizedString("Fingerprint %@. Change any one factor and the fingerprint, the path and the numbers all change.", comment: "Loto chaos fingerprint"), result.fingerprint)

        factorsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for kind in LotoChaosFactor.Kind.allCases {
            let factors = result.factors.filter { $0.kind == kind }
            guard !factors.isEmpty else { continue }
            factorsStack.addArrangedSubview(factorRow(kind: kind, factors: factors))
        }
    }

    // MARK: Pieces

    private func factorRow(kind: LotoChaosFactor.Kind, factors: [LotoChaosFactor]) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: kind.symbol))
        icon.tintColor = Design.Color.accent
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let japanese = kind.japanese
        let heading = Self.label(.title, "\(kind.title) · \(japanese.word) (\(japanese.reading))")
        let why = Self.label(.metadata, kind.why, color: Design.Color.textSecondary)
        var lines: [UIView] = [heading, why]
        if kind == .weather {
            let values = factors.compactMap { factor -> String? in
                guard let id = factor.subject, let city = LifeCity.city(id: id) else { return nil }
                return "\(city.nameJa) (\(CityReading.readings[id] ?? "")) \(factor.display)"
            }
            lines.append(Self.label(.figure, values.joined(separator: "\n")))
        } else {
            lines.append(Self.label(.figure, factors.map(\.display).joined(separator: "\n")))
        }
        let text = UIStackView(arrangedSubviews: lines)
        text.axis = .vertical
        text.spacing = Design.Spacing.xs
        let row = UIStackView(arrangedSubviews: [icon, text])
        row.spacing = Design.Spacing.m
        row.alignment = .top
        row.isAccessibilityElement = true
        row.accessibilityLabel = ([kind.title, kind.why] + factors.map(\.display)).joined(separator: ". ")
        return row
    }

    private static func termCard(_ term: LotoChaosTerm) -> UIView {
        let word = label(.headword, term.word)
        let reading = label(.reading, term.reading, color: Design.Color.textSecondary)
        let meaning = label(.meaning, term.meaning)
        let example = label(.sentence, term.example)
        let exampleReading = label(.reading, term.exampleReading, color: Design.Color.textSecondary)
        let translation = label(.metadata, term.translation, color: Design.Color.textSecondary)
        let stack = UIStackView(arrangedSubviews: [word, reading, meaning, example, exampleReading, translation])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.setCustomSpacing(Design.Spacing.s, after: meaning)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: Design.Spacing.m, bottom: Design.Spacing.m, trailing: Design.Spacing.m)
        let card = UIView()
        card.backgroundColor = Design.Color.surfaceTint
        card.layer.cornerRadius = Design.Radius.control
        card.layer.cornerCurve = .continuous
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor), stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor), stack.trailingAnchor.constraint(equalTo: card.trailingAnchor)
        ])
        card.isAccessibilityElement = true
        card.accessibilityLabel = "\(term.word), \(term.reading). \(term.meaning) \(term.example) \(term.translation)"
        return card
    }

    private static func honestBox() -> UIView {
        let title = label(.title, NSLocalizedString("Why this does not help you win", comment: "Loto chaos honest title"))
        let body = label(.explanation, NSLocalizedString("The chaotic system is a model that runs on your phone. It cannot see or reach the real machine, and the real balls do not know the weather you read. Every combination still has the same chance. Use it to see how a tiny cause becomes a big difference, and to learn the words.", comment: "Loto chaos honest body"))
        let stack = UIStackView(arrangedSubviews: [title, body])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.isAccessibilityElement = true
        stack.accessibilityLabel = [title.text, body.text].compactMap { $0 }.joined(separator: ". ")
        return stack
    }

    private static func legendItem(_ text: String, color: UIColor) -> UIView {
        let dot = UIView()
        dot.backgroundColor = color
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([dot.widthAnchor.constraint(equalToConstant: 10), dot.heightAnchor.constraint(equalToConstant: 10)])
        let row = UIStackView(arrangedSubviews: [dot, label(.metadata, text, color: Design.Color.textSecondary)])
        row.spacing = Design.Spacing.s
        row.alignment = .center
        return row
    }

    private static func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = Design.Color.separator
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    private static func label(_ role: Design.TextRole, _ text: String, color: UIColor? = nil) -> UILabel {
        let label = UILabel()
        label.apply(role)
        label.text = text
        label.numberOfLines = 0
        if let color { label.textColor = color }
        return label
    }
}
