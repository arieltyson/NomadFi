// ImageMetadataStripper.swift
// NomadFi
//
// Strips EXIF metadata (GPS coordinates, camera model, timestamps)
// from receipt images before storage and export to prevent
// unintentional location and device information leakage.

import CoreGraphics
import ImageIO
import OSLog
import UniformTypeIdentifiers

/// Removes privacy-sensitive metadata from images.
///
/// Receipt photos captured by the camera contain EXIF metadata including:
/// - **GPS coordinates** — reveals where the receipt was scanned
/// - **Camera model** — identifies the user's device
/// - **Date/time** — original capture timestamp with timezone
/// - **Thumbnail** — embedded preview that may bypass stripping
///
/// NomadFi strips all of this before storing images to disk and before
/// including images in exported tax reports. The pixel data is preserved
/// exactly — only the metadata envelope is removed.
///
/// - Important: This operates at the CGImageSource level using ImageIO,
///   which is the most memory-efficient approach. No full bitmap decoding
///   is required.
enum ImageMetadataStripper {

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "MetadataStripper"
    )

    /// Metadata dictionary keys to remove from images.
    ///
    /// These correspond to EXIF, GPS, TIFF, and IPTC metadata blocks
    /// that may contain personally identifiable information.
    ///
    /// - Note: `nonisolated(unsafe)` is safe here because the array is
    ///   a compile-time constant that is never mutated after initialization.
    ///   `CFString` does not conform to `Sendable` but these specific
    ///   ImageIO constants are immutable global symbols.
    nonisolated(unsafe) private static let sensitiveMetadataKeys: [CFString] = [
        kCGImagePropertyGPSDictionary,
        kCGImagePropertyExifDictionary,
        kCGImagePropertyExifAuxDictionary,
        kCGImagePropertyTIFFDictionary,
        kCGImagePropertyIPTCDictionary,
        kCGImagePropertyMakerAppleDictionary
    ]

    /// Strips all EXIF, GPS, TIFF, and IPTC metadata from JPEG image data.
    ///
    /// The returned data contains only pixel data with basic color profile
    /// information — no location, device, or timestamp metadata.
    ///
    /// - Parameter data: The original JPEG image data (may contain EXIF metadata).
    /// - Returns: Cleaned JPEG data with metadata stripped, or the original
    ///   data if stripping fails (fail-open to avoid data loss).
    static func stripMetadata(from data: Data) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source)
        else {
            logger.warning("Could not create image source for metadata stripping")
            return data
        }

        // Read existing properties to verify what we're removing
        let originalProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]

        let hasGPS = originalProperties?[kCGImagePropertyGPSDictionary] != nil
        let hasEXIF = originalProperties?[kCGImagePropertyExifDictionary] != nil

        // Create destination data buffer
        let mutableData = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            type,
            CGImageSourceGetCount(source),
            nil
        ) else {
            logger.warning("Could not create image destination for metadata stripping")
            return data
        }

        // Build clean properties — explicitly null out all sensitive keys
        var cleanProperties: [CFString: Any] = [:]
        for key in sensitiveMetadataKeys {
            cleanProperties[key] = kCFNull
        }

        // Preserve orientation and color profile only
        if let orientation = originalProperties?[kCGImagePropertyOrientation] {
            cleanProperties[kCGImagePropertyOrientation] = orientation
        }
        if let colorModel = originalProperties?[kCGImagePropertyColorModel] {
            cleanProperties[kCGImagePropertyColorModel] = colorModel
        }
        if let profileName = originalProperties?[kCGImagePropertyProfileName] {
            cleanProperties[kCGImagePropertyProfileName] = profileName
        }

        // Copy each image frame with cleaned properties
        let count = CGImageSourceGetCount(source)
        for index in 0..<count {
            CGImageDestinationAddImageFromSource(
                destination,
                source,
                index,
                cleanProperties as CFDictionary
            )
        }

        guard CGImageDestinationFinalize(destination) else {
            logger.warning("Could not finalize stripped image")
            return data
        }

        if hasGPS || hasEXIF {
            logger.info(
                "Stripped metadata: GPS=\(hasGPS, privacy: .public), EXIF=\(hasEXIF, privacy: .public)"
            )
        }

        return mutableData as Data
    }

    /// Strips metadata from an image file and writes the cleaned version
    /// to a destination URL.
    ///
    /// Used during tax report export to ensure receipt images included
    /// in the `.zip` archive contain no location or device metadata.
    ///
    /// - Parameters:
    ///   - sourceURL: The original image file.
    ///   - destinationURL: Where to write the cleaned image.
    /// - Returns: `true` if the stripped image was written successfully.
    @discardableResult
    static func stripMetadata(
        from sourceURL: URL,
        to destinationURL: URL
    ) -> Bool {
        guard let data = try? Data(contentsOf: sourceURL) else {
            logger.warning("Could not read image at \(sourceURL.lastPathComponent, privacy: .public)")
            return false
        }

        let strippedData = stripMetadata(from: data)

        do {
            try strippedData.write(to: destinationURL)
            return true
        } catch {
            logger.warning(
                "Could not write stripped image: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }
}
