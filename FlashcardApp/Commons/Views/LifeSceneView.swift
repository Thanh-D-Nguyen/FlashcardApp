//
//  LifeSceneView.swift
//
//  The animated picture at the top of a life card and of a lesson: a soft gradient, one large symbol and the motion that belongs to
//  the topic (rain falls, a train passes, steam rises, leaves drift, a coin turns). It is decoration: hidden from VoiceOver, and
//  with Reduce Motion on (or while off screen) nothing moves. Solid colours only; no glass on content.
//

import UIKit

/// A label that counts up to a whole number once, unless Reduce Motion is on.
final class CountUpLabel: UILabel {
    private var link: CADisplayLink?
    private var start: CFTimeInterval = 0
    private var target = 0
    private var duration: CFTimeInterval = 0.9
    var format: (Int) -> String = { "\($0)" }

    func setValue(_ value: Int, animated: Bool) {
        link?.invalidate()
        target = value
        guard animated, !UIAccessibility.isReduceMotionEnabled, window != nil else { text = format(value); return }
        text = format(0)
        start = CACurrentMediaTime()
        let link = CADisplayLink(target: WeakTarget(self), selector: #selector(WeakTarget.tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    fileprivate func step() {
        let t = min(1, (CACurrentMediaTime() - start) / duration)
        let eased = 1 - pow(1 - t, 3)
        text = format(Int((Double(target) * eased).rounded()))
        if t >= 1 { link?.invalidate(); link = nil; text = format(target) }
    }

    override func removeFromSuperview() {
        link?.invalidate()
        link = nil
        super.removeFromSuperview()
    }

    private final class WeakTarget: NSObject {
        weak var label: CountUpLabel?
        init(_ label: CountUpLabel) { self.label = label }
        @objc func tick() { label?.step() }
    }
}

extension LifeTopic {
    /// Soft background of the topic's picture: (top, bottom) in light and dark appearance.
    fileprivate var palette: (UIColor, UIColor) {
        func pair(_ lightTop: UInt32, _ lightBottom: UInt32, _ darkTop: UInt32, _ darkBottom: UInt32) -> (UIColor, UIColor) {
            func color(_ hex: UInt32) -> UIColor {
                UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
            }
            return (UIColor { $0.userInterfaceStyle == .dark ? color(darkTop) : color(lightTop) },
                    UIColor { $0.userInterfaceStyle == .dark ? color(darkBottom) : color(lightBottom) })
        }
        switch self {
        case .date: return pair(0xDDE6F5, 0xB9C9E8, 0x2A3F66, 0x1B2B48)
        case .weather: return pair(0xDDE3EA, 0xBCC7D3, 0x2E3640, 0x232A33)
        case .nearby: return pair(0xCFEBDD, 0x9AD1B8, 0x244338, 0x1A332B)
        case .transit: return pair(0xD6E4F5, 0xA9C6E8, 0x233750, 0x1A2A3D)
        case .shopping: return pair(0xFADCE0, 0xF2B3BC, 0x4A2A30, 0x391F25)
        case .news: return pair(0xE6E1D6, 0xC9C2B1, 0x3A372F, 0x2C2A24)
        case .food: return pair(0xFBE3C8, 0xF4BE8A, 0x4B3822, 0x3A2A19)
        case .culture: return pair(0xF6D6C0, 0xE9A78A, 0x4B2E22, 0x39231A)
        case .money: return pair(0xFBF0BF, 0xEBD478, 0x4A4220, 0x383219)
        case .lottery: return pair(0xE6D8F5, 0xBFA6E3, 0x3A2F52, 0x2B2340)
        }
    }
}

final class LifeSceneView: UIView {
    private let gradient = CAGradientLayer()
    private let icon = UIImageView()
    private let secondary = UIImageView()
    private let numeral = CountUpLabel()
    private let caption = UILabel()
    private let emitter = CAEmitterLayer()
    private let decor = CALayer()
    private var scene: LifeScene = .place
    private var topic: LifeTopic = .nearby
    private var wantsMotion = true
    private var animatedOnce = false
    private var motionSize = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        layer.addSublayer(gradient)
        layer.addSublayer(decor)
        layer.addSublayer(emitter)
        icon.contentMode = .scaleAspectFit
        secondary.contentMode = .scaleAspectFit
        numeral.textAlignment = .center
        caption.textAlignment = .center
        [secondary, icon, numeral, caption].forEach { addSubview($0) }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: LifeSceneView, _) in view.applyColors() }
        NotificationCenter.default.addObserver(self, selector: #selector(motionPreferenceChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: Configure

    func configure(scene: LifeScene, topic: LifeTopic) {
        self.scene = scene
        self.topic = topic
        stopMotion()
        icon.image = nil
        secondary.image = nil
        numeral.isHidden = true
        caption.isHidden = true
        secondary.isHidden = true
        switch scene {
        case .weather(let kind, let temperature):
            icon.image = symbol(Self.weatherSymbol(kind), size: 54)
            icon.tintColor = Self.weatherTint(kind)
            if let temperature {
                numeral.isHidden = false
                numeral.format = { "\($0)°" }
                numeral.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: UIFont.systemFont(ofSize: 44, weight: .semibold).rounded(), maximumPointSize: 52)
                numeral.textColor = Design.Color.textPrimary
                numeral.text = "\(temperature)°"
            }
        case .date(let day, let weekday):
            numeral.isHidden = false
            caption.isHidden = false
            numeral.format = { "\($0)" }
            numeral.font = Design.TextRole.mincho(size: 40, style: .largeTitle, maximum: 46)
            numeral.textColor = Design.Color.textPrimary
            numeral.text = "\(day)"
            caption.text = weekday
            caption.font = Design.TextRole.mincho(size: 16, style: .headline, maximum: 20)
            caption.textColor = Design.Color.textPrimary.withAlphaComponent(0.78)
            icon.image = symbol("calendar", size: 84)
            icon.tintColor = Design.Color.textPrimary.withAlphaComponent(0.12)
        case .place:
            icon.image = symbol("mappin.circle.fill", size: 58)
            icon.tintColor = Self.adaptiveTint(light: 0x1E8066, dark: 0x6FD6B8)
        case .transit:
            icon.image = symbol("tram.fill", size: 54)
            icon.tintColor = Self.adaptiveTint(light: 0x295C9E, dark: 0x8FB4F0)
        case .shopping:
            icon.image = symbol("cart.fill", size: 52)
            icon.tintColor = Self.adaptiveTint(light: 0xBD3D57, dark: 0xF598AA)
            secondary.image = symbol("tag.fill", size: 28)
            secondary.tintColor = Self.adaptiveTint(light: 0xBD3D57, dark: 0xF598AA).withAlphaComponent(0.7)
            secondary.isHidden = false
        case .news:
            icon.image = symbol("newspaper.fill", size: 52)
            icon.tintColor = Self.adaptiveTint(light: 0x594D38, dark: 0xD9CEB8)
        case .food:
            icon.image = symbol("fork.knife.circle.fill", size: 54)
            icon.tintColor = Self.adaptiveTint(light: 0xC7661A, dark: 0xF7B06E)
        case .culture:
            icon.image = symbol("leaf.fill", size: 52)
            icon.tintColor = Self.adaptiveTint(light: 0xCC4D1F, dark: 0xF59A73)
        case .money:
            icon.image = symbol("yensign.circle.fill", size: 56)
            icon.tintColor = Self.adaptiveTint(light: 0x9E7508, dark: 0xF2D16B)
        case .lottery:
            icon.image = symbol("ticket.fill", size: 52)
            icon.tintColor = Self.adaptiveTint(light: 0x6E4BB3, dark: 0xC6B0F5)
        }
        applyColors()
        setNeedsLayout()
        if window != nil { startMotion() }
    }

    private func symbol(_ name: String, size: CGFloat) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .semibold))
    }

    private func applyColors() {
        var (top, bottom) = topic.palette
        if case .weather(let kind, _) = scene { (top, bottom) = Self.weatherPalette(kind) }
        gradient.colors = [top.resolvedColor(with: traitCollection).cgColor, bottom.resolvedColor(with: traitCollection).cgColor]
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        decor.frame = bounds
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -8)
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        CATransaction.commit()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        icon.bounds = CGRect(x: 0, y: 0, width: 90, height: 90)
        secondary.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        switch scene {
        case .weather:
            let hasNumeral = !numeral.isHidden
            icon.center = CGPoint(x: hasNumeral ? bounds.midX - 52 : center.x, y: center.y)
            // A fixed box: the number grows while it counts up and must not be cut off by an early size.
            numeral.bounds = CGRect(x: 0, y: 0, width: 110, height: 60)
            numeral.center = CGPoint(x: bounds.midX + 52, y: center.y)
        case .date:
            icon.bounds = CGRect(x: 0, y: 0, width: 96, height: 96)
            icon.center = CGPoint(x: center.x, y: center.y - 6)
            numeral.bounds = CGRect(x: 0, y: 0, width: 96, height: 52)
            numeral.center = CGPoint(x: center.x, y: center.y - 2)
            caption.bounds = CGRect(x: 0, y: 0, width: 120, height: 24)
            caption.center = CGPoint(x: center.x, y: center.y + 38)
        case .shopping:
            icon.center = center
            secondary.center = CGPoint(x: center.x + 58, y: center.y - 22)
        case .transit:
            icon.center = CGPoint(x: bounds.midX, y: center.y - 4)
        default:
            icon.center = center
        }
        // The motion is laid out from the size: restart it when the size is first known or changes.
        if window != nil, bounds.size != motionSize, bounds.width > 0 {
            motionSize = bounds.size
            stopMotion()
            startMotion()
        }
    }

    // MARK: Motion

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startMotion() } else { stopMotion() }
    }

    @objc private func motionPreferenceChanged() {
        stopMotion()
        if window != nil { startMotion() }
    }

    private func stopMotion() {
        [gradient, decor, emitter, icon.layer, secondary.layer, numeral.layer].forEach { $0.removeAllAnimations() }
        decor.sublayers?.forEach { $0.removeFromSuperlayer() }
        emitter.emitterCells = nil
        emitter.birthRate = 0
        icon.removeAllSymbolEffects()
        icon.transform = .identity
    }

    private func startMotion() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        // A slow drift of the background light.
        let drift = CABasicAnimation(keyPath: "startPoint")
        drift.fromValue = CGPoint(x: 0, y: 0)
        drift.toValue = CGPoint(x: 0.35, y: 0.1)
        drift.duration = 7
        drift.autoreverses = true
        drift.repeatCount = .infinity
        drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradient.add(drift, forKey: "drift")

        switch scene {
        case .weather(let kind, _): startWeather(kind)
        case .date:
            if !animatedOnce { flipIn() }
            icon.addSymbolEffect(.pulse, options: .repeating)
        case .place: startPlace()
        case .transit: startTransit()
        case .shopping:
            bob(icon.layer, by: 6, duration: 1.1)
            bob(secondary.layer, by: -5, duration: 0.9)
            sparkles(symbol: "sparkle", colors: [UIColor.white])
        case .news:
            icon.addSymbolEffect(.variableColor.iterative.reversing, options: .repeating)
        case .food: startSteam()
        case .culture: leaves()
        case .money:
            let spin = CABasicAnimation(keyPath: "transform.rotation.y")
            spin.fromValue = 0
            spin.toValue = Double.pi * 2
            spin.duration = 3.2
            spin.repeatCount = .infinity
            var transform = CATransform3DIdentity
            transform.m34 = -1 / 400
            icon.layer.transform = transform
            icon.layer.add(spin, forKey: "spin")
            sparkles(symbol: "sparkle", colors: [UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1)])
        case .lottery: startBalls()
        }
        animatedOnce = true
        if case .weather = scene, !numeral.isHidden, let value = Int((numeral.text ?? "").replacingOccurrences(of: "°", with: "")) {
            numeral.setValue(value, animated: true)
        }
        if case .date(let day, _) = scene { numeral.setValue(day, animated: true) }
    }

    private func bob(_ layer: CALayer, by distance: CGFloat, duration: CFTimeInterval) {
        let a = CABasicAnimation(keyPath: "transform.translation.y")
        a.fromValue = 0
        a.toValue = distance
        a.duration = duration
        a.autoreverses = true
        a.repeatCount = .infinity
        a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(a, forKey: "bob")
    }

    private func flipIn() {
        let flip = CASpringAnimation(keyPath: "transform.rotation.x")
        flip.fromValue = -Double.pi / 2
        flip.toValue = 0
        flip.damping = 12
        flip.duration = flip.settlingDuration
        var transform = CATransform3DIdentity
        transform.m34 = -1 / 500
        numeral.layer.transform = transform
        numeral.layer.add(flip, forKey: "flip")
    }

    private func startWeather(_ kind: LifeWeatherKind) {
        switch kind {
        case .sunny:
            icon.addSymbolEffect(.rotate.byLayer, options: .repeating)
            sparkles(symbol: "sparkle", colors: [UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1)])
        case .partlyCloudy:
            bob(icon.layer, by: 5, duration: 1.6)
            drift(symbol: "cloud.fill", y: 0.28, alpha: 0.55, duration: 14)
        case .cloudy:
            bob(icon.layer, by: 4, duration: 2)
            drift(symbol: "cloud.fill", y: 0.22, alpha: 0.5, duration: 12)
            drift(symbol: "cloud.fill", y: 0.7, alpha: 0.35, duration: 18)
        case .fog:
            for (index, y) in [0.35, 0.55, 0.75].enumerated() { drift(symbol: "cloud.fog.fill", y: y, alpha: 0.35, duration: 10 + Double(index) * 3) }
        case .drizzle, .rain, .heavyRain, .showers:
            drift(symbol: "cloud.fill", y: 0.2, alpha: 0.5, duration: 16)
            rain(heavy: kind == .heavyRain || kind == .showers)
        case .snow:
            snow()
        case .thunderstorm:
            rain(heavy: true)
            let flash = CAKeyframeAnimation(keyPath: "opacity")
            flash.values = [1, 1, 0.2, 1, 0.3, 1, 1]
            flash.keyTimes = [0, 0.6, 0.62, 0.65, 0.68, 0.72, 1]
            flash.duration = 3.4
            flash.repeatCount = .infinity
            icon.layer.add(flash, forKey: "flash")
        }
    }

    private func drift(symbol name: String, y: CGFloat, alpha: CGFloat, duration: CFTimeInterval) {
        let layer = CALayer()
        let image = symbol(name, size: 34)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        layer.contents = image?.cgImage
        layer.contentsScale = traitCollection.displayScale
        layer.opacity = Float(alpha)
        let size = image?.size ?? CGSize(width: 40, height: 28)
        layer.bounds = CGRect(origin: .zero, size: size)
        layer.position = CGPoint(x: -size.width, y: bounds.height * y)
        decor.addSublayer(layer)
        let a = CABasicAnimation(keyPath: "position.x")
        a.fromValue = -size.width
        a.toValue = max(bounds.width, 320) + size.width
        a.duration = duration
        a.repeatCount = .infinity
        a.timeOffset = duration * Double(y)
        layer.add(a, forKey: "drift")
    }

    private func particle(image: UIImage?, birth: Float, lifetime: Float, velocity: CGFloat, spread: CGFloat, scale: CGFloat, alpha: Float = 0.8,
                          emissionLongitude: CGFloat = .pi / 2, spin: CGFloat = 0) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = image?.cgImage
        cell.birthRate = birth
        cell.lifetime = lifetime
        cell.velocity = velocity
        cell.velocityRange = velocity * 0.3
        cell.emissionLongitude = emissionLongitude
        cell.emissionRange = spread
        cell.scale = scale
        cell.scaleRange = scale * 0.4
        cell.alphaSpeed = -alpha / lifetime
        cell.color = UIColor(white: 1, alpha: CGFloat(alpha)).cgColor
        cell.spinRange = spin
        return cell
    }

    private func rain(heavy: Bool) {
        let streak = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 16)).image { context in
            UIColor.white.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 2, height: 16), cornerRadius: 1).fill()
        }
        emitter.emitterShape = .line
        emitter.emitterCells = [particle(image: streak, birth: heavy ? 90 : 45, lifetime: 1.3, velocity: heavy ? 220 : 160, spread: 0.12, scale: 1, alpha: 0.7,
                                         emissionLongitude: .pi / 2 + 0.12)]
        emitter.birthRate = 1
    }

    private func snow() {
        let dot = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 8, height: 8)).fill()
        }
        emitter.emitterShape = .line
        emitter.emitterCells = [particle(image: dot, birth: 22, lifetime: 4.5, velocity: 34, spread: 0.6, scale: 0.9, alpha: 0.95)]
        emitter.birthRate = 1
        icon.addSymbolEffect(.pulse, options: .repeating)
    }

    private func leaves() {
        let leaf = symbol("leaf.fill", size: 16)?.withTintColor(UIColor(red: 0.85, green: 0.35, blue: 0.15, alpha: 1), renderingMode: .alwaysOriginal)
        emitter.emitterShape = .line
        emitter.emitterCells = [particle(image: leaf, birth: 2.2, lifetime: 6, velocity: 30, spread: 0.7, scale: 1, alpha: 0.95, spin: 3)]
        emitter.birthRate = 1
        bob(icon.layer, by: 4, duration: 1.8)
    }

    private func sparkles(symbol name: String, colors: [UIColor]) {
        let image = symbol(name, size: 12)?.withTintColor(colors.first ?? .white, renderingMode: .alwaysOriginal)
        emitter.emitterShape = .rectangle
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emitter.emitterSize = bounds.size
        let cell = particle(image: image, birth: 1.6, lifetime: 2.4, velocity: 0, spread: .pi * 2, scale: 1, alpha: 0.9, emissionLongitude: 0)
        cell.alphaSpeed = -0.4
        cell.scaleSpeed = -0.25
        emitter.emitterCells = [cell]
        emitter.birthRate = 1
    }

    private func startPlace() {
        for index in 0..<3 {
            let ring = CAShapeLayer()
            ring.path = UIBezierPath(ovalIn: CGRect(x: -30, y: -30, width: 60, height: 60)).cgPath
            ring.fillColor = UIColor.clear.cgColor
            ring.strokeColor = UIColor(red: 0.12, green: 0.5, blue: 0.4, alpha: 0.55).cgColor
            ring.lineWidth = 2
            ring.position = CGPoint(x: bounds.midX, y: bounds.midY + 22)
            decor.addSublayer(ring)
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.3
            scale.toValue = 2.4
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.9
            fade.toValue = 0
            let group = CAAnimationGroup()
            group.animations = [scale, fade]
            group.duration = 2.4
            group.repeatCount = .infinity
            group.timeOffset = Double(index) * 0.8
            ring.add(group, forKey: "ripple")
        }
        bob(icon.layer, by: -7, duration: 0.8)
    }

    private func startTransit() {
        let track = CAShapeLayer()
        let path = UIBezierPath()
        let y = bounds.height - 22
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: max(bounds.width, 320) + 40, y: y))
        track.path = path.cgPath
        track.strokeColor = UIColor(red: 0.16, green: 0.36, blue: 0.62, alpha: 0.35).cgColor
        track.lineWidth = 3
        track.lineDashPattern = [10, 8]
        decor.addSublayer(track)
        let march = CABasicAnimation(keyPath: "lineDashPhase")
        march.fromValue = 0
        march.toValue = -36
        march.duration = 0.9
        march.repeatCount = .infinity
        track.add(march, forKey: "march")
        let slide = CABasicAnimation(keyPath: "transform.translation.x")
        slide.fromValue = -max(bounds.width, 320) * 0.5 - 60
        slide.toValue = max(bounds.width, 320) * 0.5 + 60
        slide.duration = 4.2
        slide.repeatCount = .infinity
        slide.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        icon.layer.add(slide, forKey: "slide")
    }

    private func startSteam() {
        for index in 0..<3 {
            let wisp = CAShapeLayer()
            let path = UIBezierPath()
            path.move(to: .zero)
            path.addCurve(to: CGPoint(x: 0, y: -34), controlPoint1: CGPoint(x: 10, y: -10), controlPoint2: CGPoint(x: -10, y: -24))
            wisp.path = path.cgPath
            wisp.strokeColor = UIColor.white.withAlphaComponent(0.85).cgColor
            wisp.fillColor = UIColor.clear.cgColor
            wisp.lineWidth = 3
            wisp.lineCap = .round
            wisp.position = CGPoint(x: bounds.midX - 22 + CGFloat(index) * 22, y: bounds.midY - 18)
            decor.addSublayer(wisp)
            let rise = CABasicAnimation(keyPath: "transform.translation.y")
            rise.fromValue = 12
            rise.toValue = -22
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 0.9, 0]
            let group = CAAnimationGroup()
            group.animations = [rise, fade]
            group.duration = 2.2
            group.repeatCount = .infinity
            group.timeOffset = Double(index) * 0.7
            wisp.add(group, forKey: "steam")
        }
        bob(icon.layer, by: 3, duration: 1.4)
    }

    private func startBalls() {
        let colors: [UIColor] = [UIColor(red: 0.9, green: 0.35, blue: 0.4, alpha: 1), UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1), UIColor(red: 0.95, green: 0.75, blue: 0.2, alpha: 1)]
        for index in 0..<3 {
            let ball = CAShapeLayer()
            ball.path = UIBezierPath(ovalIn: CGRect(x: -11, y: -11, width: 22, height: 22)).cgPath
            ball.fillColor = colors[index].cgColor
            ball.position = CGPoint(x: bounds.midX - 60 + CGFloat(index) * 60 + (index == 1 ? 0 : 0), y: bounds.height - 26)
            decor.addSublayer(ball)
            let hop = CAKeyframeAnimation(keyPath: "transform.translation.y")
            hop.values = [0, -26, 0, -8, 0]
            hop.keyTimes = [0, 0.35, 0.65, 0.8, 1]
            hop.duration = 1.6
            hop.repeatCount = .infinity
            hop.timeOffset = Double(index) * 0.35
            ball.add(hop, forKey: "hop")
        }
        icon.addSymbolEffect(.wiggle, options: .repeating)
    }

    // MARK: Weather look

    private static func weatherSymbol(_ kind: LifeWeatherKind) -> String {
        switch kind {
        case .sunny: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .fog: return "cloud.fog.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .rain: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .showers: return "cloud.sun.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        }
    }

    private static func adaptiveTint(light: UInt32, dark: UInt32) -> UIColor {
        func rgb(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        return UIColor { $0.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) }
    }

    private static func weatherTint(_ kind: LifeWeatherKind) -> UIColor {
        switch kind {
        case .sunny, .partlyCloudy: return adaptiveTint(light: 0xD9820B, dark: 0xFFD166)
        case .snow: return adaptiveTint(light: 0x3D6BA6, dark: 0xB8D8FA)
        case .thunderstorm: return adaptiveTint(light: 0x454580, dark: 0xC2C4F5)
        default: return adaptiveTint(light: 0x3A5273, dark: 0xB5C8E0)
        }
    }

    private static func weatherPalette(_ kind: LifeWeatherKind) -> (UIColor, UIColor) {
        func color(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        func pair(_ lt: UInt32, _ lb: UInt32, _ dt: UInt32, _ db: UInt32) -> (UIColor, UIColor) {
            (UIColor { $0.userInterfaceStyle == .dark ? color(dt) : color(lt) }, UIColor { $0.userInterfaceStyle == .dark ? color(db) : color(lb) })
        }
        switch kind {
        case .sunny: return pair(0xFFE9B8, 0xFFC878, 0x5A4620, 0x3F3116)
        case .partlyCloudy: return pair(0xFFEFD0, 0xC9DAEE, 0x4A4430, 0x2E3A4B)
        case .cloudy: return pair(0xDDE3EA, 0xBCC7D3, 0x2E3640, 0x232A33)
        case .fog: return pair(0xE5E7E8, 0xC8CCCF, 0x34383B, 0x282B2D)
        case .drizzle, .rain, .showers: return pair(0xC6D3E4, 0x93A9C4, 0x24344A, 0x1A2636)
        case .heavyRain: return pair(0xAFC0D6, 0x7C93B2, 0x1E2D42, 0x152033)
        case .snow: return pair(0xEAF1FA, 0xC9D8EA, 0x35435A, 0x27334A)
        case .thunderstorm: return pair(0xB4B8CE, 0x6F7599, 0x2A2C44, 0x1B1D33)
        }
    }
}

private extension UIFont {
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
