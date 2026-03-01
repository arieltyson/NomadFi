// DownsampledImage.swift
// NomadFi
//
// A memory-efficient image view that loads images at the exact
// target resolution using ImageIO downsampling.

import SwiftUI

/// Displays an image from a file URL, downsampled to the target size.
///
/// Unlike `AsyncImage(url:)` which loads the full-resolution bitmap,
/// this view uses ``ImageDownsampler`` to decode only the pixels needed
/// for the display size. Thumbnails are cached in ``ThumbnailCache``
/// for instant reuse in scrolling lists.
///
/// Designed for the Tax Vault receipt list where dozens of
/// multi-megabyte receipt images must display as 44×44pt thumbnails.
///
/// ```swift
/// DownsampledImage(url: document.imageURL, size: CGSize(width: 44, height: 44))
/// ```
struct DownsampledImage: View {

    let url: URL?
    let size: CGSize
    var contentMode: ContentMode = .fill

    @State private var cgImage: CGImage?
    @State private var isLoading = true

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Group {
            if let cgImage {
                Image(decorative: cgImage, scale: displayScale)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                Rectangle()
                    .fill(ColorTokens.surfaceTertiary)
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            } else {
                fallbackPlaceholder
            }
        }
        .frame(width: size.width, height: size.height)
        .task(id: url) {
            await loadThumbnail()
        }
    }
}

// MARK: - Subviews

private struct FallbackPlaceholder: View {

    var body: some View {
        Rectangle()
            .fill(ColorTokens.surfaceTertiary)
            .overlay {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
    }
}

// MARK: - Private Helpers

private extension DownsampledImage {

    var fallbackPlaceholder: some View {
        FallbackPlaceholder()
    }

    func loadThumbnail() async {
        guard let url else {
            isLoading = false
            return
        }

        // Load on a background thread to avoid blocking the main thread
        let thumbnail = await Task.detached(priority: .utility) {
            ThumbnailCache.shared.thumbnail(
                for: url,
                pointSize: size,
                scale: await MainActor.run { displayScale }
            )
        }.value

        cgImage = thumbnail
        isLoading = false
    }
}

#Preview {
    VStack(spacing: SpacingTokens.medium) {
        DownsampledImage(
            url: nil,
            size: CGSize(width: 44, height: 44)
        )

        DownsampledImage(
            url: nil,
            size: CGSize(width: 200, height: 300),
            contentMode: .fit
        )
    }
    .padding()
}
