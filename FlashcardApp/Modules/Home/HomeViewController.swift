//
//  HomeViewController.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/14.
//
//

import UIKit

final class HomeViewController: BaseViewController {

    var presenter: HomePresenterInterface!
    
    @IBOutlet weak private var homeTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
    }
    
    func setupUI() {
        homeTableView.registerNib(cellClass: HomeCardCell.self)
        homeTableView.registerNib(cellClass: HomeSubSectionCell.self)
        homeTableView.registerNib(cellClass: HomeCarouselCell.self)
        homeTableView.backgroundColor = .white
    }

    func subscribe() { }
}

extension HomeViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        HomeSectionType.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = HomeSectionType(rawValue: section) else { return 0 }
        return sectionType.numOfCells
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = HomeSectionType(rawValue: indexPath.section) else { return UITableViewCell() }
        if sectionType == .card {
            let cell: HomeCardCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
            return cell
        } else {
            if indexPath.row == 0 {
                let cell: HomeSubSectionCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
                cell.updateTitle(sectionType)
                return cell
            } else {
                let cell: HomeCarouselCell = tableView.dequeueResuableCell(forIndexPath: indexPath)
                return cell
            }
        }
    }
}

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let sectionType = HomeSectionType(rawValue: indexPath.section) else { return 0.0 }
        return sectionType.heightForRow(indexPath.row)
    }
}
