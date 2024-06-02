//
//  ColoredLogHandler.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2024/05/03.
//

import Foundation
import Logging

struct ColoredLogHandler: LogHandler {
    var label: String
    var logLevel: Logger.Level = .debug
    var metadata: Logger.Metadata = [:]
    
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { return metadata[key] }
        set { metadata[key] = newValue }
    }
    
    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        let emoji = emoji(for: level)
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let dateString = formatter.string(from: date)
        print("\(dateString) \(emoji)[\(level.rawValue.uppercased())] \(message)")
    }
    
    private func emoji(for level: Logger.Level) -> String {
        switch level {
            case .trace: return "🟤"
            case .debug: return "⚪️"
            case .info: return "🔵"
            case .notice: return "🟢"
            case .warning: return "🟡"
            case .error: return "🟠"
            case .critical: return "🔴"
        }
    }
}
