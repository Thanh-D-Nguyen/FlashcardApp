//
//  ImageSearchWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/02.
//  
//

import UIKit

protocol ImageSearchWireframeInterface: AnyObject {

}

final class ImageSearchWireframe: BaseWireframe<ImageSearchViewController> {
    
    private let storyboard = UIStoryboard(name: "ImageSearch", bundle: nil)
    
    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: ImageSearchViewController.self)
        super.init(viewController: moduleViewController)
        let interactor = ImageSearchInteractor.create(type: .pixabay)
        let presenter = ImageSearchPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    } 
}

extension ImageSearchWireframe: ImageSearchWireframeInterface {
    
}
