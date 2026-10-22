//
//  CreateDeskViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//  
//

import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Create or edit a deck. Details first, then the cards; everything optional (reading, note, picture) is
/// one tap away but out of the way. Presented in a navigation controller, so the bars are the system's glass.
final class CreateDeskViewController: BaseViewController, CreateDeskViewInterface {
    var presenter: CreateDeskPresenterInterface!

    private enum Section: Int, CaseIterable { case details, cards }
    private enum DetailRow: Int, CaseIterable { case name, description, direction }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let accessory = EditorAccessoryView()
    private var issues: [DeckValidationIssue] = []
    private var revealed: [String: Set<CardField>] = [:]
    private var focusedCard: (id: String, field: CardField)?
    private var pictureTargetId: String?

    private lazy var closeItem: UIBarButtonItem = {
        let item = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.presenter.close() })
        item.accessibilityIdentifier = "close_deck_editor"
        return item
    }()

    private lazy var saveItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: NSLocalizedString("Save", comment: ""), primaryAction: UIAction { [weak self] _ in
            self?.view.endEditing(true)
            self?.presenter.save()
        })
        item.style = .prominent
        item.accessibilityIdentifier = "save_deck"
        return item
    }()

    private lazy var moreItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: makeMoreMenu())
        item.accessibilityLabel = NSLocalizedString("More", comment: "")
        item.accessibilityIdentifier = "deck_more"
        return item
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.presentationController?.delegate = self
        presenter.viewDidAppear()
    }

    func setupUI() {
        title = presenter.isEditingExistingDeck ? NSLocalizedString("Edit deck", comment: "") : NSLocalizedString("New deck", comment: "")
        view.backgroundColor = Design.Color.background
        navigationItem.leftBarButtonItem = closeItem
        navigationItem.rightBarButtonItems = [saveItem, moreItem]
        navigationItem.largeTitleDisplayMode = .never

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.keyboardDismissMode = .interactive
        tableView.sectionHeaderTopPadding = Design.Spacing.s
        tableView.accessibilityIdentifier = "deck_editor_table"
        tableView.register(TextEntryCell.self, forCellReuseIdentifier: TextEntryCell.reuseIdentifier)
        tableView.register(DeckDirectionCell.self, forCellReuseIdentifier: DeckDirectionCell.reuseIdentifier)
        tableView.register(CardEditorCell.self, forCellReuseIdentifier: CardEditorCell.reuseIdentifier)
        tableView.register(AddCardCell.self, forCellReuseIdentifier: AddCardCell.reuseIdentifier)
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "header")
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "footer")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        accessory.onNext = { [weak self] in self?.focusNextField() }
        accessory.onAddCard = { [weak self] in self?.addCardFromToolbar() }
        accessory.onDismissKeyboard = { [weak self] in self?.view.endEditing(true) }
        accessory.onSelectSuggestion = { [weak self] suggestion in
            guard let self, let focused = self.focusedCard, let index = self.index(ofCard: focused.id) else { return }
            self.presenter.apply(suggestion, toCardAt: index)
            self.accessory.setSuggestions([])
        }
    }

    func subscribe() {}

    // MARK: Index helpers

    private var cardCount: Int { presenter.draft.cards.count }

    private func index(ofCard id: String) -> Int? { presenter.draft.cards.firstIndex { $0.id == id } }

    private func cardIndexPath(_ index: Int) -> IndexPath { IndexPath(row: index, section: Section.cards.rawValue) }

    private func cardCell(at index: Int) -> CardEditorCell? { tableView.cellForRow(at: cardIndexPath(index)) as? CardEditorCell }

    private func problem(forCardAt index: Int) -> String? {
        for issue in issues {
            if case .incompleteCard(let issueIndex, let missingFront) = issue, issueIndex == index {
                return missingFront ? NSLocalizedString("Add a front to this card.", comment: "") : NSLocalizedString("Add a back to this card.", comment: "")
            }
        }
        return nil
    }

    private var nameProblem: String? {
        issues.contains(.nameEmpty) ? NSLocalizedString("Enter a deck name.", comment: "") : nil
    }

    private var cardsFooterProblem: String? {
        if issues.contains(.tooFewCards) {
            return String.localizedStringWithFormat(NSLocalizedString("Add at least %lld cards with a front and a back.", comment: ""), DeckDraft.minimumCards)
        }
        if issues.contains(.tooManyCards) {
            return String.localizedStringWithFormat(NSLocalizedString("A deck can hold up to %lld cards.", comment: ""), DeckDraft.maximumCards)
        }
        return nil
    }

    // MARK: CreateDeskViewInterface

    func reload() {
        tableView.reloadData()
        updateAccessoryPosition()
    }

    func reloadDetails() {
        tableView.reloadRows(at: [IndexPath(row: DetailRow.direction.rawValue, section: Section.details.rawValue)], with: .none)
    }

    func insertCard(at index: Int) {
        tableView.insertRows(at: [cardIndexPath(index)], with: .automatic)
        refreshCardsHeader()
        // The cards around the new one change their number and their "move up/down" availability.
        let neighbours = ((index - 1)..<cardCount).filter { $0 >= 0 && $0 != index }.map(cardIndexPath)
        tableView.reconfigureRows(at: neighbours)
        updateAccessoryPosition()
    }

    func deleteCard(at index: Int) {
        tableView.deleteRows(at: [cardIndexPath(index)], with: .automatic)
        refreshCardsHeader()
        // Row numbers ("Card 3") and the picture/option menus of the cards below are now stale.
        let following = ((index - 1)..<cardCount).filter { $0 >= 0 }.map(cardIndexPath)
        tableView.reconfigureRows(at: following)
        updateAccessoryPosition()
    }

    func moveCard(from: Int, to: Int) {
        tableView.moveRow(at: cardIndexPath(from), to: cardIndexPath(to))
        tableView.reconfigureRows(at: (min(from, to)...max(from, to)).map(cardIndexPath))
    }

    func reloadCard(at index: Int) {
        guard index < cardCount else { return }
        tableView.reconfigureRows(at: [cardIndexPath(index)])
        // A picture (or a revealed field) changes the row's height; re-measure without reloading the row.
        UIView.performWithoutAnimation { tableView.performBatchUpdates(nil) }
    }

    func showIssues(_ newIssues: [DeckValidationIssue], reveal: Bool) {
        issues = newIssues
        refreshProblemsInPlace()
        guard reveal, let first = newIssues.first else { return }
        let target: IndexPath
        switch first {
        case .nameEmpty: target = IndexPath(row: DetailRow.name.rawValue, section: Section.details.rawValue)
        case .incompleteCard(let index, _): target = cardIndexPath(index)
        case .tooFewCards, .tooManyCards: target = IndexPath(row: max(cardCount - 1, 0), section: Section.cards.rawValue)
        }
        tableView.scrollToRow(at: target, at: .middle, animated: true)
        let message = [nameProblem, cardsFooterProblem].compactMap { $0 }.first ?? first.appError.errorDescription ?? ""
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    func setSaving(_ saving: Bool) {
        saveItem.isEnabled = !saving
        closeItem.isEnabled = !saving
        view.isUserInteractionEnabled = !saving
    }

    func setDirty(_ dirty: Bool) {
        // A dirty editor cannot be dismissed by swiping down; the attempt asks what to do instead.
        isModalInPresentation = dirty
        navigationController?.isModalInPresentation = dirty
    }

    func showSuggestions(_ suggestions: [CardSuggestion]) {
        accessory.setSuggestions(focusedCard == nil ? [] : suggestions)
    }

    func focus(cardIndex: Int, field: CardField) {
        guard cardIndex < cardCount else { return }
        let indexPath = cardIndexPath(cardIndex)
        tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.tableView.layoutIfNeeded()
            self.cardCell(at: cardIndex)?.focus(field)
        }
    }

    // MARK: In-place problem refresh (keeps the keyboard up while typing)

    private func refreshProblemsInPlace() {
        for case let cell as TextEntryCell in tableView.visibleCells where cell.textView.accessibilityIdentifier == "deck_name" {
            cell.setProblem(nameProblem)
        }
        for case let cell as CardEditorCell in tableView.visibleCells {
            if let indexPath = tableView.indexPath(for: cell) { cell.setProblem(problem(forCardAt: indexPath.row)) }
        }
        refreshCardsFooter()
        tableView.performBatchUpdates(nil)
    }

    private func refreshCardsHeader() {
        guard let header = tableView.headerView(forSection: Section.cards.rawValue) else { return }
        configureHeader(header)
    }

    private func refreshCardsFooter() {
        guard let footer = tableView.footerView(forSection: Section.cards.rawValue) else { return }
        configureFooter(footer)
    }

    private func configureHeader(_ header: UITableViewHeaderFooterView) {
        var content = UIListContentConfiguration.header()
        content.text = String.localizedStringWithFormat(NSLocalizedString("%lld cards", comment: ""), cardCount)
        content.textProperties.font = Design.TextRole.eyebrow.font
        header.contentConfiguration = content
    }

    private func configureFooter(_ footer: UITableViewHeaderFooterView) {
        var content = UIListContentConfiguration.footer()
        content.text = cardsFooterProblem
        content.textProperties.color = Design.Color.error
        content.textProperties.font = Design.TextRole.metadata.font
        footer.contentConfiguration = content
        footer.accessibilityIdentifier = "deck_cards_problem"
    }

    // MARK: Focus and toolbar

    private func updateAccessoryPosition() {
        if let focused = focusedCard, let index = index(ofCard: focused.id) {
            accessory.setPosition(String(format: NSLocalizedString("Card %1$lld of %2$lld", comment: "Position while typing"), index + 1, cardCount))
        } else {
            accessory.setPosition(NSLocalizedString("Deck details", comment: ""))
        }
    }

    private func focusNextField() {
        if let focused = focusedCard, let index = index(ofCard: focused.id), let cell = cardCell(at: index) {
            let fields = cell.visibleFields
            if let position = fields.firstIndex(of: focused.field), position + 1 < fields.count {
                cell.focus(fields[position + 1])
            } else {
                presenter.focusNext(after: index, field: .back)
            }
            return
        }
        let name = IndexPath(row: DetailRow.name.rawValue, section: Section.details.rawValue)
        let description = IndexPath(row: DetailRow.description.rawValue, section: Section.details.rawValue)
        if (tableView.cellForRow(at: name) as? TextEntryCell)?.textView.isFirstResponder == true {
            (tableView.cellForRow(at: description) as? TextEntryCell)?.textView.becomeFirstResponder()
        } else {
            focus(cardIndex: 0, field: .front)
        }
    }

    private func addCardFromToolbar() {
        if let focused = focusedCard, let index = index(ofCard: focused.id) {
            presenter.insertCard(after: index)
        } else {
            presenter.insertCard(after: nil)
        }
    }

    // MARK: Menus

    private func makeMoreMenu() -> UIMenu {
        let reorder = UIAction(title: tableView.isEditing ? NSLocalizedString("Done reordering", comment: "") : NSLocalizedString("Reorder cards", comment: ""),
                               image: UIImage(systemName: "arrow.up.arrow.down")) { [weak self] _ in self?.toggleReordering() }
        let importCards = UIAction(title: NSLocalizedString("Import cards…", comment: ""), image: UIImage(systemName: "square.and.arrow.down")) { [weak self] _ in self?.showImport() }
        guard presenter.isEditingExistingDeck else { return UIMenu(children: [importCards, reorder]) }
        let delete = UIAction(title: NSLocalizedString("Delete deck", comment: ""), image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            self?.view.endEditing(true)
            self?.presenter.deleteDeck()
        }
        return UIMenu(children: [importCards, reorder, UIMenu(options: .displayInline, children: [delete])])
    }

    private func toggleReordering() {
        view.endEditing(true)
        tableView.setEditing(!tableView.isEditing, animated: true)
        moreItem.menu = makeMoreMenu()
        saveItem.isEnabled = !tableView.isEditing
    }

    private func showImport() {
        view.endEditing(true)
        let importer = BulkImportViewController { [weak self] text in
            guard let self else { return .success(0) }
            return self.presenter.importCards(from: text)
        }
        let navigation = UINavigationController(rootViewController: importer)
        navigation.modalPresentationStyle = .pageSheet
        navigation.sheetPresentationController?.detents = [.large()]
        present(navigation, animated: true)
    }

    private func optionsMenu(forCard id: String) -> UIMenu {
        let index = index(ofCard: id) ?? 0
        let isFirst = index == 0, isLast = index == cardCount - 1
        return UIMenu(children: [
            UIAction(title: NSLocalizedString("Move up", comment: ""), image: UIImage(systemName: "arrow.up"), attributes: isFirst ? .disabled : []) { [weak self] _ in
                guard let self, let current = self.index(ofCard: id) else { return }
                self.presenter.moveCard(at: current, by: -1)
            },
            UIAction(title: NSLocalizedString("Move down", comment: ""), image: UIImage(systemName: "arrow.down"), attributes: isLast ? .disabled : []) { [weak self] _ in
                guard let self, let current = self.index(ofCard: id) else { return }
                self.presenter.moveCard(at: current, by: 1)
            },
            UIAction(title: NSLocalizedString("Duplicate", comment: ""), image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
                guard let self, let current = self.index(ofCard: id) else { return }
                self.presenter.duplicateCard(at: current)
            },
            UIAction(title: NSLocalizedString("Delete", comment: ""), image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                guard let self, let current = self.index(ofCard: id) else { return }
                self.presenter.requestDeleteCard(at: current)
            }
        ])
    }

    private func pictureMenu(forCard id: String, hasPicture: Bool) -> UIMenu {
        var actions: [UIMenuElement] = [
            UIAction(title: NSLocalizedString("Choose from Photos", comment: ""), image: UIImage(systemName: "photo.on.rectangle")) { [weak self] _ in
                self?.pictureTargetId = id
                self?.showPhotoPicker()
            },
            UIAction(title: NSLocalizedString("Use a web address…", comment: ""), image: UIImage(systemName: "link")) { [weak self] _ in
                self?.askForPictureAddress(cardId: id)
            }
        ]
        if hasPicture {
            actions.append(UIAction(title: NSLocalizedString("Remove picture", comment: ""), image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                guard let self, let index = self.index(ofCard: id) else { return }
                self.presenter.removePicture(fromCardAt: index)
            })
        }
        return UIMenu(children: actions)
    }

    private func showPhotoPicker() {
        view.endEditing(true)
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func askForPictureAddress(cardId: String) {
        let alert = UIAlertController(title: NSLocalizedString("Picture from the web", comment: ""),
                                      message: NSLocalizedString("Paste the https address of a JPEG, PNG, HEIC, WebP or GIF picture. It is saved on this device.", comment: ""),
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "https://"
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.clearButtonMode = .whileEditing
            field.accessibilityIdentifier = "picture_address"
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Add", comment: ""), style: .default) { [weak self, weak alert] _ in
            guard let self, let index = self.index(ofCard: cardId) else { return }
            self.presenter.setPicture(fromAddress: alert?.textFields?.first?.text ?? "", forCardAt: index)
        })
        present(alert, animated: true)
    }
}

// MARK: - Photos

extension CreateDeskViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, let cardId = pictureTargetId else { return }
        pictureTargetId = nil
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
            // An unreadable item reaches the presenter as empty data, which it reports like any invalid picture.
            DispatchQueue.main.async {
                guard let self, let index = self.index(ofCard: cardId) else { return }
                self.presenter.setPicture(fromData: data ?? Data(), forCardAt: index)
            }
        }
    }
}

// MARK: - Dismissal guard

extension CreateDeskViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        presenter.close()
    }
}

// MARK: - Table

extension CreateDeskViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section(rawValue: section) == .details ? DetailRow.allCases.count : cardCount + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if Section(rawValue: indexPath.section) == .details { return detailCell(at: indexPath) }
        if indexPath.row == cardCount {
            return tableView.dequeueReusableCell(withIdentifier: AddCardCell.reuseIdentifier, for: indexPath)
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: CardEditorCell.reuseIdentifier, for: indexPath) as! CardEditorCell
        let card = presenter.draft.cards[indexPath.row]
        cell.configure(card: card, number: indexPath.row + 1, revealed: revealed[card.id] ?? [],
                       isBusy: presenter.busyCardIds.contains(card.id), problem: problem(forCardAt: indexPath.row),
                       optionsMenu: optionsMenu(forCard: card.id), pictureMenu: pictureMenu(forCard: card.id, hasPicture: !card.imageReference.isEmpty))
        let id = card.id
        cell.onTextChange = { [weak self] field, text in
            guard let self, let index = self.index(ofCard: id) else { return }
            self.presenter.updateField(field, ofCardAt: index, text: text)
        }
        cell.onBeginEditing = { [weak self] field in
            guard let self else { return }
            self.focusedCard = (id, field)
            self.updateAccessoryPosition()
            if let index = self.index(ofCard: id) { self.presenter.suggestionsNeeded(cardIndex: index, field: field) }
        }
        cell.onHeightChange = { [weak self, weak cell] in
            guard let self, let cell else { return }
            UIView.performWithoutAnimation { self.tableView.performBatchUpdates(nil) }
            if let indexPath = self.tableView.indexPath(for: cell) { self.tableView.scrollToRow(at: indexPath, at: .none, animated: false) }
        }
        cell.onReveal = { [weak self, weak cell] field in
            guard let self, let cell, let index = self.index(ofCard: id) else { return }
            self.revealed[id, default: []].insert(field)
            self.reloadCard(at: index)
            DispatchQueue.main.async { (self.cardCell(at: index) ?? cell).focus(field) }
        }
        for field in CardField.allCases { cell.setAccessory(accessory, for: field) }
        return cell
    }

    private func detailCell(at indexPath: IndexPath) -> UITableViewCell {
        switch DetailRow(rawValue: indexPath.row) ?? .name {
        case .name, .description:
            let isName = indexPath.row == DetailRow.name.rawValue
            let cell = tableView.dequeueReusableCell(withIdentifier: TextEntryCell.reuseIdentifier, for: indexPath) as! TextEntryCell
            cell.configure(text: isName ? presenter.draft.name : presenter.draft.details,
                           placeholder: isName ? NSLocalizedString("Deck name", comment: "") : NSLocalizedString("Description (optional)", comment: ""),
                           role: isName ? .headword : .meaning,
                           problem: isName ? nameProblem : nil, allowsLineBreaks: !isName,
                           identifier: isName ? "deck_name" : "deck_description")
            cell.onChange = { [weak self] text in
                if isName { self?.presenter.updateName(text) } else { self?.presenter.updateDetails(text) }
            }
            cell.onHeightChange = { [weak self] in UIView.performWithoutAnimation { self?.tableView.performBatchUpdates(nil) } }
            cell.onBeginEditing = { [weak self] in
                self?.focusedCard = nil
                self?.accessory.setSuggestions([])
                self?.updateAccessoryPosition()
            }
            cell.textView.inputAccessoryView = accessory
            return cell
        case .direction:
            let cell = tableView.dequeueReusableCell(withIdentifier: DeckDirectionCell.reuseIdentifier, for: indexPath) as! DeckDirectionCell
            cell.configure(direction: presenter.draft.sortingLanguage) { [weak self] direction in self?.presenter.setDirection(direction) }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard Section(rawValue: section) == .cards else { return nil }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header")!
        configureHeader(header)
        return header
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard Section(rawValue: section) == .cards else { return nil }
        let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: "footer")!
        configureFooter(footer)
        return footer
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        Section(rawValue: section) == .cards ? UITableView.automaticDimension : 0.01
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        Section(rawValue: section) == .cards ? UITableView.automaticDimension : 0.01
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if Section(rawValue: indexPath.section) == .cards, indexPath.row == cardCount {
            presenter.insertCard(after: cardCount - 1)
        }
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        Section(rawValue: indexPath.section) == .cards && indexPath.row == cardCount
    }

    // Reordering and deleting (edit mode)

    private func isCardRow(_ indexPath: IndexPath) -> Bool {
        Section(rawValue: indexPath.section) == .cards && indexPath.row < cardCount
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { isCardRow(indexPath) }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        isCardRow(indexPath) ? .delete : .none
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool { false }

    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt source: IndexPath, toProposedIndexPath proposed: IndexPath) -> IndexPath {
        guard proposed.section == Section.cards.rawValue else { return source }
        return IndexPath(row: min(proposed.row, cardCount - 1), section: Section.cards.rawValue)
    }

    func tableView(_ tableView: UITableView, moveRowAt source: IndexPath, to destination: IndexPath) {
        presenter.moveCard(from: source.row, to: destination.row)
        tableView.reconfigureRows(at: (min(source.row, destination.row)...max(source.row, destination.row)).map(cardIndexPath))
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete, isCardRow(indexPath) { presenter.requestDeleteCard(at: indexPath.row) }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard isCardRow(indexPath), !tableView.isEditing else { return nil }
        let delete = UIContextualAction(style: .destructive, title: NSLocalizedString("Delete", comment: "")) { [weak self] _, _, done in
            self?.presenter.requestDeleteCard(at: indexPath.row)
            done(true)
        }
        delete.image = UIImage(systemName: "trash")
        let configuration = UISwipeActionsConfiguration(actions: [delete])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}
