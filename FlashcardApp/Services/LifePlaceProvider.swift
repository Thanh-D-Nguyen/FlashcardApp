//
//  LifePlaceProvider.swift
//
//  Reads where the learner is, once, when they ask: one position fix, the place names in Japanese, and the kinds of places
//  around them from Apple Maps. Privacy: no background location, no continuous updates, coordinates are not stored and not
//  sent anywhere; only names and kinds of places leave this file. If the learner refuses, nothing is read.
//

import CoreLocation
import Foundation
import MapKit
import RxSwift

enum LifeLocationAuthorization: Equatable {
    case notDetermined, denied, authorized
}

enum LifePlaceError: Error, Equatable, LocalizedError {
    case denied
    case unavailable
    case outsideJapan
    case nothingNearby

    var errorDescription: String? {
        switch self {
        case .denied: return NSLocalizedString("Location is off for this app. You can turn it on in Settings, or keep choosing a city.", comment: "")
        case .unavailable: return NSLocalizedString("Couldn't find where you are. Try again in a moment.", comment: "")
        case .outsideJapan: return NSLocalizedString("You don't seem to be in Japan, so there is no Japanese place lesson for here. Choose a Japanese city to learn from.", comment: "")
        case .nothingNearby: return NSLocalizedString("No notable places found around you to learn from.", comment: "")
        }
    }
}

protocol LifePlaceProviding: AnyObject {
    var authorization: LifeLocationAuthorization { get }
    /// Asks for permission if it was never decided (the system dialog), reads the position once and turns it into a `LifePlace`.
    /// Disposing the subscription stops the work.
    func currentPlace() -> Single<LifePlace>
}

final class CoreLocationPlaceProvider: LifePlaceProviding {
    static let shared = CoreLocationPlaceProvider()

    var authorization: LifeLocationAuthorization {
        switch CLLocationManager().authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorizedAlways, .authorizedWhenInUse: return .authorized
        default: return .denied
        }
    }

    func currentPlace() -> Single<LifePlace> {
        Single.create { observer in
            let job = Job(observer: observer)
            job.start()
            return Disposables.create { job.cancel() }
        }
        .subscribe(on: MainScheduler.instance)
    }

    /// One lookup: permission → one fix → place names → nearby kinds. Retains itself until it ends.
    private final class Job: NSObject, CLLocationManagerDelegate {
        private let observer: (SingleEvent<LifePlace>) -> Void
        private let manager = CLLocationManager()
        private var reverseRequest: MKReverseGeocodingRequest?
        private var search: MKLocalSearch?
        private var finished = false
        private var retries = 0
        private var selfRetain: Job?

        init(observer: @escaping (SingleEvent<LifePlace>) -> Void) {
            self.observer = observer
            super.init()
            manager.delegate = self
            // Neighbourhood accuracy is enough to name a ward and the places around it.
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            selfRetain = self
        }

        func start() {
            switch manager.authorizationStatus {
            case .notDetermined: manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
            default: finish(.failure(LifePlaceError.denied))
            }
        }

        func cancel() {
            finished = true
            reverseRequest?.cancel()
            search?.cancel()
            manager.stopUpdatingLocation()
            selfRetain = nil
        }

        private func finish(_ result: Result<LifePlace, Error>) {
            guard !finished else { return }
            finished = true
            observer(result.publicEvent)
            selfRetain = nil
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            guard !finished else { return }
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
            case .notDetermined: break
            default: finish(.failure(LifePlaceError.denied))
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard !finished, let location = locations.last else { return }
            resolve(location)
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            logger.error("Reading the position failed: \((error as NSError).domain) \((error as NSError).code)")
            // Right after permission is given the system may not have a fix yet: ask again, briefly, a couple of times.
            if (error as? CLError)?.code == .locationUnknown, retries < 2, !finished {
                retries += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self, !self.finished else { return }
                    self.manager.requestLocation()
                }
                return
            }
            if (error as? CLError)?.code == .denied { finish(.failure(LifePlaceError.denied)) } else { finish(.failure(LifePlaceError.unavailable)) }
        }

        private func resolve(_ location: CLLocation) {
            guard let request = MKReverseGeocodingRequest(location: location) else {
                return finish(.failure(LifePlaceError.unavailable))
            }
            request.preferredLocale = Locale(identifier: "ja_JP")
            reverseRequest = request
            request.getMapItems { [weak self] items, error in
                guard let self, !self.finished else { return }
                guard let representation = items?.first?.addressRepresentations, error == nil else {
                    logger.error("Naming the place failed: \(error.map { "\(($0 as NSError).domain) \(($0 as NSError).code)" } ?? "no result")")
                    return self.finish(.failure(LifePlaceError.unavailable))
                }
                guard representation.__regionCode == "JP" else { return self.finish(.failure(LifePlaceError.outsideJapan)) }
                // MapKit supplies a localized city with its prefecture context as one display name.
                let placeName = representation.cityWithContext ?? representation.cityName ?? ""
                guard !placeName.isEmpty else { return self.finish(.failure(LifePlaceError.unavailable)) }
                self.findNearby(location) { nearby in
                    guard !nearby.isEmpty else { return self.finish(.failure(LifePlaceError.nothingNearby)) }
                    self.finish(.success(LifePlace(adminArea: "", locality: placeName, nearby: nearby)))
                }
            }
        }

        private func findNearby(_ location: CLLocation, completion: @escaping ([LifePlace.Nearby]) -> Void) {
            let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: 900)
            let search = MKLocalSearch(request: request)
            self.search = search
            search.start { [weak self] response, _ in
                guard self?.finished == false else { return }
                var nearest: [LifePlaceKind: Double] = [:]
                for item in response?.mapItems ?? [] {
                    guard let category = item.pointOfInterestCategory, let kind = Self.kind(of: category) else { continue }
                    let distance = location.distance(from: item.location)
                    nearest[kind] = min(nearest[kind] ?? .infinity, distance)
                }
                let nearby = nearest.map { LifePlace.Nearby(kind: $0.key, meters: Int(($0.value / 100).rounded()) * 100) }
                    .sorted { ($0.meters, $0.kind.rawValue) < ($1.meters, $1.kind.rawValue) }
                completion(Array(nearby.prefix(3)))
            }
        }

        private static func kind(of category: MKPointOfInterestCategory) -> LifePlaceKind? {
            switch category {
            case .publicTransport: return .station
            case .restaurant: return .restaurant
            case .cafe: return .cafe
            case .foodMarket: return .supermarket
            case .store: return .shop
            case .bank: return .bank
            case .hospital: return .hospital
            case .pharmacy: return .pharmacy
            case .park, .nationalPark: return .park
            case .postOffice: return .postOffice
            case .school, .university: return .school
            case .library: return .library
            default: return nil
            }
        }
    }
}

private extension Result where Success == LifePlace, Failure == Error {
    var publicEvent: SingleEvent<LifePlace> {
        switch self {
        case .success(let place): return .success(place)
        case .failure(let error): return .failure(error)
        }
    }
}
