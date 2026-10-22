import UIKit

/// Search results as a grid of thumbnails. Tapping one previews it full size; only "Use this picture" saves it.
final class PictureSearchViewController: BaseViewController, PictureSearchViewInterface {
    var presenter: PictureSearchPresenterInterface!

    private let searchController = UISearchController(searchResultsController: nil)
    private let stateView = StateView()
    private var collectionView: UICollectionView!
    private var pictures: [PictureSuggestion] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }

    func setupUI() {
        title = NSLocalizedString("Find a picture", comment: "")
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        let close = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.presenter.close() })
        close.accessibilityIdentifier = "picture_search_close"
        navigationItem.leftBarButtonItem = close

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.text = presenter.initialTerm
        searchController.searchBar.placeholder = NSLocalizedString("Search pictures", comment: "")
        searchController.searchBar.returnKeyType = .search
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.delegate = self
        searchController.searchBar.accessibilityIdentifier = "picture_search_field"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        let layout = UICollectionViewCompositionalLayout { _, environment in
            let columns = environment.container.effectiveContentSize.width > 600 ? 4 : 2
            let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1.0 / CGFloat(columns)), heightDimension: .estimated(130)))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(130)),
                                                           repeatingSubitem: item, count: columns)
            group.interItemSpacing = .fixed(Design.Spacing.m)
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = Design.Spacing.m
            section.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: Design.Spacing.gutter, bottom: Design.Spacing.l, trailing: Design.Spacing.gutter)
            return section
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.keyboardDismissMode = .onDrag
        collectionView.accessibilityIdentifier = "picture_search_results"
        collectionView.register(PictureThumbnailCell.self, forCellWithReuseIdentifier: PictureThumbnailCell.reuseIdentifier)
        collectionView.backgroundView = stateView
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        stateView.accessibilityIdentifier = "picture_search_state"
    }

    func subscribe() {}

    // MARK: PictureSearchViewInterface

    func render(_ state: PictureSearchState) {
        pictures = []
        stateView.isHidden = false
        switch state {
        case .needsTerm:
            stateView.configure(.empty(title: NSLocalizedString("What should the picture show?", comment: ""),
                                       message: NSLocalizedString("Type a word, such as the meaning of the card, then search.", comment: "")))
        case .signInRequired:
            stateView.configure(.call(symbol: "person.crop.circle", title: NSLocalizedString("Sign in to search pictures", comment: ""),
                                      message: NSLocalizedString("Picture search uses your account. You can still add a picture from Photos or a web address.", comment: ""),
                                      actionTitle: NSLocalizedString("Sign In", comment: "")),
                                onRetry: { [weak self] in self?.presenter.signIn() })
        case .loading:
            stateView.configure(.loading(NSLocalizedString("Searching…", comment: "")))
        case .results(let found):
            pictures = found
            stateView.isHidden = true
        case .empty:
            stateView.configure(.empty(title: NSLocalizedString("No pictures found", comment: ""),
                                       message: NSLocalizedString("Try a simpler or different word.", comment: "")))
        case .unavailable:
            stateView.configure(.empty(title: NSLocalizedString("Picture search isn't available yet", comment: ""),
                                       message: NSLocalizedString("The server has no picture source set up. You can still add a picture from Photos or a web address.", comment: "")))
        case .failed(let message):
            stateView.configure(.error(message: message, retryTitle: NSLocalizedString("Try again", comment: "")),
                                onRetry: { [weak self] in self?.presenter.search(self?.searchController.searchBar.text ?? "") })
        }
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)
    }
}

extension PictureSearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        presenter.search(searchBar.text ?? "")
    }
}

extension PictureSearchViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { pictures.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PictureThumbnailCell.reuseIdentifier, for: indexPath) as! PictureThumbnailCell
        cell.configure(pictures[indexPath.item], number: indexPath.item + 1)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let picture = pictures[indexPath.item]
        let preview = PicturePreviewViewController(picture: picture) { [weak self] in self?.presenter.select(picture) }
        navigationController?.pushViewController(preview, animated: true)
    }
}

final class PictureThumbnailCell: UICollectionViewCell {
    static let reuseIdentifier = "picture_thumbnail_cell"

    private let pictureView = CardImageView()
    private let sourceLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        pictureView.isCompact = true
        pictureView.translatesAutoresizingMaskIntoConstraints = false
        pictureView.isAccessibilityElement = false
        sourceLabel.apply(.metadata)
        sourceLabel.textColor = Design.Color.textSecondary
        sourceLabel.numberOfLines = 1
        sourceLabel.isAccessibilityElement = false
        let stack = UIStackView(arrangedSubviews: [pictureView, sourceLabel])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pictureView.heightAnchor.constraint(equalTo: pictureView.widthAnchor, multiplier: 0.75)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func prepareForReuse() {
        super.prepareForReuse()
        pictureView.cancel()
    }

    func configure(_ picture: PictureSuggestion, number: Int) {
        pictureView.setReference(picture.thumbnailURL.absoluteString)
        sourceLabel.text = picture.source
        accessibilityLabel = String(format: NSLocalizedString("Picture %lld", comment: ""), number)
        accessibilityValue = picture.source
    }
}

/// Full-size look at one result, with where it comes from, before it is saved to the card.
final class PicturePreviewViewController: UIViewController {
    private let picture: PictureSuggestion
    private let onUse: () -> Void
    private let pictureView = CardImageView()

    init(picture: PictureSuggestion, onUse: @escaping () -> Void) {
        self.picture = picture
        self.onUse = onUse
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Preview", comment: "")
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        pictureView.translatesAutoresizingMaskIntoConstraints = false
        pictureView.accessibilityLabel = NSLocalizedString("Picture preview", comment: "")
        pictureView.setReference(picture.imageURL.absoluteString)

        let source = UILabel()
        source.apply(.metadata)
        source.textColor = Design.Color.textSecondary
        source.text = picture.source.isEmpty ? nil : String(format: NSLocalizedString("Source: %@", comment: "Where a picture comes from"), picture.source)

        var configuration = Design.Button.primary(title: NSLocalizedString("Use this picture", comment: ""))
        configuration.image = UIImage(systemName: "checkmark")
        configuration.imagePadding = Design.Spacing.s
        let use = UIButton(configuration: configuration)
        use.accessibilityIdentifier = "use_picture"
        use.addAction(UIAction { [weak self] _ in self?.onUse() }, for: .primaryActionTriggered)

        let stack = UIStackView(arrangedSubviews: [source, use])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pictureView)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            pictureView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Design.Spacing.l),
            pictureView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            pictureView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            pictureView.bottomAnchor.constraint(equalTo: stack.topAnchor, constant: -Design.Spacing.l),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Design.Spacing.l)
        ])
    }
}
