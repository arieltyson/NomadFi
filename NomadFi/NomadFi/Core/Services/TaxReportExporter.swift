// TaxReportExporter.swift
// NomadFi
//
// Generates structured PDF tax reports organized by jurisdiction,
// bundled with receipt images into a shareable .zip archive.

import Foundation
import OSLog
import SwiftUI

/// Generates exportable tax reports as PDF documents bundled into a `.zip` archive.
///
/// Each jurisdiction gets its own PDF with categorized totals, a transaction list,
/// and receipt thumbnails. The archive is saved to a temporary directory for sharing
/// via `ShareLink`.
///
/// - Note: Uses `ImageRenderer` for PDF generation (SwiftUI-native, no UIKit).
enum TaxReportExporter {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "TaxExport")

    /// Generates a `.zip` archive containing PDF reports organized by jurisdiction.
    ///
    /// - Parameters:
    ///   - documents: The tax documents to include in the report.
    ///   - taxYear: The tax year for the report.
    ///   - jurisdictions: The user's jurisdiction profiles for grouping.
    /// - Returns: A file URL to the generated `.zip` archive.
    @MainActor
    static func generateReport(
        documents: [TaxDocument],
        taxYear: Int,
        jurisdictions: [JurisdictionProfile]
    ) async throws -> URL {
        let exportDir = FileManager.default.temporaryDirectory
            .appending(path: "NomadFi_Export_\(taxYear)")

        // Clean up any previous export
        try? FileManager.default.removeItem(at: exportDir)
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        // Group documents by jurisdiction
        let grouped = Dictionary(grouping: documents) { $0.jurisdiction }

        for (jurisdictionCode, docs) in grouped {
            let jurisdictionName = jurisdictions
                .first { $0.countryCode == jurisdictionCode }?.countryName ?? jurisdictionCode

            let pdfData = generatePDF(
                documents: docs,
                jurisdictionName: jurisdictionName,
                jurisdictionCode: jurisdictionCode,
                taxYear: taxYear
            )

            let pdfFilename = "NomadFi_TaxReport_\(jurisdictionCode)_\(taxYear).pdf"
            let pdfURL = exportDir.appending(path: pdfFilename)
            try pdfData.write(to: pdfURL)

            // Copy receipt images into a subdirectory, stripping any
            // residual EXIF/GPS metadata to prevent location leakage
            // in the exported archive.
            let receiptsDir = exportDir.appending(path: "\(jurisdictionCode)_Receipts")
            try FileManager.default.createDirectory(at: receiptsDir, withIntermediateDirectories: true)

            for doc in docs {
                if let imageURL = doc.imageURL,
                   FileManager.default.fileExists(atPath: imageURL.path())
                {
                    let destURL = receiptsDir.appending(path: imageURL.lastPathComponent)
                    ImageMetadataStripper.stripMetadata(from: imageURL, to: destURL)
                }
            }
        }

        // Create the .zip archive
        let zipURL = FileManager.default.temporaryDirectory
            .appending(path: "NomadFi_TaxReport_\(taxYear).zip")
        try? FileManager.default.removeItem(at: zipURL)

        let coordinator = NSFileCoordinator()
        var archiveError: NSError?

        coordinator.coordinate(
            readingItemAt: exportDir,
            options: .forUploading,
            error: &archiveError
        ) { zippedURL in
            try? FileManager.default.moveItem(at: zippedURL, to: zipURL)
        }

        if let archiveError {
            throw archiveError
        }

        // Clean up the unzipped export directory
        try? FileManager.default.removeItem(at: exportDir)

        logger.info("Tax report exported: \(zipURL.lastPathComponent)")
        return zipURL
    }

    // MARK: - PDF Generation

    /// Generates a PDF for a single jurisdiction's tax documents.
    private static func generatePDF(
        documents: [TaxDocument],
        jurisdictionName: String,
        jurisdictionCode: String,
        taxYear: Int
    ) -> Data {
        let pageWidth: CGFloat = 612  // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        return renderer.pdfData { context in
            context.beginPage()
            var yPosition: CGFloat = margin

            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.label,
            ]
            let title = "NomadFi Tax Report — \(jurisdictionName) \(taxYear)"
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40

            // Subtitle
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel,
            ]
            let subtitle = "Generated \(Date.now.formatted(date: .long, time: .shortened)) • \(documents.count) documents"
            subtitle.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: subtitleAttributes)
            yPosition += 30

            // Separator
            drawSeparator(in: context, at: yPosition, width: pageWidth, margin: margin)
            yPosition += 15

            // Category Totals
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.label,
            ]
            "Category Totals".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25

            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.label,
            ]

            let grouped = Dictionary(grouping: documents) { $0.taxCategoryRawValue }
            for (categoryRaw, docs) in grouped.sorted(by: { $0.key < $1.key }) {
                let categoryName = TaxCategory(rawValue: categoryRaw)?.displayName ?? categoryRaw
                let total = docs.reduce(0.0) { $0 + $1.amount }
                let currencySymbol = docs.first?.currencyCode?.symbol ?? "$"
                let formattedTotal = total.formatted(.number.precision(.fractionLength(2)))
                let line = "\(categoryName): \(currencySymbol)\(formattedTotal) (\(docs.count) items)"
                line.draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 18

                if yPosition > pageHeight - margin {
                    context.beginPage()
                    yPosition = margin
                }
            }

            yPosition += 15
            drawSeparator(in: context, at: yPosition, width: pageWidth, margin: margin)
            yPosition += 15

            // Document List
            "Documents".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium

            for doc in documents.sorted(by: { $0.documentDate > $1.documentDate }) {
                let currencySymbol = doc.currencyCode?.symbol ?? "$"
                let dateStr = dateFormatter.string(from: doc.documentDate)
                let formattedAmount = doc.amount.formatted(.number.precision(.fractionLength(2)))
                let line = "\(dateStr) — \(doc.merchantName) — \(currencySymbol)\(formattedAmount)"
                line.draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bodyAttributes)
                yPosition += 18

                if yPosition > pageHeight - margin {
                    context.beginPage()
                    yPosition = margin
                }
            }

            // Footer
            yPosition = pageHeight - margin - 20
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.tertiaryLabel,
            ]
            "Generated by NomadFi • For informational purposes only • Consult a tax professional"
                .draw(at: CGPoint(x: margin, y: yPosition), withAttributes: footerAttributes)
        }
    }

    private static func drawSeparator(
        in context: UIGraphicsPDFRendererContext,
        at y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: width - margin, y: y))
        UIColor.separator.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
}
