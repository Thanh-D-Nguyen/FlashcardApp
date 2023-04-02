import Foundation
import Alamofire

class AlamofireRequestBuilderFactory: RequestBuilderFactory {
    func getNonDecodableBuilder<T>() -> RequestBuilder<T>.Type {
        return AlamofireRequestBuilder<T>.self
    }

    func getBuilder<T:Decodable>() -> RequestBuilder<T>.Type {
        return AlamofireDecodableRequestBuilder<T>.self
    }
}

// Store manager to retain its reference
private var managerStore: [String: Alamofire.Session] = [:]

// Sync queue to manage safe access to the store manager
private let syncQueue = DispatchQueue(label: "thread-safe-sync-queue", attributes: .concurrent)

open class AlamofireRequestBuilder<T>: RequestBuilder<T> {
    required public init(method: String, URLString: String, parameters: [String : Any]?, isBody: Bool, headers: HTTPHeaders = HTTPHeaders()) {
        super.init(method: method, URLString: URLString, parameters: parameters, isBody: isBody, headers: headers)
    }
    /**
     May be overridden by a subclass if you want to control the session
     configuration.
     */
    open func createSession() -> Alamofire.Session {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = buildHeaders()
        return Alamofire.Session(configuration: configuration)
    }
    /**
     May be overridden by a subclass if you want to control the Content-Type
     that is given to an uploaded form part.

     Return nil to use the default behavior (inferring the Content-Type from
     the file extension).  Return the desired Content-Type otherwise.
     */
    open func contentTypeForFormPart(fileURL: URL) -> String? {
        return nil
    }

    /**
     May be overridden by a subclass if you want to control the request
     configuration (e.g. to override the cache policy).
     */
    open func makeRequest(manager: Session, method: HTTPMethod, encoding: ParameterEncoding, headers: HTTPHeaders) -> DataRequest {
        return manager.request(URLString, method: method, parameters: parameters, encoding: encoding, headers: headers)
    }

    override open func execute(_ completion: @escaping (_ response: Response<T>?, _ error: Error?) -> Void) {
        let managerId:String = UUID().uuidString
        // Create a new manager for each request to customize its request header
        let manager = createSession()
        syncQueue.async(flags: .barrier) {
            managerStore[managerId] = manager
        }

        let encoding:ParameterEncoding = isBody ? JSONDataEncoding() : URLEncoding()

        let xMethod = Alamofire.HTTPMethod(rawValue: method)
        let fileKeys = parameters == nil ? [] : parameters!.filter { $1 is NSURL }
                                                           .map { $0.0 }

        if fileKeys.count > 0 {
            _ = try? manager.upload(multipartFormData: { mpForm in
                for (k, v) in self.parameters! {
                    switch v {
                    case let fileURL as URL:
                        if let mimeType = self.contentTypeForFormPart(fileURL: fileURL) {
                            mpForm.append(fileURL, withName: k, fileName: fileURL.lastPathComponent, mimeType: mimeType)
                        }
                        else {
                            mpForm.append(fileURL, withName: k)
                        }
                    case let string as String:
                        mpForm.append(string.data(using: String.Encoding.utf8)!, withName: k)
                    case let number as NSNumber:
                        mpForm.append(number.stringValue.data(using: String.Encoding.utf8)!, withName: k)
                    default:
                        fatalError("Unprocessable value \(v) with key \(k)")
                    }
                }
            }, to: URLString.asURL()).uploadProgress(queue: .main, closure: { progress in
                if let onProgressReady = self.onProgressReady {
                    onProgressReady(progress)
                }
            })
        } else {
            let request = makeRequest(manager: manager, method: xMethod, encoding: encoding, headers: headers)
            if let onProgressReady = self.onProgressReady {
                onProgressReady(request.uploadProgress)
            }
            processRequest(request: request, managerId, completion)
        }

    }

    fileprivate func processRequest(request: DataRequest, _ managerId: String, _ completion: @escaping (_ response: Response<T>?, _ error: Error?) -> Void) {
        if let credential = self.credential {
            request.authenticate(with: credential)
        }

        let cleanupRequest = {
            syncQueue.async(flags: .barrier) {
                 _ = managerStore.removeValue(forKey: managerId)
            }
        }

        let validatedRequest = request.validate()

        switch T.self {
        case is String.Type:
            validatedRequest.responseString { response in
                cleanupRequest()
                switch response.result {
                case .success(let string):
                    let responseResult = Response(statusCode: response.response?.statusCode ?? 500, header: [:], body: string as? T)
                    completion(responseResult, nil)
                case .failure(let error):
                    completion(nil, ErrorResponse.error(response.response?.statusCode ?? 500, response.data, error))
                }
            }
        case is URL.Type:
            validatedRequest.responseData { dataResponse in
                cleanupRequest()
                switch dataResponse.result {
                case .success(let data):
                    do {
                        let fileManager = FileManager.default
                        let urlRequest = request.convertible.urlRequest!
                        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let requestURL = try self.getURL(from: urlRequest)

                        var requestPath = try self.getPath(from: requestURL)

                        if let headerFileName = self.getFileName(fromContentDisposition: dataResponse.response?.allHeaderFields["Content-Disposition"] as? String) {
                            requestPath = requestPath.appending("/\(headerFileName)")
                        }

                        let filePath = documentsDirectory.appendingPathComponent(requestPath)
                        let directoryPath = filePath.deletingLastPathComponent().path

                        try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
                        try data.write(to: filePath, options: .atomic)
                        completion(Response(response: dataResponse.response!, body: (filePath as! T)), nil)
                    } catch {
                        print(error)
                    }
                    
                case .failure(let error):
                    completion(nil, ErrorResponse.error(400, dataResponse.data, error))
                }
            }
        case is Void.Type:
            validatedRequest.responseData { voidResponse in
                cleanupRequest()
                switch voidResponse.result {
                case .success(let data):
                    completion(Response(response: voidResponse.response!, body: data as? T), nil)
                case .failure(let error):
                    completion(nil, ErrorResponse.error(voidResponse.response?.statusCode ?? 500, voidResponse.data, error))
                }
            }
        default:
            validatedRequest.responseData(completionHandler: { dataResponse in
                cleanupRequest()
                switch dataResponse.result {
                case .success(let data):
                    completion(Response(response: dataResponse.response!, body: data as? T), nil)
                case .failure(let error):
                    completion(nil, ErrorResponse.error(dataResponse.response?.statusCode ?? 500, dataResponse.data, error))
                }
                
            })
        }
    }

    open func buildHeaders() -> [String: String] {
        var httpHeaders = [String: String]()
        for header in self.headers {
            httpHeaders[header.name] = header.value
        }
        return httpHeaders
    }

    fileprivate func getFileName(fromContentDisposition contentDisposition : String?) -> String? {

        guard let contentDisposition = contentDisposition else {
            return nil
        }

        let items = contentDisposition.components(separatedBy: ";")

        var filename : String? = nil

        for contentItem in items {

            let filenameKey = "filename="
            guard let range = contentItem.range(of: filenameKey) else {
                break
            }

            filename = contentItem
            return filename?
                .replacingCharacters(in: range, with:"")
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return filename

    }

    fileprivate func getPath(from url : URL) throws -> String {

        guard var path = URLComponents(url: url, resolvingAgainstBaseURL: true)?.path else {
            throw DownloadException.requestMissingPath
        }

        if path.hasPrefix("/") {
            path.remove(at: path.startIndex)
        }

        return path

    }

    fileprivate func getURL(from urlRequest : URLRequest) throws -> URL {

        guard let url = urlRequest.url else {
            throw DownloadException.requestMissingURL
        }

        return url
    }

}

fileprivate enum DownloadException : Error {
    case responseDataMissing
    case responseFailed
    case requestMissing
    case requestMissingPath
    case requestMissingURL
}

public enum AlamofireDecodableRequestBuilderError: Error {
    case emptyDataResponse
    case nilHTTPResponse
    case jsonDecoding(DecodingError)
    case generalError(Error)
}

open class AlamofireDecodableRequestBuilder<T:Decodable>: AlamofireRequestBuilder<T> {

    override fileprivate func processRequest(request: DataRequest, _ managerId: String, _ completion: @escaping (_ response: Response<T>?, _ error: Error?) -> Void) {
        if let credential = self.credential {
            request.authenticate(with: credential)
        }

        let cleanupRequest = {
            syncQueue.async(flags: .barrier) {
                _ = managerStore.removeValue(forKey: managerId)
            }
        }

        let validatedRequest = request.validate()

        switch T.self {
        case is String.Type:
            validatedRequest.responseString(completionHandler: { stringResponse in
                cleanupRequest()
                switch stringResponse.result {
                case .success(let data):
                    completion(Response(response: stringResponse.response!, body: (data as? T)), nil)
                case .failure(let error):
                    completion(nil, ErrorResponse.error(stringResponse.response?.statusCode ?? 500, stringResponse.data, error))
                }
            })
        case is Void.Type:
            validatedRequest.responseData(completionHandler: { voidResponse in
                cleanupRequest()
                switch voidResponse.result {
                case .success(let data):
                    completion(Response(response: voidResponse.response!, body: data as? T), nil)
                case .failure(let error):
                    completion(nil, ErrorResponse.error(voidResponse.response?.statusCode ?? 500, voidResponse.data, error))
                }
            })
        case is Data.Type:
            validatedRequest.responseData(completionHandler: { (dataResponse) in
                cleanupRequest()
                switch dataResponse.result {
                case .success(let data):
                    completion(Response(response: dataResponse.response!, body: data as? T), nil)
                case .failure(let error):
                    completion(nil, ErrorResponse.error(dataResponse.response?.statusCode ?? 500, dataResponse.data, error))
                }
            })
        default:
            validatedRequest.responseData(completionHandler: { dataResponse in
                cleanupRequest()
                switch dataResponse.result {
                case .success(let data):
                    var responseObj: Response<T>? = nil
                    let decodeResult: (decodableObj: T?, error: Error?) = CodableHelper.decode(T.self, from: data)
                    if decodeResult.error == nil {
                        responseObj = Response(response: dataResponse.response!, body: decodeResult.decodableObj)
                    }

                    completion(responseObj, decodeResult.error)
                case .failure(let error):
                    completion(nil, error)

                }
            })
        }
    }

}
