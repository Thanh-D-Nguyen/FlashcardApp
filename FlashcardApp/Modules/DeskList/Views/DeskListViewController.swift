//
//  DeskListViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//  
//

import UIKit

final class DeskListViewController: BaseViewController {
    var presenter: DeskListPresenterInterface!
    @IBOutlet private weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        presenter.viewDidLoad()
    }

    func setupUI() {
        tableView.registerNib(cellClass: DeskListCell.self)
        let tapGusture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGusture.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tapGusture)
    }

    func subscribe() {
        subscribe(presenter.desksRelay) { [weak self] value in
            guard let self else { return }
            self.tableView.reloadData()
        }
    }
    
    @objc private func handleTap(_ guesture: UITapGestureRecognizer) {
        let location = guesture.location(in: view)
        let tappedView = view.hitTest(location, with: nil)
        if tappedView == view {
            presenter.dismiss()
        }
    }
}

extension DeskListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presenter.desksRelay.value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: DeskListCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
        if presenter.desksRelay.value.indices.contains(indexPath.row) {
            cell.updateInfo(presenter.desksRelay.value[indexPath.row])
        }
        return cell
    }
}

extension DeskListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        presenter.didSelectDeskAtIndex(indexPath.row)
    }
}
