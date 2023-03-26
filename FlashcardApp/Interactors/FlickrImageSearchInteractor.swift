//
//  FlickrImageSearchInteractor.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/03/26.
//

import UIKit

protocol FlickrImageSearchInteractorInterface: AnyObject {
    
    var resultPhotos: (([Photo]) -> Void)? { get set }
    
    var resultImage: ((UIImage?) -> Void)? { get set }
    
    func fetchPhotos(_ request: ImageSearchEntity.FetchPhotos.Request)
    func selectPhoto(_ request: ImageSearchEntity.SelectPhoto.Request)
}

class FlickrImageSearchInteractor {
    private let networkService: NetworkServiceProtocol
    private let decodingService: DecodingServiceProtocol

    private let detailInteractor: FlickrImageDetailInteractorInterface
    
    private var selectedPhoto: Photo?
    @Atomic private var photos: [Photo] = []
    
    var resultPhotos: (([Photo]) -> Void)?
    var resultImage: ((UIImage?) -> Void)?
    
    // MARK: - Pagination
    private var isLastPage = false
    private var isPaginating = false
    private var searchQuery = ""
    private var currentPage = 1
    private var totalPagesCount = 1
    private var oldPhotosCount = 0
    private var photosPerPage = 0
    
    init() {
        networkService = NetworkService()
        decodingService = DecodingService()
        detailInteractor = FlickrImageDetailInteractor()
    }
}

extension FlickrImageSearchInteractor: FlickrImageSearchInteractorInterface {
    func fetchPhotos(_ request: ImageSearchEntity.FetchPhotos.Request) {
        resetPaginationIfNeeded(for: request.query)
        
        guard isPaginationEnabled else { return }
        isPaginating = true
        photosPerPage = request.photosPerPage
        
        let search = FlickrRoute.search(
            query: request.query,
            page: currentPage,
            perpage: photosPerPage
        )
        
        networkService.fetch(route: search) { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let data):
                    guard let data = data else {
                        self.stopPagination()
                        return
                    }
                    
                    let decodingResult = self.decodingService.decodeJSON(
                        PhotoSearchResult.self,
                        data: data
                    )
                    switch decodingResult {
                        case .success(let searchResult):
                            do {
                                try self.updatePhotos(searchResult.photos)
                                DispatchQueue.main.async {
                                    self.incrementPage()
                                    self.stopPagination()
                                    self.resultPhotos?(self.photos)
                                }
                            } catch {
                                self.stopPagination(with: error)
                            }
                        case .failure(let error):
                            self.stopPagination(with: error)
                    }
                case .failure(let error):
                    self.stopPagination(with: error)
            }
        }
    }
    
    func selectPhoto(_ request: ImageSearchEntity.SelectPhoto.Request) {
        selectedPhoto = photos[request.index]
    }
}


// MARK: - Methods
private extension FlickrImageSearchInteractor {
    func resetPaginationIfNeeded(for query: String) {
        guard searchQuery != query else { return }
        searchQuery = query
        isLastPage = false
        currentPage = 1
        totalPagesCount = 1
        photos = []
    }
    
    func updatePhotos(_ photos: PagedPhotoSearchResult?) throws {
        guard let photos = photos, let firstPhoto = photos.photo.first else { throw DataError.photosDataIsMissing }
        detailInteractor.fetchPhoto(ImageDetailEntity.FetchPhoto.Request(id: firstPhoto.id, server: firstPhoto.server, secret: firstPhoto.secret))
        detailInteractor.didCompleteLoadImage = { [weak self] image in
            self?.resultImage?(image)
            
        }
        setTotalPagesCount(photos.total)
        oldPhotosCount = self.photos.count
        self.photos.append(contentsOf: photos.photo)
    }
    
    func setTotalPagesCount(_ totalPhotosCount: Int) {
        if totalPagesCount == 1 && totalPhotosCount > photosPerPage {
            totalPagesCount = totalPhotosCount / photosPerPage
        }
    }
    
    func incrementPage() {
        if (currentPage + 1) <= totalPagesCount {
            currentPage += 1
        } else {
            isLastPage = true
        }
    }
    
    func stopPagination(with error: Error? = nil) {
        isPaginating = false
        error.map { debugPrint($0.localizedDescription) }
    }
}

// MARK: - Computed properties
private extension FlickrImageSearchInteractor {
    var isPaginationEnabled: Bool {
        let searchQueryIsNotEmpty = !searchQuery.isEmpty
        let pagesCountIsNotExceeded = currentPage <= totalPagesCount
        return !isPaginating && !isLastPage && searchQueryIsNotEmpty && pagesCountIsNotExceeded
    }
}
