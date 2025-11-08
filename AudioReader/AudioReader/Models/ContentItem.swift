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
    var detectedLanguage: String // ISO language code (e.g., "en", "es")
    var manualLanguageOverride: String? // User can manually set language

    init(id: UUID = UUID(),
         title: String,
         type: ContentType,
         extractedText: String,
         dateAdded: Date = Date(),
         duration: TimeInterval = 0,
         lastPlayedPosition: TimeInterval = 0,
         isFavorite: Bool = false,
         detectedLanguage: String? = nil,
         manualLanguageOverride: String? = nil) {
        self.id = id
        self.title = title
        self.type = type
        self.extractedText = extractedText
        self.dateAdded = dateAdded
        self.duration = duration > 0 ? duration : Self.estimateDuration(for: extractedText)
        self.lastPlayedPosition = lastPlayedPosition
        self.isFavorite = isFavorite
        self.detectedLanguage = detectedLanguage ?? Self.detectLanguage(from: extractedText)
        self.manualLanguageOverride = manualLanguageOverride
    }

    // Get the effective language to use (manual override takes precedence)
    var effectiveLanguage: String {
        return manualLanguageOverride ?? detectedLanguage
    }

    // Estimate audio duration based on text length (avg 150 words per minute)
    static func estimateDuration(for text: String) -> TimeInterval {
        let wordCount = text.split(separator: " ").count
        return Double(wordCount) / 150.0 * 60.0 // Convert to seconds
    }

    // Detect language using NSLinguisticTagger
    static func detectLanguage(from text: String) -> String {
        // Need a reasonable sample for accurate detection
        let sampleText = String(text.prefix(min(500, text.count)))

        guard !sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "en" // Default to English for empty text
        }

        let tagger = NSLinguisticTagger(tagSchemes: [.language], options: 0)
        tagger.string = sampleText

        let language = tagger.dominantLanguage ?? "en"

        // Extract just the language code (e.g., "es" from "es-ES")
        let languageCode = language.split(separator: "-").first.map(String.init) ?? "en"

        print("🌍 Detected language: \(languageCode) for text sample: \(sampleText.prefix(50))...")

        return languageCode
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var languageDisplayName: String {
        let locale = Locale(identifier: "en")
        return locale.localizedString(forLanguageCode: effectiveLanguage)?.capitalized ?? effectiveLanguage.uppercased()
    }

    // Get list of commonly supported languages
    static var supportedLanguages: [(code: String, name: String)] {
        let languageCodes = ["en", "es", "fr", "de", "it", "pt", "ja", "ko", "zh", "ru", "ar", "nl", "sv", "da", "no", "fi", "pl", "tr", "hi"]
        let locale = Locale(identifier: "en")

        return languageCodes.compactMap { code in
            guard let name = locale.localizedString(forLanguageCode: code) else { return nil }
            return (code: code, name: name.capitalized)
        }.sorted { $0.name < $1.name }
    }
}
