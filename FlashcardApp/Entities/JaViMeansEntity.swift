//
//  JaViMeansEntity.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/03/21.
//

import Foundation

struct JaViMeanEntity: Codable {
    var kind: String?
    var mean: String
    var field: String?
    var check: Bool?
}

extension JaViMeanEntity {
    init(data: Data) throws {
        self = try JSONDecoder().decode(JaViMeanEntity.self, from: data)
    }
    
    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }
    
    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }
    
    func with(
        kind: String?? = nil,
        mean: String? = nil,
        field: String?? = nil,
        check: Bool?? = nil
    ) -> JaViMeanEntity {
        return JaViMeanEntity(
            kind: kind ?? self.kind,
            mean: mean ?? self.mean,
            field: field ?? self.field,
            check: check ?? self.check
        )
    }
    
    func jsonData() throws -> Data {
        return try JSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

typealias JaViMeansEntity = [JaViMeanEntity]

extension Array where Element == JaViMeansEntity.Element {
    init(data: Data) throws {
        self = try JSONDecoder().decode(JaViMeansEntity.self, from: data)
    }
    
    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }
    
    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }
    
    func jsonData() throws -> Data {
        return try JSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}
