import UIKit

/// Draws a kanji stroke by stroke from verified stroke data (`KanjiStrokeDrawing`), with play/pause, replay and single steps.
///
/// Progress is one number, `position`, in 0…strokeCount: strokes before `floor(position)` are complete, the one at that index
/// is drawn up to the fractional part, the rest are only a faint outline so the whole character stays readable. Playing moves
/// `position` forward with a display link; stepping moves it by whole strokes. With Reduce Motion the strokes are never
/// animated: the learner steps through them.
final class StrokeOrderView: UIView {
    private let drawing: KanjiStrokeDrawing
    private let guides = CAShapeLayer()
    private let ghosts: [CAShapeLayer]
    private let inks: [CAShapeLayer]
    private let numberLabels: [UILabel]
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    /// Seconds one stroke takes to draw while playing.
    static let secondsPerStroke: CFTimeInterval = 0.7

    private(set) var position: CGFloat = 0
    private(set) var isPlaying = false
    var onChange: (() -> Void)?

    var strokeCount: Int { drawing.strokes.count }
    /// Number of strokes completely drawn.
    var completedStrokes: Int { Int(position.rounded(.down)) }

    init(drawing: KanjiStrokeDrawing) {
        self.drawing = drawing
        ghosts = drawing.strokes.map { _ in CAShapeLayer() }
        inks = drawing.strokes.map { _ in CAShapeLayer() }
        numberLabels = drawing.strokes.indices.map { index in
            let label = UILabel()
            label.text = "\(index + 1)"
            label.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
            label.isHidden = true
            label.isAccessibilityElement = false
            return label
        }
        super.init(frame: .zero)
        applyCardSurface(radius: Design.Radius.card)
        layer.masksToBounds = true
        layer.addSublayer(guides)
        for (index, stroke) in drawing.strokes.enumerated() {
            for shape in [ghosts[index], inks[index]] {
                shape.path = stroke.path
                shape.fillColor = nil
                shape.lineCap = .round
                shape.lineJoin = .round
                layer.addSublayer(shape)
            }
            ghosts[index].strokeEnd = 1
            inks[index].strokeEnd = 0
        }
        numberLabels.forEach(addSubview)
        isAccessibilityElement = false
        accessibilityIdentifier = "stroke_order_canvas"
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: StrokeOrderView, _) in view.applyColors() }
        applyColors()
        render()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit { link?.invalidate() }

    // MARK: Controls

    func play() {
        guard !UIAccessibility.isReduceMotionEnabled, strokeCount > 0 else { return }
        if position >= CGFloat(strokeCount) { position = 0 }
        isPlaying = true
        lastTimestamp = 0
        link?.invalidate()
        let newLink = CADisplayLink(target: LinkTarget(self), selector: #selector(LinkTarget.tick(_:)))
        newLink.add(to: .main, forMode: .common)
        link = newLink
        notify()
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        link?.invalidate()
        link = nil
        // Settle on a whole stroke so a paused drawing is never half a stroke.
        position = position.rounded(.down)
        render()
        notify()
    }

    func replay() {
        pause()
        position = 0
        render()
        play()
    }

    func stepForward() {
        pause()
        position = min(CGFloat(strokeCount), position.rounded(.down) + 1)
        render()
        notify()
    }

    func stepBack() {
        pause()
        position = max(0, position.rounded(.down) - 1)
        render()
        notify()
    }

    func showAll() {
        pause()
        position = CGFloat(strokeCount)
        render()
        notify()
    }

    fileprivate func advance(to timestamp: CFTimeInterval) {
        defer { lastTimestamp = timestamp }
        guard lastTimestamp > 0 else { return }
        position += CGFloat((timestamp - lastTimestamp) / Self.secondsPerStroke)
        if position >= CGFloat(strokeCount) {
            position = CGFloat(strokeCount)
            isPlaying = false
            link?.invalidate()
            link = nil
            render()
            notify()
            return
        }
        render()
    }

    // MARK: Drawing

    private func notify() { onChange?() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        let scale = side / max(drawing.size.width, drawing.size.height)
        let origin = CGPoint(x: (bounds.width - drawing.size.width * scale) / 2, y: (bounds.height - drawing.size.height * scale) / 2)
        var transform = CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: scale, y: scale)
        for (index, stroke) in drawing.strokes.enumerated() {
            let path = stroke.path.copy(using: &transform)
            ghosts[index].path = path
            inks[index].path = path
            let width = max(2.5, 3.2 * scale / 2.2)
            ghosts[index].lineWidth = width
            inks[index].lineWidth = width
            if let start = path?.firstPoint {
                numberLabels[index].sizeToFit()
                numberLabels[index].center = CGPoint(x: start.x - 7, y: start.y - 7)
            }
        }
        // Calligraphy practice grid: the box, its centre cross, and the diagonals.
        let box = CGRect(x: origin.x, y: origin.y, width: drawing.size.width * scale, height: drawing.size.height * scale)
        let grid = UIBezierPath(rect: box)
        grid.move(to: CGPoint(x: box.midX, y: box.minY)); grid.addLine(to: CGPoint(x: box.midX, y: box.maxY))
        grid.move(to: CGPoint(x: box.minX, y: box.midY)); grid.addLine(to: CGPoint(x: box.maxX, y: box.midY))
        grid.move(to: box.origin); grid.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
        grid.move(to: CGPoint(x: box.maxX, y: box.minY)); grid.addLine(to: CGPoint(x: box.minX, y: box.maxY))
        guides.path = grid.cgPath
        guides.fillColor = nil
        guides.lineWidth = 0.5
        guides.lineDashPattern = [3, 3]
    }

    private func applyColors() {
        let trait = traitCollection
        guides.strokeColor = Design.Color.separator.resolvedColor(with: trait).cgColor
        for index in drawing.strokes.indices {
            ghosts[index].strokeColor = Design.Color.textSecondary.resolvedColor(with: trait).withAlphaComponent(0.22).cgColor
            inks[index].strokeColor = Design.Color.textPrimary.resolvedColor(with: trait).cgColor
            numberLabels[index].textColor = Design.Color.accent
        }
        render()
    }

    private func render() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let whole = Int(position.rounded(.down))
        for index in drawing.strokes.indices {
            let progress: CGFloat
            if index < whole { progress = 1 } else if index == whole { progress = position - CGFloat(whole) } else { progress = 0 }
            inks[index].strokeEnd = progress
            // The stroke being drawn is in the accent colour so the eye follows it; finished strokes settle to text colour.
            let current = index == whole && progress > 0 && progress < 1
            inks[index].strokeColor = (current ? Design.Color.accent : Design.Color.textPrimary).resolvedColor(with: traitCollection).cgColor
            numberLabels[index].isHidden = !(index < whole || current)
        }
        CATransaction.commit()
        accessibilityValue = String(format: NSLocalizedString("Stroke %1$lld of %2$lld", comment: "Stroke order progress"), min(whole, strokeCount), strokeCount)
    }
}

/// Keeps the display link from retaining the view (a display link retains its target).
private final class LinkTarget {
    weak var view: StrokeOrderView?
    init(_ view: StrokeOrderView) { self.view = view }
    @objc func tick(_ link: CADisplayLink) {
        guard let view else { link.invalidate(); return }
        view.advance(to: link.timestamp)
    }
}

private extension CGPath {
    /// The first point of the path (where its pen goes down).
    var firstPoint: CGPoint? {
        var result: CGPoint?
        applyWithBlock { element in
            if result == nil, element.pointee.type == .moveToPoint { result = element.pointee.points[0] }
        }
        return result
    }
}
