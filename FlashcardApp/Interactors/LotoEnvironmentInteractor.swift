//
//  LotoEnvironmentInteractor.swift
//
//  The weather of the ten Japanese cities of the life hub, read from the public life feed, as factors of the Loto chaos system.
//  Best effort: a city that cannot be read is left out, and no city at all is a valid result.
//

import Foundation
import RxSwift

protocol LotoEnvironmentInteractorInterface: AnyObject {
    /// Never fails; the factors that could be read, in no particular order.
    func weatherFactors() -> Single<[LotoChaosFactor]>
}

final class LotoEnvironmentInteractor: LotoEnvironmentInteractorInterface {
    private let api: BJTLifeFeedAPIInterface

    init(api: BJTLifeFeedAPIInterface = BJTLifeFeedAPI.shared) { self.api = api }

    func weatherFactors() -> Single<[LotoChaosFactor]> {
        let loads = LifeCity.all.map { [api] city in
            api.feed(cityID: city.id).map { Self.factor(city: city, feed: $0) }.catchAndReturn(nil)
        }
        return Single.zip(loads).map { $0.compactMap { $0 } }
    }

    static func factor(city: LifeCity, feed: BJTLifeFeedDTO) -> LotoChaosFactor? {
        guard let scene = feed.cards.first(where: { $0.topic == "weather" })?.scene, scene.kind == "weather",
              let code = scene.weatherCode, let temperature = scene.temperatureC, temperature.isFinite else { return nil }
        let rounded = (temperature * 10).rounded() / 10
        return LotoChaosFactor(kind: .weather, key: "weather.\(city.id)", value: "code=\(code);temperatureC=\(rounded)",
                               display: String(format: "%.1f°C", rounded), subject: city.id)
    }
}
