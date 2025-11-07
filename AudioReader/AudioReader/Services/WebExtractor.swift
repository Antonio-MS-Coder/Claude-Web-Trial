//
//  WebExtractor.swift
//  AudioReader
//
//  Service for extracting readable content from web pages
//

import Foundation
import WebKit

class WebExtractor {
    static func extractText(from urlString: String) async throws -> (title: String, content: String) {
        guard let url = URL(string: urlString) else {
            throw ExtractionError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let html = String(data: data, encoding: .utf8) else {
            throw ExtractionError.networkError
        }

        // Extract title
        let title = extractTitle(from: html) ?? url.host ?? "Web Article"

        // Basic HTML to text conversion
        // Remove script and style tags
        var cleanedHTML = html
        cleanedHTML = cleanedHTML.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression
        )
        cleanedHTML = cleanedHTML.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression
        )

        // Remove HTML tags
        cleanedHTML = cleanedHTML.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        // Decode HTML entities
        cleanedHTML = cleanedHTML.replacingOccurrences(of: "&nbsp;", with: " ")
        cleanedHTML = cleanedHTML.replacingOccurrences(of: "&amp;", with: "&")
        cleanedHTML = cleanedHTML.replacingOccurrences(of: "&lt;", with: "<")
        cleanedHTML = cleanedHTML.replacingOccurrences(of: "&gt;", with: ">")
        cleanedHTML = cleanedHTML.replacingOccurrences(of: "&quot;", with: "\"")

        // Clean up whitespace
        cleanedHTML = cleanedHTML.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        cleanedHTML = cleanedHTML.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedHTML.isEmpty else {
            throw ExtractionError.noTextFound
        }

        return (title, cleanedHTML)
    }

    private static func extractTitle(from html: String) -> String? {
        let pattern = "<title>(.*?)</title>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let nsString = html as NSString
        let results = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))

        if let match = results.first {
            let titleRange = match.range(at: 1)
            return nsString.substring(with: titleRange)
        }

        return nil
    }
}
