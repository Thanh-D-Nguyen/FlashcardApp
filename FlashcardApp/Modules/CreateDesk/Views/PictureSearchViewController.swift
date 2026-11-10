import UIKit

/// Search results as a grid of thumbnails. Tapping one uses it for the card straight away and closes the search.
final class PictureSearchViewController: BaseViewController, PictureSearchViewInterface {
    var presenter: PictureSearchPresenterInterface!

    private let searchController = UISearchController(searchResultsController: nil)
    private let stateView = StateView()
    private var collectionView: UICollectionView!
    private var pictures: [PictureSuggestion] = []
    private let busyView = UIActivityIndicatorView(style: .large)

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
        busyView.hidesWhenStopped = true
        busyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(busyView)
        NSLayoutConstraint.activate([
            busyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            busyView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
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

extension PictureSearchViewController {
    func setSelecting(_ selecting: Bool) {
        selecting ? busyView.startAnimating() : busyView.stopAnimating()
        // Saving the picture takes a moment: a second tap must not choose another one meanwhile.
        collectionView.isUserInteractionEnabled = !selecting
        collectionView.alpha = selecting ? 0.5 : 1
    }

    func showSelectionFailure(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
        present(alert, animated: true)
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
        presenter.select(pictures[indexPath.item])
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
        pictureView.setReference(picture.imageURL.absoluteString)
        sourceLabel.text = picture.attribution.author ?? picture.source
        accessibilityLabel = String(format: NSLocalizedString("Picture %lld", comment: ""), number)
        accessibilityValue = picture.attribution.creditLine
    }
}
