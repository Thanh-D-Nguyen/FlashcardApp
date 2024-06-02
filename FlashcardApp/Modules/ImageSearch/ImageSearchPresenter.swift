//
//  ImageSearchPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/02.
//  
//

import Foundation
import RxSwift
import RxCocoa

protocol ImageSearchPresenterInterface: AnyObject {
    
    var photosRelay: BehaviorRelay<[SearchPhoto]> { get }
    var errorRelay: BehaviorRelay<Error?> { get }

    func viewDidLoad()
    
    func changePhotoSource(_ index: Int)
    func searchPhotos(query: String?)
}

class ImageSearchPresenter {
    final private let pageSize = 25
    private var currentPage = 1
    private var isLoading = false
    private var currentQuery = ""
    
    private var totalPhotos: [SearchPhoto] = []
    
    let photosRelay = BehaviorRelay<[SearchPhoto]>(value: [])
    let errorRelay = BehaviorRelay<Error?>(value: nil)
    
    private var interactor: ImageSearchInteractorInterface
    private let wireframe: ImageSearchWireframeInterface
    
    private let disposeBag = DisposeBag()
    
    init(interactor: ImageSearchInteractorInterface, 
         wireframe: ImageSearchWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ImageSearchPresenter: ImageSearchPresenterInterface {
    func viewDidLoad() {
        
    }
    
    func changePhotoSource(_ index: Int) {
        let photoSource = SearchImageType(rawValue: index) ?? .flickr
        interactor = ImageSearchInteractor(searchType: photoSource)
        self.currentPage = 1
        self.totalPhotos = []
        searchPhotos(query: self.currentQuery)
    }
    
    func searchPhotos(query: String?) {
        guard !isLoading else { return }
        isLoading = true
        if let q = query, !q.isEmpty {
            self.currentQuery = q
        }
        interactor.search(query: self.currentQuery, page: currentPage, perpage: pageSize).subscribe { [weak self] photos in
            guard let self else { return }
            self.isLoading = false
            self.currentPage += 1
            self.totalPhotos.append(contentsOf: photos)
            self.photosRelay.accept(self.totalPhotos)
            logger.debug("\(photos)")

        } onFailure: { [weak self] error in
            guard let self else { return }
            self.errorRelay.accept(error)
            self.isLoading = false
            logger.error("\(error)")
            
        }.disposed(by: disposeBag)
    }
}
