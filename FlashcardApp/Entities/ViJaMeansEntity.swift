//
//  ViJaMeansEntity.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/03/21.
//

import Foundation

struct ViJaMeanEntity: Codable {
    var kind, mean: String?
    var examples: [String]?
}

// MARK: MeanEntityElement convenience initializers and mutators

extension ViJaMeanEntity {
    init(data: Data) throws {
        self = try JSONDecoder().decode(ViJaMeanEntity.self, from: data)
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
        mean: String?? = nil,
        examples: [String]?? = nil
    ) -> ViJaMeanEntity {
        return ViJaMeanEntity(
            kind: kind ?? self.kind,
            mean: mean ?? self.mean,
            examples: examples ?? self.examples
        )
    }
    
    func jsonData() throws -> Data {
        return try JSONEncoder().encode(self)
    }
    
    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

typealias ViJaMeansEntity = [ViJaMeanEntity]

extension Array where Element == ViJaMeansEntity.Element {
    init(data: Data) throws {
        self = try JSONDecoder().decode(ViJaMeansEntity.self, from: data)
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
