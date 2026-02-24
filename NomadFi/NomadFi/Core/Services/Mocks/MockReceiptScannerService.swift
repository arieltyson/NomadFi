// MockReceiptScannerService.swift
// NomadFi
//
// Mock implementation of ReceiptScannerService for Previews and testing.

import Foundation

/// A mock receipt scanner that returns sample extracted data.
///
/// Simulates a successful OCR scan of a US grocery receipt.
struct MockReceiptScannerService: ReceiptScannerService {

    var simulatedDelay: Duration = .milliseconds(500)
    var shouldFail: Bool = false

    func extractReceiptData(from imageURL: URL) async throws -> ReceiptScanResult {
        try await Task.sleep(for: simulatedDelay)

        if shouldFail {
            throw ReceiptScannerError.recognitionFailed
        }

        return ReceiptScanResult(
            merchantName: "Whole Foods Market",
            totalAmount: 67.43,
            currencyCode: .usd,
            date: .now,
            rawText: "WHOLE FOODS MARKET\n1765 California St\nSan Francisco, CA 94109\n\nOrganic Bananas  2.49\nAlmond Milk      4.99\nSourdough Bread  5.49\nChicken Breast  12.99\nMixed Greens     4.49\n\nSUBTOTAL       30.45\nTAX             2.67\nTOTAL          67.43",
            lineItems: [
                ReceiptLineItem(description: "Organic Bananas", amount: 2.49),
                ReceiptLineItem(description: "Almond Milk", amount: 4.99),
                ReceiptLineItem(description: "Sourdough Bread", amount: 5.49),
                ReceiptLineItem(description: "Chicken Breast", amount: 12.99),
                ReceiptLineItem(description: "Mixed Greens", amount: 4.49),
            ]
        )
    }
}

/// Errors that can occur during receipt scanning.
enum ReceiptScannerError: Error, LocalizedError, Sendable {
    case recognitionFailed
    case cameraUnavailable
    case imageLoadFailed

    var errorDescription: String? {
        switch self {
        case .recognitionFailed: "Could not read the receipt. Try taking a clearer photo."
        case .cameraUnavailable: "Camera is not available on this device."
        case .imageLoadFailed: "Unable to load the selected image."
        }
    }
}
