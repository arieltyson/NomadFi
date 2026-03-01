// ImageDownsampler.swift
// NomadFi
//
// Memory-efficient image downsampling using ImageIO.
// Loads images at the exact target resolution without decoding
// the full bitmap into memory, critical for receipt thumbnails.

import CoreGraphics
import ImageIO
import OSLog
import SwiftUI

/// Provides memory-efficient image downsampling using ImageIO.
///
/// Unlike `UIImage(contentsOfFile:)` which decodes the entire bitmap,
/// `ImageDownsampler` uses `CGImageSource` to create thumbnails at
/// the exact target pixel size. This is critical for Tax Vault receipt
/// lists where dozens of multi-megabyte images would otherwise
/// consume hundreds of megabytes of memory.
///
/// All operations are synchronous and should be called from a
/// background context (e.g., inside a `Task` or `.task` modifier).
enum ImageDownsampler {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "ImageDownsampler")

    // MARK: - Thumbnail Generation

    /// Creates a downsampled `CGImage` from a file URL at the specified point size.
    ///
    /// Uses `CGImageSource` with `kCGImageSourceCreateThumbnailFromImageAlways`
    /// to decode only the required pixels. The actual pixel dimensions are
    /// calculated from the point size and the current display scale.
    ///
    /// - Parameters:
    ///   - url: The file URL of the source image.
    ///   - pointSize: The target size in points (will be scaled by display factor).
    ///   - scale: The display scale factor (defaults to 3x for modern iPhones).
    /// - Returns: A downsampled `CGImage`, or `nil` if the source is unreadable.
    static func downsample(
        url: URL,
        pointSize: CGSize,
        scale: CGFloat = 3.0
    ) -> CGImage? {
        PerformanceMonitor.measureSync(.imageProcessing, name: "Downsample Image") {
            let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
            ]

            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                logger.warning("Could not create image source from \(url.lastPathComponent, privacy: .public)")
                return nil
            }

            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                logger.warning("Could not create thumbnail for \(url.lastPathComponent, privacy: .public)")
                return nil
            }

            return thumbnail
        }
    }

    /// Creates a downsampled `CGImage` from raw image data at the specified point size.
    ///
    /// Useful when the image data is already in memory (e.g., from `PhotosPickerItem`).
    ///
    /// - Parameters:
    ///   - data: The raw image data (JPEG, PNG, HEIC, etc.).
    ///   - pointSize: The target size in points.
    ///   - scale: The display scale factor.
    /// - Returns: A downsampled `CGImage`, or `nil` if the data is invalid.
    static func downsample(
        data: Data,
        pointSize: CGSize,
        scale: CGFloat = 3.0
    ) -> CGImage? {
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

// MARK: - Thumbnail Cache

/// An in-memory LRU cache for downsampled receipt thumbnails.
///
/// Uses `NSCache` for automatic memory management — thumbnails are
/// evicted under memory pressure without manual intervention.
/// Thread-safe by design (NSCache is internally synchronized).
final class ThumbnailCache: @unchecked Sendable {

    /// Shared singleton for app-wide thumbnail caching.
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, CGImageWrapper>()
    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "ThumbnailCache")

    private init() {
        // Limit to ~50 thumbnails in memory (~50 × 44×44×3px ≈ 1.2MB)
        cache.countLimit = 50
    }

    /// Retrieves a cached thumbnail or generates one from the source URL.
    ///
    /// - Parameters:
    ///   - url: The file URL of the source image.
    ///   - pointSize: The target size in points.
    ///   - scale: The display scale factor.
    /// - Returns: A downsampled `CGImage`, or `nil` if generation fails.
    func thumbnail(
        for url: URL,
        pointSize: CGSize,
        scale: CGFloat = 3.0
    ) -> CGImage? {
        let key = url.absoluteString as NSString

        if let cached = cache.object(forKey: key) {
            return cached.image
        }

        guard let image = ImageDownsampler.downsample(
            url: url,
            pointSize: pointSize,
            scale: scale
        ) else {
            return nil
        }

        cache.setObject(CGImageWrapper(image: image), forKey: key)
        return image
    }

    /// Removes all cached thumbnails.
    func removeAll() {
        cache.removeAllObjects()
    }
}

/// A reference-type wrapper for `CGImage` required by `NSCache`.
private final class CGImageWrapper: @unchecked Sendable {
    let image: CGImage
    init(image: CGImage) { self.image = image }
}
