import UIKit

/// One Daily Radar card, read in the app: the server's title and summary, its Japanese expressions with whatever reading,
/// meaning and example the server gave, and its usage note. Nothing is added; a missing field is simply not shown.
final class DailyRadarCardViewController: BaseViewController {
    private let item: DailyRadarItem
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    init(item: DailyRadarItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    func subscribe() {}

    private func label(_ text: String, style: Design.TextRole, color: UIColor? = nil, identifier: String? = nil) -> UILabel {
        let label = UILabel()
        label.apply(style)
        label.numberOfLines = 0
        label.text = text
        if let color { label.textColor = color }
        label.accessibilityIdentifier = identifier
        return label
    }

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        title = item.moduleTitle.isEmpty ? NSLocalizedString("Daily Radar", comment: "Title of a Daily Radar card screen") : item.moduleTitle
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.accessibilityIdentifier = "radar_card_screen"
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Design.Spacing.l),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter)
        ])

        let heading = label(item.title, style: .headword, identifier: "radar_card_title")
        heading.font = Design.TextRole.weighted(.title2, weight: .semibold)
        heading.accessibilityTraits = .header
        stack.addArrangedSubview(heading)
        let meta = [item.level, item.minutes.map { String.localizedStringWithFormat(NSLocalizedString("%lld minutes", comment: ""), $0) }]
            .compactMap { $0 }.joined(separator: " · ")
        if !meta.isEmpty { stack.addArrangedSubview(label(meta, style: .metadata)) }
        if let summary = item.summary { stack.addArrangedSubview(label(summary, style: .meaning)) }

        stack.addArrangedSubview(label(NSLocalizedString("JAPANESE TO USE", comment: "Daily Radar card: heading of its Japanese expressions"),
                                       style: .eyebrow, color: Design.Color.accent))
        for (index, expression) in item.expressions.enumerated() {
            let column = UIStackView()
            column.axis = .vertical
            column.spacing = Design.Spacing.xs
            column.addArrangedSubview(label(expression.japanese, style: .headword, identifier: "radar_expression_\(index)"))
            if let reading = expression.reading, reading != expression.japanese { column.addArrangedSubview(label(reading, style: .reading)) }
            if let meaning = expression.meaning { column.addArrangedSubview(label(meaning, style: .meaning)) }
            if let example = expression.example {
                column.addArrangedSubview(label(example, style: .meaning))
                if let exampleMeaning = expression.exampleMeaning { column.addArrangedSubview(label(exampleMeaning, style: .metadata)) }
            }
            let card = wrapCard(column)
            card.isAccessibilityElement = true
            card.accessibilityLabel = [expression.japanese, expression.reading, expression.meaning, expression.example, expression.exampleMeaning]
                .compactMap { $0 }.joined(separator: ". ")
            stack.addArrangedSubview(card)
        }
        if let note = item.usageNote {
            stack.addArrangedSubview(label(NSLocalizedString("HOW IT IS USED", comment: "Daily Radar card: heading of its usage note"),
                                           style: .eyebrow, color: Design.Color.accent))
            stack.addArrangedSubview(wrapCard(label(note, style: .meaning)))
        }
        if let reason = item.reason { stack.addArrangedSubview(label(reason, style: .metadata)) }
    }

    private func wrapCard(_ content: UIView) -> UIView {
        let container = UIView()
        container.applyCardSurface(radius: Design.Radius.card)
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: Design.Spacing.l),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Design.Spacing.l),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Design.Spacing.l),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Design.Spacing.l)
        ])
        return container
    }
}
