import UIKit

/// Reads one lesson: the server's text in reading order, one table section per kind of material. Draws the presenter's state.
final class LessonReaderViewController: BaseVC {
    var presenter: LessonReaderPresenterInterface!

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let stateView = StateView()
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let offlineLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.onChange = { [weak self] in self?.render() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        presenter.viewDidLoad()
        render()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.cancelLoading()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeHeaderToFit()
    }

    private func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "entry")
        tableView.estimatedRowHeight = 72
        tableView.rowHeight = UITableView.automaticDimension
        tableView.accessibilityIdentifier = "lesson_reader"
        tableView.backgroundView = stateView
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        stateView.accessibilityIdentifier = "lesson_reader_status"

        titleLabel.apply(.headword)
        titleLabel.font = Design.TextRole.weighted(.title2, weight: .semibold)
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        titleLabel.accessibilityIdentifier = "lesson_reader_title"
        metaLabel.apply(.metadata)
        offlineLabel.apply(.metadata)
        offlineLabel.numberOfLines = 0
        offlineLabel.textColor = Design.Color.accent
        offlineLabel.accessibilityIdentifier = "lesson_reader_offline"
        let stack = UIStackView(arrangedSubviews: [titleLabel, metaLabel, offlineLabel])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        headerView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: Design.Spacing.s, leading: Design.Spacing.gutter, bottom: Design.Spacing.m, trailing: Design.Spacing.gutter)
        headerView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: headerView.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: headerView.layoutMarginsGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.trailingAnchor)
        ])
        tableView.tableHeaderView = headerView
    }

    private func sizeHeaderToFit() {
        let width = tableView.bounds.width
        guard width > 0 else { return }
        headerView.frame.size.width = width
        headerView.layoutIfNeeded()
        let height = headerView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        stateView.topContentInset = height + Design.Spacing.s
        guard abs(headerView.frame.size.height - height) > 0.5 || abs(headerView.frame.size.width - width) > 0.5 else { return }
        headerView.frame.size = CGSize(width: width, height: height)
        tableView.tableHeaderView = headerView
    }

    private func render() {
        titleLabel.text = presenter.title
        metaLabel.text = presenter.minutes.map { String(format: NSLocalizedString("%lld min", comment: ""), $0) }
        metaLabel.isHidden = metaLabel.text == nil
        offlineLabel.text = presenter.isFromCache
            ? NSLocalizedString("You're offline. This is the copy saved on this device.", comment: "Lesson reader banner") : nil
        offlineLabel.isHidden = offlineLabel.text == nil
        switch presenter.state {
        case .idle, .loading:
            stateView.configure(.loading(NSLocalizedString("Loading…", comment: "")), onRetry: nil)
        case .failed(let message):
            stateView.configure(.error(message: message, retryTitle: NSLocalizedString("Retry", comment: "")),
                                onRetry: { [weak self] in self?.presenter.retry() })
        case .loaded:
            break
        }
        stateView.isHidden = presenter.state == .loaded
        if presenter.canShadow, navigationItem.rightBarButtonItem == nil {
            let item = UIBarButtonItem(image: UIImage(systemName: "waveform.and.mic"),
                                       primaryAction: UIAction { [weak self] _ in self?.presenter.showShadowing() })
            item.accessibilityLabel = NSLocalizedString("Shadowing", comment: "Lesson: repeat the example sentences aloud")
            item.accessibilityIdentifier = "lesson_shadowing"
            navigationItem.rightBarButtonItem = item
        } else if !presenter.canShadow {
            navigationItem.rightBarButtonItem = nil
        }
        tableView.reloadData()
        view.setNeedsLayout()
    }

    private var showsPractice: Bool { presenter.state == .loaded && presenter.practiceActivityCount > 0 }
}

extension LessonReaderViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { presenter.sections.count + (showsPractice ? 1 : 0) }

    private func isVocabulary(_ section: Int) -> Bool {
        section < presenter.sections.count && presenter.sections[section].kind == .vocabulary
    }

    /// The vocabulary section ends with one more row that saves every word.
    private func hasSaveAllRow(_ section: Int) -> Bool { isVocabulary(section) && presenter.canSaveWords }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section < presenter.sections.count ? presenter.sections[section].entries.count + (hasSaveAllRow(section) ? 1 : 0) : 1
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard isVocabulary(indexPath.section), indexPath.row < presenter.sections[indexPath.section].entries.count, presenter.canSaveWords else { return nil }
        let action = UIContextualAction(style: .normal, title: NSLocalizedString("Save", comment: "Save a word to a deck")) { [weak self] _, _, done in
            self?.presenter.saveWord(at: indexPath.row)
            done(true)
        }
        action.backgroundColor = Design.Color.accent
        return UISwipeActionsConfiguration(actions: [action])
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section < presenter.sections.count ? presenter.sections[section].title : NSLocalizedString("Practice", comment: "")
    }

    static func statusText(_ status: LessonPracticeStatus) -> String? {
        switch status {
        case .notStarted: return nil
        case .inProgress(let answered, let total): return String(format: NSLocalizedString("%lld of %lld answered", comment: "Lesson practice progress"), answered, total)
        case .completed: return NSLocalizedString("Completed", comment: "Lesson practice status")
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section >= presenter.sections.count {
            presenter.showPractice()
        } else if hasSaveAllRow(indexPath.section), indexPath.row == presenter.sections[indexPath.section].entries.count {
            presenter.saveAllWords()
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "entry", for: indexPath)
        cell.accessoryType = .none
        cell.isAccessibilityElement = false
        cell.accessibilityCustomActions = nil
        var content = cell.defaultContentConfiguration()
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        content.textToSecondaryTextVerticalPadding = Design.Spacing.xs
        cell.backgroundColor = Design.Color.surface
        let highlight = UIView()
        highlight.backgroundColor = Design.Color.highlight
        cell.selectedBackgroundView = highlight
        cell.selectionStyle = .none
        cell.accessibilityTraits = .staticText
        if indexPath.section >= presenter.sections.count {
            // Practice: the server's activities, with where the learner stands on this device.
            content.image = UIImage(systemName: "checklist")
            content.imageProperties.tintColor = Design.Color.accent
            content.text = NSLocalizedString("Practice", comment: "")
            content.textProperties.apply(.title)
            content.textProperties.color = Design.Color.accent
            let count = String(format: NSLocalizedString("%lld activities", comment: ""), presenter.practiceActivityCount)
            content.secondaryText = [Self.statusText(presenter.practiceStatus), count].compactMap { $0 }.joined(separator: " · ")
            content.secondaryTextProperties.apply(.metadata)
            cell.selectionStyle = .default
            cell.accessoryType = .disclosureIndicator
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = [content.text, content.secondaryText].compactMap { $0 }.joined(separator: ". ")
            cell.accessibilityTraits = .button
            cell.accessibilityIdentifier = "lesson_practice"
            cell.contentConfiguration = content
            return cell
        }
        let section = presenter.sections[indexPath.section]
        if indexPath.row >= section.entries.count {
            content.image = UIImage(systemName: "plus.rectangle.on.rectangle")
            content.imageProperties.tintColor = Design.Color.accent
            content.text = NSLocalizedString("Save all words to a deck", comment: "Lesson reader")
            content.textProperties.apply(.title)
            content.textProperties.color = Design.Color.accent
            cell.selectionStyle = .default
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = content.text
            cell.accessibilityTraits = .button
            cell.accessibilityIdentifier = "lesson_save_all_words"
            cell.contentConfiguration = content
            return cell
        }
        let entry = section.entries[indexPath.row]
        if let headline = entry.headline {
            content.text = headline
            content.textProperties.apply(section.kind == .context ? .explanation : .headword)
            content.secondaryText = [entry.reading, entry.body, entry.note].compactMap { $0 }.joined(separator: "\n")
            content.secondaryTextProperties.apply(.explanation)
        } else if let label = entry.label {
            content.text = label
            content.textProperties.apply(.metadata)
            content.secondaryText = entry.body
            content.secondaryTextProperties.apply(.explanation)
        } else {
            content.text = entry.body
            content.textProperties.apply(.explanation)
        }
        cell.accessibilityIdentifier = "lesson_entry_\(indexPath.section)_\(indexPath.row)"
        if section.kind == .vocabulary, presenter.canSaveWords {
            // One element per word, with a VoiceOver action in place of the swipe.
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = [entry.headline, entry.reading, entry.body].compactMap { $0 }.joined(separator: ". ")
            let index = indexPath.row
            cell.accessibilityCustomActions = [UIAccessibilityCustomAction(name: NSLocalizedString("Save to a deck", comment: "Lesson reader")) { [weak self] _ in
                self?.presenter.saveWord(at: index)
                return true
            }]
        } else {
            cell.accessibilityCustomActions = nil
        }
        cell.contentConfiguration = content
        return cell
    }
}
