//
//  SettingViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import UIKit
import RxSwift
import RxCocoa
import Kingfisher
import UserNotifications

final class SettingViewController: BaseViewController {

    var presenter: SettingPresenterInterface!

    @IBOutlet private weak var settingTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        refreshNotificationStatus()
        presenter.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.viewWillDisappear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AdsService.shared.prepare(from: self)
    }

    func setupUI() {
        settingTableView.register(AccountCell.self, forCellReuseIdentifier: AccountCell.reuseIdentifier)
        settingTableView.register(SettingsRowCell.self, forCellReuseIdentifier: SettingsRowCell.reuseIdentifier)
        settingTableView.register(SectionHeaderView.self, forHeaderFooterViewReuseIdentifier: SectionHeaderView.reuseIdentifier)
        settingTableView.dataSource = self
        settingTableView.delegate = self
        settingTableView.rowHeight = UITableView.automaticDimension
        settingTableView.estimatedRowHeight = 56
        settingTableView.estimatedSectionHeaderHeight = 32
        settingTableView.sectionHeaderTopPadding = 0
        settingTableView.backgroundColor = Design.Color.background
        settingTableView.separatorStyle = .singleLine
        settingTableView.separatorColor = Design.Color.separator
        // Hairlines start under the text, past the 28 pt icon column.
        settingTableView.separatorInset = UIEdgeInsets(top: 0, left: 56, bottom: 0, right: 0)
        settingTableView.accessibilityIdentifier = "settings_list"
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .always
    }

    func subscribe() {
        presenter.sectionsRelay
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.settingTableView.reloadData()
            })
            .disposed(by: disposeBag)
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            DispatchQueue.main.async {
                self.presenter.updateNotificationAuthorizationStatus(settings.authorizationStatus)
                DailyStudyReminder.restoreIfNeeded()
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension SettingViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        presenter.sectionsRelay.value.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        presenter.sectionsRelay.value[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = presenter.sectionsRelay.value[indexPath.section].items[indexPath.row]

        switch item {
        case .account(let user):
            let cell = tableView.dequeueReusableCell(withIdentifier: AccountCell.reuseIdentifier, for: indexPath) as! AccountCell
            cell.configure(with: user)
            cell.onSignIn = { [weak self] in self?.presenter.didSelectItem(at: indexPath) }
            cell.accessibilityIdentifier = "setting_account"
            return cell

        case .toggle(let config):
            let cell = rowCell(tableView, indexPath)
            cell.configureToggle(title: config.title, subtitle: config.subtitle, iconName: config.iconName,
                                 isOn: config.isOn, isEnabled: config.isEnabled)
            cell.onToggle = { [weak self] isOn in
                switch config.id {
                case "notification": self?.presenter.toggleNotification(to: isOn)
                case "sound": self?.presenter.toggleSound(to: isOn)
                case "analytics": self?.presenter.toggleAnalytics(to: isOn)
                default: break
                }
            }
            cell.accessibilityIdentifier = "setting_\(config.id)"
            return cell

        case .choice(let config):
            let cell = rowCell(tableView, indexPath)
            let actions = config.options.map { option in
                UIAction(title: option.title, state: option.id == config.selectedID ? .on : .off) { [weak self] _ in
                    self?.presenter.selectChoice(id: config.id, optionID: option.id)
                }
            }
            cell.configureChoice(title: config.title, iconName: config.iconName, selectedTitle: config.selectedTitle,
                                 menu: UIMenu(title: config.title, options: .singleSelection, children: actions))
            cell.accessibilityIdentifier = "setting_\(config.id)"
            return cell

        case .navigation(let config):
            let cell = rowCell(tableView, indexPath)
            cell.configureNavigation(title: config.title, iconName: config.iconName, value: config.subText,
                                     disclosure: config.disclosure)
            cell.accessibilityIdentifier = "setting_\(config.id)"
            return cell

        case .destructive(let config):
            let cell = rowCell(tableView, indexPath)
            cell.configureNavigation(title: config.title, iconName: config.iconName, value: config.subText,
                                     disclosure: config.disclosure, destructive: true)
            cell.accessibilityIdentifier = "setting_\(config.id)"
            return cell
        }
    }

    private func rowCell(_ tableView: UITableView, _ indexPath: IndexPath) -> SettingsRowCell {
        tableView.dequeueReusableCell(withIdentifier: SettingsRowCell.reuseIdentifier, for: indexPath) as! SettingsRowCell
    }
}

// MARK: - UITableViewDelegate

extension SettingViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = presenter.sectionsRelay.value[indexPath.section].items[indexPath.row]

        switch item {
        case .navigation(let config), .destructive(let config):
            if config.id == "ad_privacy" {
                AdsService.shared.presentPrivacyOptions(from: self)
            } else {
                presenter.handleNavigationTap(config: config)
            }
        case .account:
            presenter.didSelectItem(at: indexPath)
        case .toggle, .choice:
            break
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = presenter.sectionsRelay.value[section].title else { return nil }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: SectionHeaderView.reuseIdentifier) as! SectionHeaderView
        header.configure(title: title)
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        presenter.sectionsRelay.value[section].title == nil ? Design.Spacing.s : UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { .leastNormalMagnitude }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { nil }
}
