//
//  ContentItem.swift
//  AudioReader
//
//  Data model for content items that can be converted to audio
//

import Foundation
import SwiftUI

enum ContentType: String, Codable, CaseIterable {
    case pdf = "PDF"
    case webpage = "Web Page"
    case text = "Text"
    case image = "Image"

    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .webpage: return "globe"
        case .text: return "text.alignleft"
        case .image: return "photo"
        }
    }

    var color: Color {
        switch self {
        case .pdf: return .red
        case .webpage: return .blue
        case .text: return .green
        case .image: return .purple
        }
    }
}

struct ContentItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var type: ContentType
    var extractedText: String
    var dateAdded: Date
    var duration: TimeInterval // Estimated duration in seconds
    var lastPlayedPosition: TimeInterval
    var isFavorite: Bool

    init(id: UUID = UUID(),
         title: String,
         type: ContentType,
         extractedText: String,
         dateAdded: Date = Date(),
         duration: TimeInterval = 0,
         lastPlayedPosition: TimeInterval = 0,
         isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.type = type
        self.extractedText = extractedText
        self.dateAdded = dateAdded
        self.duration = duration > 0 ? duration : Self.estimateDuration(for: extractedText)
        self.lastPlayedPosition = lastPlayedPosition
        self.isFavorite = isFavorite
    }

    // Estimate audio duration based on text length (avg 150 words per minute)
    static func estimateDuration(for text: String) -> TimeInterval {
        let wordCount = text.split(separator: " ").count
        return Double(wordCount) / 150.0 * 60.0 // Convert to seconds
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
