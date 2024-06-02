//
//  SettingViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit

final class SettingViewController: BaseViewController {
    var presenter: SettingPresenterInterface!
    
    @IBOutlet private weak var settingTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }

    func setupUI() {
        settingTableView.registerNib(cellClass: AccountCell.self)
        settingTableView.registerNib(cellClass: CommonCell.self)
    }

    func subscribe() {
        subscribe(presenter.settingDataRelay) { [weak self] _ in
            guard let self else { return }
            self.applySetting()
        }
    }
}

extension SettingViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        presenter.settingDataRelay.value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cellType = SettingTableCell(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        switch cellType {
            case .account:
                let cell: AccountCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
                return cell
            default:
                let cell: CommonCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
                cell.updateCell(presenter.settingDataRelay.value[indexPath.row])
                return cell
        }
    }
}

extension SettingViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 80.0
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return VersionFooterView(frame: .zero)
    }
}

extension SettingViewController {
    private func applySetting() {
        settingTableView.reloadData()
    }
}
