//
//  APIErrorFilter.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/08.
//

import Foundation

class APIError: Error {
    let status: Int
    let message: String
    
    init(status: Int, message: String) {
        self.status = status
        self.message = message
    }
}

class APIErrorFilter {
    class func filter(_ response: Any?, _ error: Error?) -> APIError? {
        if let error = error {
            return APIError(status: 1, message: error.localizedDescription)
        }
        return nil
    }
}
