// ReceiptScannerService.swift
// NomadFi
//
// Protocol defining receipt OCR operations for the Tax Vault.
// The live implementation uses VisionKit and Vision framework.

import Foundation

/// Defines the contract for extracting structured data from receipt images.
///
/// The live implementation uses `DataScannerViewController` for capture
/// and `VNRecognizeTextRequest` for on-device OCR.
protocol ReceiptScannerService: Sendable {

    /// Extracts structured receipt data from an image at the given URL.
    /// - Parameter imageURL: The file URL of the receipt image.
    /// - Returns: Extracted receipt data for user confirmation.
    func extractReceiptData(from imageURL: URL) async throws -> ReceiptScanResult
}

/// The structured data extracted from a scanned receipt.
struct ReceiptScanResult: Sendable {
    let merchantName: String?
    let totalAmount: Double?
    let currencyCode: CurrencyCode?
    let date: Date?
    let rawText: String
    let lineItems: [ReceiptLineItem]
}

/// A single line item extracted from a receipt.
struct ReceiptLineItem: Sendable {
    let description: String
    let amount: Double?
}
