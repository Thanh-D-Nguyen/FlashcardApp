import Foundation
import Alamofire

public struct JSONDataEncoding: ParameterEncoding {

    // MARK: Properties

    private static let jsonDataKey = "jsonData"

    // MARK: Encoding

    /// Creates a URL request by encoding parameters and applying them onto an existing request.
    ///
    /// - parameter urlRequest: The request to have parameters applied.
    /// - parameter parameters: The parameters to apply. This should have a single key/value
    ///                         pair with "jsonData" as the key and a Data object as the value.
    ///
    /// - throws: An `Error` if the encoding process encounters an error.
    ///
    /// - returns: The encoded request.
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()

        guard let jsonData = parameters?[JSONDataEncoding.jsonDataKey] as? Data, !jsonData.isEmpty else {
            return urlRequest
        }

        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        urlRequest.httpBody = jsonData

        return urlRequest
    }

    public static func encodingParameters(jsonData: Data?) -> Parameters? {
        var returnedParams: Parameters? = nil
        if let jsonData = jsonData, !jsonData.isEmpty {
            var params = Parameters()
            params[jsonDataKey] = jsonData
            returnedParams = params
        }
        return returnedParams
    }

}
