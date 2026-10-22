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
        refreshNotificationStatus()
        presenter.viewWillAppear()
    }

    func setupUI() {
        settingTableView.registerNib(cellClass: AccountCell.self)
        settingTableView.registerNib(cellClass: CommonCell.self)
        settingTableView.register(ToggleCell.self, forCellReuseIdentifier: ToggleCell.reuseIdentifier)
        settingTableView.dataSource = self
        settingTableView.delegate = self
        settingTableView.rowHeight = UITableView.automaticDimension
        settingTableView.estimatedRowHeight = 60
        settingTableView.backgroundColor = Design.Color.background
        settingTableView.separatorStyle = .singleLine
        settingTableView.separatorInset = UIEdgeInsets(top: 0, left: 56, bottom: 0, right: 0)
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
            UserDefaultsPreferences.shared.notificationAuthorizationStatus = settings.authorizationStatus
            DispatchQueue.main.async {
                self.presenter.viewWillAppear()
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension SettingViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        presenter.sectionsRelay.value.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        presenter.sectionsRelay.value[section].title
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        presenter.sectionsRelay.value[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = presenter.sectionsRelay.value[indexPath.section].items[indexPath.row]

        switch item {
        case .account(let user):
            let cell: AccountCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
            cell.configure(with: user)
            return cell

        case .toggle(let config):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ToggleCell.reuseIdentifier, for: indexPath) as? ToggleCell else {
                return UITableViewCell()
            }
            cell.configure(with: config)
            cell.onToggleChanged = { [weak self] isOn in
                switch config.id {
                case "notification":
                    self?.presenter.toggleNotification(to: isOn)
                case "sound":
                    self?.presenter.toggleSound(to: isOn)
                default:
                    break
                }
            }
            return cell

        case .navigation(let config), .destructive(let config):
            let cell: CommonCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
            let isDestructive: Bool
            if case .destructive = item {
                isDestructive = true
            } else {
                isDestructive = false
            }
            cell.updateCell(
                title: config.title,
                subText: config.subText,
                iconName: config.iconName,
                showDisclosure: config.disclosure,
                isDestructive: isDestructive
            )
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension SettingViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = presenter.sectionsRelay.value[indexPath.section].items[indexPath.row]

        switch item {
        case .navigation(let config), .destructive(let config):
            presenter.handleNavigationTap(config: config)
        case .account:
            presenter.didSelectItem(at: indexPath)
        case .toggle:
            break
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // Minimal footer spacing; version info moved to About row.
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat {
        return 8
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
}