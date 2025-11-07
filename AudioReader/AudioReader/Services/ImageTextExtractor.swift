//
//  ImageTextExtractor.swift
//  AudioReader
//
//  Service for extracting text from images using Vision framework (OCR)
//

import Foundation
import Vision
import UIKit

class ImageTextExtractor {
    static func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw ExtractionError.imageProcessingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ExtractionError.noTextFound)
                    return
                }

                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                if recognizedText.isEmpty {
                    continuation.resume(throwing: ExtractionError.noTextFound)
                } else {
                    continuation.resume(returning: recognizedText)
                }
            }

            // Configure for best accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    static func extractText(from data: Data) async throws -> String {
        guard let image = UIImage(data: data) else {
            throw ExtractionError.imageProcessingFailed
        }

        return try await extractText(from: image)
    }
}
