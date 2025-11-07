//
//  PDFExtractor.swift
//  AudioReader
//
//  Service for extracting text from PDF documents
//

import Foundation
import PDFKit

class PDFExtractor {
    static func extractText(from url: URL) async throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ExtractionError.invalidPDF
        }

        var fullText = ""

        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex) {
                if let pageText = page.string {
                    fullText += pageText + "\n\n"
                }
            }
        }

        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExtractionError.noTextFound
        }

        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractText(from data: Data) async throws -> String {
        guard let document = PDFDocument(data: data) else {
            throw ExtractionError.invalidPDF
        }

        var fullText = ""

        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex) {
                if let pageText = page.string {
                    fullText += pageText + "\n\n"
                }
            }
        }

        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExtractionError.noTextFound
        }

        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ExtractionError: LocalizedError {
    case invalidPDF
    case invalidURL
    case noTextFound
    case networkError
    case imageProcessingFailed

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "Unable to read PDF file"
        case .invalidURL:
            return "Invalid URL provided"
        case .noTextFound:
            return "No text content found"
        case .networkError:
            return "Failed to load web page"
        case .imageProcessingFailed:
            return "Failed to extract text from image"
        }
    }
}
