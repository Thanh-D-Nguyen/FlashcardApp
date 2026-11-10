import UIKit

/// A square pad that records finger or Apple Pencil strokes and shows them as ink. It knows nothing about recognition.
final class HandwritingCanvasView: UIView {
    /// Called after a stroke ends, is undone or the pad is cleared.
    var onInkChange: ((HandwritingInk) -> Void)?
    private(set) var ink = HandwritingInk()

    private let guides = CAShapeLayer()
    private let inkLayer = CAShapeLayer()
    private var currentStroke: [InkPoint]?
    private var activeTouch: UITouch?
    /// Samples closer than this to the previous one add nothing but cost.
    private let minimumStep: CGFloat = 1.5

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        isExclusiveTouch = true
        backgroundColor = Design.Color.surface
        layer.cornerRadius = Design.Radius.panel
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        guides.fillColor = nil
        guides.lineWidth = 1
        guides.lineDashPattern = [4, 4]
        inkLayer.fillColor = nil
        inkLayer.lineCap = .round
        inkLayer.lineJoin = .round
        inkLayer.lineWidth = 7
        layer.addSublayer(guides)
        layer.addSublayer(inkLayer)
        isAccessibilityElement = true
        accessibilityLabel = NSLocalizedString("Handwriting area", comment: "")
        accessibilityHint = NSLocalizedString("Draw one character here with your finger or Apple Pencil.", comment: "")
        // VoiceOver passes touches straight through, so the pad can be drawn on.
        accessibilityTraits = .allowsDirectInteraction
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in self.applyColors() }
        applyColors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guides.frame = bounds
        inkLayer.frame = bounds
        let guidePath = UIBezierPath()
        guidePath.move(to: CGPoint(x: bounds.midX, y: 12)); guidePath.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY - 12))
        guidePath.move(to: CGPoint(x: 12, y: bounds.midY)); guidePath.addLine(to: CGPoint(x: bounds.maxX - 12, y: bounds.midY))
        guides.path = guidePath.cgPath
    }

    private func applyColors() {
        layer.borderColor = Design.Color.separator.resolvedColor(with: traitCollection).cgColor
        guides.strokeColor = Design.Color.separator.resolvedColor(with: traitCollection).cgColor
        inkLayer.strokeColor = Design.Color.textPrimary.resolvedColor(with: traitCollection).cgColor
    }

    // MARK: Editing

    var canUndo: Bool { !ink.strokes.isEmpty }

    func undoLastStroke() {
        guard !ink.strokes.isEmpty else { return }
        ink.strokes.removeLast()
        redraw()
        onInkChange?(ink)
    }

    func clear() {
        guard !ink.strokes.isEmpty || currentStroke != nil else { return }
        ink = HandwritingInk()
        currentStroke = nil
        activeTouch = nil
        redraw()
        onInkChange?(ink)
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, ink.strokes.count < HandwritingInk.maximumStrokes, let touch = touches.first else { return }
        activeTouch = touch
        currentStroke = [InkPoint(location: clamped(touch.location(in: self)))]
        redraw()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch), var stroke = currentStroke else { return }
        // Coalesced touches keep the curve of a fast stroke that the display rate alone would turn into a polygon.
        for sample in event?.coalescedTouches(for: touch) ?? [touch] {
            let point = clamped(sample.location(in: self))
            guard let last = stroke.last?.location, hypot(point.x - last.x, point.y - last.y) >= minimumStep,
                  stroke.count < HandwritingInk.maximumPointsPerStroke else { continue }
            stroke.append(InkPoint(location: point))
        }
        currentStroke = stroke
        redraw()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        finishStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // The system took the touch away (a call, a gesture): half a stroke would be misread, so it is dropped.
        guard let touch = activeTouch, touches.contains(touch) else { return }
        activeTouch = nil
        currentStroke = nil
        redraw()
    }

    private func finishStroke() {
        defer {
            activeTouch = nil
            currentStroke = nil
            redraw()
        }
        guard let stroke = currentStroke else { return }
        // A tap is not a line; keeping it would turn a stray touch into a "stroke" that changes the reading.
        guard stroke.count >= 2 else { return }
        ink.strokes.append(stroke)
        onInkChange?(ink)
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), bounds.width), y: min(max(point.y, 0), bounds.height))
    }

    private func redraw() {
        let path = UIBezierPath()
        for stroke in ink.strokes + (currentStroke.map { [$0] } ?? []) {
            guard let first = stroke.first else { continue }
            path.move(to: first.location)
            if stroke.count == 1 { path.addLine(to: first.location); continue }
            // Quadratic curves through the midpoints round off the sampling without moving the line off the finger.
            for index in 1..<stroke.count {
                let current = stroke[index].location
                let previous = stroke[index - 1].location
                path.addQuadCurve(to: CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2), controlPoint: previous)
            }
            if let last = stroke.last { path.addLine(to: last.location) }
        }
        inkLayer.path = path.cgPath
    }
}
