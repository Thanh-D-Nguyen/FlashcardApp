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
        settingTableView.dataSource = self
        settingTableView.delegate = self
    }

    func subscribe() {
        subscribe(presenter.settingDataRelay, { [weak self] _ in
            guard let self else { return }
            self.settingTableView.reloadData()
        })
    }
}

extension SettingViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presenter.settingDataRelay.value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell: AccountCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
            return cell
        }
        let cell: CommonCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
        cell.updateCell(presenter.settingDataRelay.value[indexPath.row])
        return cell
    }
}

extension SettingViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
