//
//  HomePresenter.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/14.
//
//

import UIKit

enum HomeSectionType: Int {
    case card = 0
    case quest
    case popular
    case recomment
    case bundle1
    case bundle2
    
    var numOfCells: Int {
        if self == .card {
            return 1
        }
        return 2
    }
    
    var titleText: String {
        switch self {
            case .card:
                return ""
            case .quest:
                return NSLocalizedString("Daily quests", comment: "")
            case .popular:
                return NSLocalizedString("Popular items", comment: "")
            case .recomment:
                return NSLocalizedString("Recommended for you", comment: "")
            case .bundle1:
                return NSLocalizedString("Seasonal bundles", comment: "")
            case .bundle2:
                return NSLocalizedString("Mystery bundles", comment: "")
        }
    }
    
    func heightForRow(_ row: Int) -> CGFloat {
        switch self {
            case .card:
                return 270.0
            case .quest:
                return row == 0 ? 68 : 152
            case .popular, .recomment:
                return row == 0 ? 68 : 227
            case .bundle1, .bundle2:
                return row == 0 ? 68 : 203
        }
    }
    
    static let count = 6
}

protocol HomePresenterInterface: AnyObject {
    
    func sectionData(_ sectionType: HomeSectionType)
}

final class HomePresenter {

    private let interactor: HomeInteractorInterface
    private let wireframe: HomeWireframeInterface

    init(
        interactor: HomeInteractorInterface,
        wireframe: HomeWireframeInterface
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension HomePresenter: HomePresenterInterface {
    func sectionData(_ sectionType: HomeSectionType) {
        
    }
}
