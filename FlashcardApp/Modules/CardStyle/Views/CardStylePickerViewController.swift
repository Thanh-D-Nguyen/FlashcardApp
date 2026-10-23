import UIKit

/// The choice of card style: a grid of previews, each the real card surface with a sample word. Tapping one applies
/// it immediately (the card behind the sheet changes); the sheet closes with the Done button or a swipe.
final class CardStylePickerViewController: BaseViewController, CardStylePickerViewInterface {
    var presenter: CardStylePickerPresenterInterface!

    private var collectionView: UICollectionView!
    private var state = CardStylePickerState(options: [], selectedSlug: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    func setupUI() {
        title = NSLocalizedString("Card style", comment: "")
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        let done = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.presenter.close() })
        done.accessibilityIdentifier = "card_style_done"
        navigationItem.rightBarButtonItem = done

        let layout = UICollectionViewCompositionalLayout { _, environment in
            let columns = environment.traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 1 : 2
            let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0 / CGFloat(columns)), heightDimension: .estimated(190))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(190)),
                repeatingSubitem: NSCollectionLayoutItem(layoutSize: size), count: columns)
            group.interItemSpacing = .fixed(Design.Spacing.l)
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = Design.Spacing.l
            section.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.s, leading: Design.Spacing.gutter, bottom: Design.Spacing.xl, trailing: Design.Spacing.gutter)
            let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)),
                                                                     elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            section.boundarySupplementaryItems = [header]
            return section
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.accessibilityIdentifier = "card_style_grid"
        collectionView.register(CardStyleCell.self, forCellWithReuseIdentifier: CardStyleCell.reuseIdentifier)
        collectionView.register(CardStyleIntroView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: CardStyleIntroView.reuseIdentifier)
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor), collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor), collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func subscribe() {}

    func render(_ newState: CardStylePickerState) {
        state = newState
        guard isViewLoaded else { return }
        collectionView.reloadData()
    }
}

extension CardStylePickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { state.options.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CardStyleCell.reuseIdentifier, for: indexPath) as! CardStyleCell // swiftlint:disable:this force_cast
        let option = state.options[indexPath.item]
        cell.configure(option: option, isSelected: option.slug == state.selectedSlug)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CardStyleIntroView.reuseIdentifier, for: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        presenter.select(state.options[indexPath.item])
    }
}

/// One sentence under the title: what a style changes.
private final class CardStyleIntroView: UICollectionReusableView {
    static let reuseIdentifier = "CardStyleIntroView"
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.apply(.metadata)
        label.text = NSLocalizedString("Choose a readable card style that suits your study routine.", comment: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.xs),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.s),
            label.leadingAnchor.constraint(equalTo: leadingAnchor), label.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

private final class CardStyleCell: UICollectionViewCell {
    static let reuseIdentifier = "CardStyleCell"

    private let preview = CardSurfaceView()
    private let wordLabel = UILabel()
    private let readingLabel = UILabel()
    private let accentBar = UIView()
    private let ring = UIView()
    private let badge = UIImageView()
    private let nameLabel = UILabel()
    private let summaryLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let sample = UIStackView(arrangedSubviews: [wordLabel, readingLabel, accentBar])
        sample.axis = .vertical
        sample.alignment = .center
        sample.spacing = Design.Spacing.xs
        sample.translatesAutoresizingMaskIntoConstraints = false
        wordLabel.text = "勉強"
        readingLabel.text = "べんきょう"
        wordLabel.isAccessibilityElement = false
        readingLabel.isAccessibilityElement = false
        accentBar.layer.cornerRadius = 1
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.addSubview(sample)

        ring.isUserInteractionEnabled = false
        ring.layer.borderWidth = 3
        ring.layer.cornerCurve = .continuous
        ring.translatesAutoresizingMaskIntoConstraints = false
        preview.addSubview(ring)
        badge.image = UIImage(systemName: "checkmark.circle.fill")
        badge.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.isAccessibilityElement = false

        nameLabel.apply(.title)
        summaryLabel.apply(.metadata)
        let column = UIStackView(arrangedSubviews: [preview, nameLabel, summaryLabel])
        column.axis = .vertical
        column.spacing = Design.Spacing.xs
        column.setCustomSpacing(Design.Spacing.s, after: preview)
        column.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(column)
        preview.addSubview(badge)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: contentView.topAnchor), column.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            column.leadingAnchor.constraint(equalTo: contentView.leadingAnchor), column.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            preview.heightAnchor.constraint(equalToConstant: 104),
            sample.centerXAnchor.constraint(equalTo: preview.centerXAnchor), sample.centerYAnchor.constraint(equalTo: preview.centerYAnchor),
            sample.leadingAnchor.constraint(greaterThanOrEqualTo: preview.leadingAnchor, constant: Design.Spacing.m),
            accentBar.widthAnchor.constraint(equalToConstant: 28), accentBar.heightAnchor.constraint(equalToConstant: 2),
            ring.topAnchor.constraint(equalTo: preview.topAnchor), ring.bottomAnchor.constraint(equalTo: preview.bottomAnchor),
            ring.leadingAnchor.constraint(equalTo: preview.leadingAnchor), ring.trailingAnchor.constraint(equalTo: preview.trailingAnchor),
            badge.topAnchor.constraint(equalTo: preview.topAnchor, constant: Design.Spacing.s),
            badge.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: -Design.Spacing.s)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(option: CardStyleOption, isSelected: Bool) {
        preview.apply(style: option.style)
        let style = option.style
        wordLabel.font = style?.font(textStyle: .title1, weight: .semibold, maximum: 40) ?? UIFont.preferredFont(forTextStyle: .title1).withWeight(.semibold)
        readingLabel.font = style?.font(textStyle: .footnote, maximum: 20) ?? UIFont.preferredFont(forTextStyle: .footnote)
        wordLabel.adjustsFontForContentSizeCategory = true
        readingLabel.adjustsFontForContentSizeCategory = true
        wordLabel.textColor = style?.foregroundColor ?? Design.TextRole.term.color
        readingLabel.textColor = style?.mutedColor ?? Design.Color.textSecondary
        accentBar.backgroundColor = style?.accentColor ?? Design.Color.accent
        nameLabel.text = option.title
        summaryLabel.text = option.summary
        ring.isHidden = !isSelected
        ring.layer.borderColor = Design.Color.accent.cgColor
        ring.layer.cornerRadius = style?.cornerRadius ?? Design.Radius.panel
        badge.isHidden = !isSelected
        badge.tintColor = Design.Color.accent
        accessibilityLabel = "\(option.title). \(option.summary)"
        accessibilityTraits = isSelected ? [.button, .selected] : .button
        accessibilityIdentifier = "card_style_\(option.slug ?? "default")"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The ring is a CGColor: refresh it when the appearance changes.
        ring.layer.borderColor = Design.Color.accent.cgColor
    }
}
