import UIKit

/// One activity at a time. Draws the presenter's screen; the choice, the reveal and the saving all live in the presenter.
final class LessonPracticeViewController: BaseVC {
    var presenter: LessonPracticePresenterInterface!

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    /// What a table row shows; rebuilt from the presenter's screen on every change.
    private enum Row {
        case text(String, secondary: String?, role: Design.TextRole)
        case option(index: Int, PracticeOptionState)
        case error(String)
        case action(title: String, identifier: String, enabled: Bool, handler: () -> Void)
        case status(String, secondary: String?)
    }

    private struct Section {
        let title: String?
        let rows: [Row]
    }

    private var sections: [Section] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        tableView.accessibilityIdentifier = "lesson_practice_table"
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        presenter.onChange = { [weak self] in self?.render() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        presenter.viewDidLoad()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.cancelLoading()
    }

    private func render() {
        if !presenter.title.isEmpty { title = presenter.title }
        sections = presenter.errorMessage.map { [Section(title: nil, rows: [.error($0)])] } ?? []
        switch presenter.screen {
        case .question(let state): sections += questionSections(state)
        case .summary(let summary): sections += summarySections(summary)
        }
        tableView.reloadData()
    }

    private func questionSections(_ state: PracticeQuestionState) -> [Section] {
        var prompt: [Row] = []
        if let scenario = state.scenario { prompt.append(.text(scenario, secondary: nil, role: .metadata)) }
        if let stimulus = state.stimulus { prompt.append(.text(stimulus, secondary: nil, role: .headword)) }
        prompt.append(.text(state.prompt, secondary: state.promptTranslation, role: .explanation))
        var result = [
            Section(title: String(format: NSLocalizedString("Question %lld of %lld", comment: "Lesson practice progress"), state.index + 1, state.total), rows: prompt),
            Section(title: nil, rows: state.options.enumerated().map { .option(index: $0.offset, $0.element) })
        ]
        if state.isAnswered {
            var after: [Row] = []
            if let explanation = state.explanation {
                after.append(.text(NSLocalizedString("Explanation", comment: "Lesson practice"), secondary: explanation, role: .metadata))
            }
            let title = state.isLast ? NSLocalizedString("Finish", comment: "Lesson practice") : NSLocalizedString("Next question", comment: "Lesson practice")
            after.append(.action(title: title, identifier: "practice_next", enabled: true) { [weak self] in self?.presenter.next() })
            result.append(Section(title: nil, rows: after))
        }
        return result
    }

    private func summarySections(_ summary: PracticeSummary) -> [Section] {
        var rows: [Row] = [.text(NSLocalizedString("Lesson finished", comment: "Lesson practice"),
                                 secondary: String(format: NSLocalizedString("%lld of %lld correct", comment: "Lesson practice score"), summary.correct, summary.total),
                                 role: .title)]
        var syncRows: [Row] = []
        let save: () -> Void = { [weak self] in self?.presenter.retrySync() }
        switch summary.server {
        case .notApplicable:
            syncRows.append(.status(NSLocalizedString("Saved on this device. Sign in to save progress to your account.", comment: "Lesson practice"), secondary: nil))
        case .sending:
            syncRows.append(.status(NSLocalizedString("Saving to your account…", comment: "Lesson practice"), secondary: nil))
        case .confirmed:
            syncRows.append(.status(NSLocalizedString("Saved to your account.", comment: "Lesson practice"), secondary: nil))
        case .notSent:
            syncRows.append(.status(NSLocalizedString("Finished on this device. Not saved to your account yet.", comment: "Lesson practice"), secondary: nil))
            syncRows.append(.action(title: NSLocalizedString("Save to your account", comment: "Lesson practice"), identifier: "practice_sync", enabled: true, handler: save))
        case .failed(let message):
            syncRows.append(.status(NSLocalizedString("Finished on this device, but not saved to your account.", comment: "Lesson practice"), secondary: message))
            syncRows.append(.action(title: NSLocalizedString("Try again", comment: ""), identifier: "practice_sync", enabled: true, handler: save))
        case .unknown(let message):
            syncRows.append(.status(NSLocalizedString("We can't tell whether your account was updated.", comment: "Lesson practice"), secondary: message))
            syncRows.append(.action(title: NSLocalizedString("Try again", comment: ""), identifier: "practice_sync", enabled: true, handler: save))
        }
        rows.append(.action(title: NSLocalizedString("Back to lesson", comment: "Lesson practice"), identifier: "practice_back", enabled: true) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        })
        return [Section(title: nil, rows: [rows[0]]), Section(title: nil, rows: syncRows), Section(title: nil, rows: [rows[1]])]
    }
}

extension LessonPracticeViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].title }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        content.textToSecondaryTextVerticalPadding = Design.Spacing.xs
        cell.backgroundColor = Design.Color.surface
        let highlight = UIView()
        highlight.backgroundColor = Design.Color.highlight
        cell.selectedBackgroundView = highlight
        cell.accessoryView = nil
        cell.isAccessibilityElement = false
        cell.accessibilityIdentifier = nil
        cell.accessibilityLabel = nil
        cell.accessibilityTraits = .staticText
        cell.selectionStyle = .none
        switch sections[indexPath.section].rows[indexPath.row] {
        case .text(let text, let secondary, let role):
            content.text = text
            content.textProperties.apply(role)
            content.secondaryText = secondary
            content.secondaryTextProperties.apply(.explanation)
        case .status(let text, let secondary):
            content.text = text
            content.textProperties.apply(.explanation)
            content.secondaryText = secondary
            content.secondaryTextProperties.apply(.metadata)
        case .error(let message):
            content.text = message
            content.textProperties.apply(.explanation)
            content.textProperties.color = Design.Color.error
            content.image = UIImage(systemName: "exclamationmark.triangle")
            content.imageProperties.tintColor = Design.Color.error
        case .action(let title, let identifier, let enabled, _):
            content.text = title
            content.textProperties.apply(.title)
            content.textProperties.color = enabled ? Design.Color.accent : Design.Color.textSecondary
            content.textProperties.alignment = .center
            cell.selectionStyle = enabled ? .default : .none
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = title
            cell.accessibilityTraits = enabled ? .button : [.button, .notEnabled]
            cell.accessibilityIdentifier = identifier
        case .option(let index, let option):
            content.text = "\(option.key)   \(option.text)"
            content.textProperties.apply(.headword)
            content.secondaryText = option.rationale
            content.secondaryTextProperties.apply(.explanation)
            let outcomeLabel: String?
            switch option.outcome {
            case .correct: (cell.accessoryView, outcomeLabel) = (Self.badge("checkmark.circle.fill", Design.Color.success), NSLocalizedString("Correct", comment: "Lesson practice outcome"))
            case .incorrect: (cell.accessoryView, outcomeLabel) = (Self.badge("xmark.circle.fill", Design.Color.error), NSLocalizedString("Incorrect", comment: "Lesson practice outcome"))
            case .correctAnswer: (cell.accessoryView, outcomeLabel) = (Self.badge("checkmark.circle", Design.Color.success), NSLocalizedString("Correct answer", comment: "Lesson practice outcome"))
            case .none: outcomeLabel = nil
            }
            let answered = presenterIsAnswered
            cell.selectionStyle = answered ? .none : .default
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = [option.key, option.text, outcomeLabel, option.rationale].compactMap { $0 }.joined(separator: ". ")
            cell.accessibilityTraits = answered ? .staticText : .button
            cell.accessibilityIdentifier = "practice_option_\(index)"
        }
        cell.contentConfiguration = content
        return cell
    }

    private var presenterIsAnswered: Bool {
        if case .question(let state) = presenter.screen { return state.isAnswered }
        return true
    }

    private static func badge(_ symbol: String, _ color: UIColor) -> UIView {
        let view = UIImageView(image: UIImage(systemName: symbol))
        view.tintColor = color
        view.sizeToFit()
        return view
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section].rows[indexPath.row] {
        case .option(let index, _): presenter.selectOption(at: index)
        case .action(_, _, let enabled, let handler): if enabled { handler() }
        default: break
        }
    }
}
