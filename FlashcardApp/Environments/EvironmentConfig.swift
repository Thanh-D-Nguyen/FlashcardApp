import Foundation

final class EnvironmentConfig {
    static func baseUrl() -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ProductBaseUrl") as? String,
              let url = URL(string: value), url.host != nil else {
            preconditionFailure("Configure PRODUCT_BASE_URL before building the app.")
        }
        return value.hasSuffix("/") ? String(value.dropLast()) : value
    }
}
