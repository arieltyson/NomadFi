// TaxVaultViewModel.swift
// NomadFi
//
// Manages Tax Vault state including document management, receipt scanning,
// auto-categorization, and export report generation.

import Foundation
import OSLog
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Manages the Tax Vault feature's state and business logic.
///
/// Coordinates receipt scanning via ``ReceiptScannerService``, auto-categorization
/// via ``ReceiptCategorizer``, document persistence via SwiftData, and PDF export.
/// Works alongside `@Query` in the view for reactive document lists.
@MainActor
@Observable
final class TaxVaultViewModel {

    // MARK: - State

    var isScanning = false
    var scanResult: ReceiptScanResult?
    var scanError: String?
    var selectedPhotoItem: PhotosPickerItem?
    var showingScanner = false
    var showingConfirmation = false
    var isExporting = false
    var exportURL: URL?
    var searchText = ""

    /// The draft document being reviewed before saving.
    var draftMerchantName = ""
    var draftAmount: Double = 0
    var draftCurrencyCode: CurrencyCode = .usd
    var draftDocumentDate: Date = .now
    var draftJurisdiction = ""
    var draftTaxCategory: TaxCategory = .other

    // MARK: - Dependencies

    private let services: ServiceContainer
    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "TaxVault")

    init(services: ServiceContainer = ServiceContainer()) {
        self.services = services
    }

    // MARK: - Tax Year & Filtering

    /// Returns the current tax year based on today's date.
    var currentTaxYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    /// Groups documents by tax year, sorted newest first.
    func documentsByTaxYear(_ documents: [TaxDocument]) -> [(year: Int, documents: [TaxDocument])] {
        let grouped = Dictionary(grouping: documents) { $0.taxYear }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (year: $0.key, documents: $0.value.sorted { $0.documentDate > $1.documentDate }) }
    }

    /// Groups documents for a given year by jurisdiction.
    func documentsByJurisdiction(
        _ documents: [TaxDocument],
        jurisdictions: [JurisdictionProfile]
    ) -> [(jurisdiction: JurisdictionProfile, documents: [TaxDocument])] {
        jurisdictions.compactMap { profile in
            let matching = documents.filter { $0.jurisdiction == profile.countryCode }
            guard !matching.isEmpty else { return nil }
            return (jurisdiction: profile, documents: matching)
        }
    }

    /// Filters documents by search text across merchant name, extracted text, and category.
    func filteredDocuments(_ documents: [TaxDocument]) -> [TaxDocument] {
        guard !searchText.isEmpty else { return documents }
        return documents.filter { doc in
            doc.merchantName.localizedStandardContains(searchText)
                || doc.extractedText.localizedStandardContains(searchText)
                || (doc.taxCategory?.displayName.localizedStandardContains(searchText) ?? false)
        }
    }

    /// Calculates the total amount for a given category within a set of documents.
    func categoryTotal(
        _ category: TaxCategory,
        in documents: [TaxDocument]
    ) -> Double {
        documents
            .filter { $0.taxCategoryRawValue == category.rawValue }
            .reduce(0) { $0 + $1.amount }
    }

    /// Returns all categories that have at least one document in the given set.
    func activeCategories(in documents: [TaxDocument]) -> [TaxCategory] {
        let rawValues = Set(documents.map(\.taxCategoryRawValue))
        return TaxCategory.allCases.filter { rawValues.contains($0.rawValue) }
    }

    // MARK: - Receipt Scanning

    /// Processes a selected photo from the photo picker.
    func processSelectedPhoto(modelContext: ModelContext) async {
        guard let item = selectedPhotoItem else { return }

        isScanning = true
        scanError = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ReceiptScannerError.imageLoadFailed
            }

            let imageURL = try saveImageToDocuments(data: data)
            let result = try await services.receiptScannerService.extractReceiptData(from: imageURL)

            scanResult = result
            populateDraft(from: result, imageURL: imageURL)
            showingConfirmation = true

            Self.logger.info("Receipt scanned: \(result.merchantName ?? "unknown merchant", privacy: .private)")
        } catch {
            scanError = error.localizedDescription
            Self.logger.error("Receipt scan failed: \(error.localizedDescription, privacy: .public)")
        }

        isScanning = false
    }

    /// Saves the confirmed draft document to SwiftData.
    func saveConfirmedDocument(modelContext: ModelContext) {
        let taxYear = Calendar.current.component(.year, from: draftDocumentDate)

        let sanitizedAmount = InputSanitizer.validateAmount(draftAmount) ?? 0

        let document = TaxDocument(
            merchantName: InputSanitizer.sanitizeShortText(draftMerchantName),
            amount: sanitizedAmount,
            currencyCode: draftCurrencyCode,
            documentDate: draftDocumentDate,
            taxYear: taxYear,
            jurisdiction: draftJurisdiction,
            taxCategory: draftTaxCategory,
            extractedText: InputSanitizer.sanitizeLongText(scanResult?.rawText ?? ""),
            imageRelativePath: pendingImagePath,
            scannedAt: .now,
            isVerified: true
        )

        modelContext.insert(document)
        Self.logger.info("Tax document saved: \(self.draftMerchantName, privacy: .private) for \(taxYear)")

        resetDraft()
    }

    /// Deletes a tax document and its associated image file.
    func deleteDocument(_ document: TaxDocument, modelContext: ModelContext) {
        // Remove the image file from disk
        if let imageURL = document.imageURL {
            try? FileManager.default.removeItem(at: imageURL)
        }
        modelContext.delete(document)
        Self.logger.info("Tax document deleted: \(document.merchantName, privacy: .private)")
    }

    // MARK: - Export

    /// Generates a structured export report for the given documents.
    func exportDocuments(
        _ documents: [TaxDocument],
        taxYear: Int,
        jurisdictions: [JurisdictionProfile]
    ) async {
        isExporting = true
        defer { isExporting = false }

        do {
            let url = try await PerformanceMonitor.measure(.export, name: "Generate Tax Report") {
                try await TaxReportExporter.generateReport(
                    documents: documents,
                    taxYear: taxYear,
                    jurisdictions: jurisdictions
                )
            }
            exportURL = url
            Self.logger.info("Tax report exported for \(taxYear)")
        } catch {
            scanError = "Export failed: \(error.localizedDescription)"
            Self.logger.error("Export failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Private Helpers

    private var pendingImagePath = ""

    /// Saves the receipt image to the documents directory.
    ///
    /// Caps the stored image at 2048px on the longest side to balance OCR
    /// quality with storage efficiency. A full 12MP camera image is ~4MB;
    /// downsampled to 2048px it's ~500KB — a 8× reduction that preserves
    /// all text readable by the Vision framework.
    ///
    /// EXIF metadata (GPS coordinates, camera model, timestamps) is stripped
    /// before writing to disk to prevent unintentional location leakage.
    private func saveImageToDocuments(data: Data) throws -> URL {
        let receiptsDir = URL.documentsDirectory.appending(path: "receipts")
        try FileManager.default.createDirectory(at: receiptsDir, withIntermediateDirectories: true)

        let filename = "receipt_\(Int(Date.now.timeIntervalSince1970)).jpg"
        let fileURL = receiptsDir.appending(path: filename)

        // Downsample before saving to reduce disk usage and future load times.
        // 2048px is sufficient for Vision OCR's .accurate recognition level.
        if let downsampledCGImage = ImageDownsampler.downsample(
            data: data,
            pointSize: CGSize(width: 2048, height: 2048),
            scale: 1.0
        ) {
            let uiImage = UIImage(cgImage: downsampledCGImage)
            if let jpegData = uiImage.jpegData(compressionQuality: 0.85) {
                // Strip EXIF/GPS metadata before writing to disk
                let cleanData = ImageMetadataStripper.stripMetadata(from: jpegData)
                try cleanData.write(to: fileURL)
                pendingImagePath = "receipts/\(filename)"
                return fileURL
            }
        }

        // Fall back to saving the original data if downsampling fails,
        // still stripping metadata for privacy
        let cleanData = ImageMetadataStripper.stripMetadata(from: data)
        try cleanData.write(to: fileURL)
        pendingImagePath = "receipts/\(filename)"

        return fileURL
    }

    private func populateDraft(from result: ReceiptScanResult, imageURL: URL) {
        draftMerchantName = result.merchantName ?? ""
        draftAmount = result.totalAmount ?? 0
        draftCurrencyCode = result.currencyCode ?? .usd
        draftDocumentDate = result.date ?? .now

        // Auto-categorize based on extracted text
        let categorization = ReceiptCategorizer.categorize(text: result.rawText)
        draftTaxCategory = categorization.category
        draftJurisdiction = categorization.jurisdiction ?? ""
    }

    private func resetDraft() {
        scanResult = nil
        selectedPhotoItem = nil
        draftMerchantName = ""
        draftAmount = 0
        draftCurrencyCode = .usd
        draftDocumentDate = .now
        draftJurisdiction = ""
        draftTaxCategory = .other
        pendingImagePath = ""
        showingConfirmation = false
    }
}
