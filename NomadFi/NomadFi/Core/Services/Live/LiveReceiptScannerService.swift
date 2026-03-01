// LiveReceiptScannerService.swift
// NomadFi
//
// On-device receipt OCR using the Vision framework.
// Extracts merchant names, totals, dates, and line items
// from receipt images without any network requests.

import Foundation
import OSLog
import Vision

/// Live implementation of ``ReceiptScannerService`` using Apple's Vision framework.
///
/// Performs on-device text recognition with `.accurate` recognition level
/// for high-quality receipt OCR. All processing happens locally — no receipt
/// data ever leaves the device.
///
/// - Important: Processes images synchronously on a background thread via
///   `VNImageRequestHandler`. The `async` interface is provided for
///   structured concurrency compatibility.
struct LiveReceiptScannerService: ReceiptScannerService {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "ReceiptScanner")

    func extractReceiptData(from imageURL: URL) async throws -> ReceiptScanResult {
        let recognizedText = try await recognizeText(in: imageURL)

        guard !recognizedText.isEmpty else {
            Self.logger.warning("No text recognized in receipt image")
            throw ReceiptScannerError.recognitionFailed
        }

        let rawText = recognizedText.joined(separator: "\n")
        Self.logger.info("OCR extracted \(recognizedText.count) lines from receipt")

        let merchantName = extractMerchantName(from: recognizedText)
        let totalAmount = extractTotal(from: recognizedText)
        let currencyCode = detectCurrency(from: rawText)
        let date = extractDate(from: recognizedText)
        let lineItems = extractLineItems(from: recognizedText)

        return ReceiptScanResult(
            merchantName: merchantName,
            totalAmount: totalAmount,
            currencyCode: currencyCode,
            date: date,
            rawText: rawText,
            lineItems: lineItems
        )
    }
}

// MARK: - Vision OCR

private extension LiveReceiptScannerService {

    /// Performs text recognition on the image using VNRecognizeTextRequest.
    func recognizeText(in imageURL: URL) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let handler = VNImageRequestHandler(url: imageURL)

                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let lines = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    continuation.resume(returning: lines)
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ReceiptScannerError.recognitionFailed)
            }
        }
    }
}

// MARK: - Text Extraction Helpers

private extension LiveReceiptScannerService {

    /// Extracts the merchant name — typically the first non-empty,
    /// non-numeric line on the receipt.
    func extractMerchantName(from lines: [String]) -> String? {
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Skip lines that are mostly numbers (addresses, phone numbers, dates)
            let letterCount = trimmed.filter(\.isLetter).count
            let totalCount = trimmed.count
            if totalCount > 0, Double(letterCount) / Double(totalCount) > 0.5 {
                // Skip very short lines and common receipt headers
                if trimmed.count >= 3
                    && !trimmed.localizedStandardContains("receipt")
                    && !trimmed.localizedStandardContains("welcome")
                {
                    return trimmed
                }
            }
        }
        return nil
    }

    /// Extracts the total amount by looking for "TOTAL" keywords.
    func extractTotal(from lines: [String]) -> Double? {
        let totalPatterns = ["TOTAL", "AMOUNT DUE", "BALANCE DUE", "GRAND TOTAL"]

        // Search from bottom up — totals are typically near the end
        for line in lines.reversed() {
            let uppercased = line.uppercased()
            for pattern in totalPatterns {
                if uppercased.contains(pattern) && !uppercased.contains("SUB") {
                    if let amount = extractAmount(from: line) {
                        return amount
                    }
                }
            }
        }

        // Fallback: look for the largest amount on the receipt
        let amounts = lines.compactMap { extractAmount(from: $0) }
        return amounts.max()
    }

    /// Extracts a monetary amount from a line of text.
    func extractAmount(from text: String) -> Double? {
        // Match patterns like $12.99, 12.99, $1,234.56
        let pattern = #"[\$€£]?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2}))"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: text,
                  range: NSRange(text.startIndex..., in: text)
              )
        else {
            return nil
        }

        if let range = Range(match.range(at: 1), in: text) {
            let amountString = String(text[range]).replacing(",", with: "")
            return Double(amountString)
        }
        return nil
    }

    /// Detects the currency from symbol presence in the receipt text.
    func detectCurrency(from text: String) -> CurrencyCode? {
        if text.contains("$") {
            // Could be USD, CAD, or TTD — default to USD
            if text.localizedStandardContains("CA") || text.localizedStandardContains("Canada") {
                return .cad
            } else if text.localizedStandardContains("TT") || text.localizedStandardContains("Trinidad") {
                return .ttd
            }
            return .usd
        } else if text.contains("£") {
            return .gbp
        } else if text.contains("€") {
            return .eur
        } else if text.contains("₹") {
            return .inr
        } else if text.contains("₦") {
            return .ngn
        }
        return nil
    }

    /// Extracts a date from the receipt lines.
    func extractDate(from lines: [String]) -> Date? {
        let datePatterns = [
            "MM/dd/yyyy", "MM/dd/yy", "dd/MM/yyyy", "dd/MM/yy",
            "yyyy-MM-dd", "MMM dd, yyyy", "MMMM dd, yyyy",
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for line in lines {
            for pattern in datePatterns {
                formatter.dateFormat = pattern
                // Try to find a date substring in each line
                let words = line.split(separator: " ").map(String.init)
                for i in 0..<words.count {
                    for length in 1...min(3, words.count - i) {
                        let candidate = words[i..<(i + length)].joined(separator: " ")
                        if let date = formatter.date(from: candidate) {
                            return date
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Extracts individual line items (description + amount pairs).
    func extractLineItems(from lines: [String]) -> [ReceiptLineItem] {
        var items: [ReceiptLineItem] = []

        for line in lines {
            guard let amount = extractAmount(from: line) else { continue }

            let uppercased = line.uppercased()
            // Skip summary lines
            guard !uppercased.contains("TOTAL")
                    && !uppercased.contains("SUBTOTAL")
                    && !uppercased.contains("TAX")
                    && !uppercased.contains("CHANGE")
                    && !uppercased.contains("BALANCE")
            else {
                continue
            }

            // Extract the description by removing the amount portion
            let description = line
                .replacing(#/[\$€£₹₦]?\s*\d{1,3}(?:,\d{3})*(?:\.\d{2})/#, with: "")
                .trimmingCharacters(in: .whitespaces)

            if !description.isEmpty {
                items.append(ReceiptLineItem(description: description, amount: amount))
            }
        }

        return items
    }
}
