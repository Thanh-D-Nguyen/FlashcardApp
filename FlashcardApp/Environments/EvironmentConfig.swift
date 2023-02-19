//
//  EvironmentConfig.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//

import Foundation

class EnvironmentConfig {
    static private func infoForKey(_ key: String) -> String? {
        return (Bundle.main.infoDictionary?[key] as? String)?
            .replacingOccurrences(of: "\\", with: "")
    }
    
    static func baseUrl() -> String {
        return infoForKey("ProductBaseUrl")!
    }
}
