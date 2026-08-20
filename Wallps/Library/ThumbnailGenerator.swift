import AppKit
import AVFoundation
import Foundation

/// Extracts a representative frame from a video and writes it as a JPEG.
enum ThumbnailGenerator {
    static func generate(
        from videoURL: URL,
        to destination: URL,
        maxDimension: CGFloat = 640
    ) async throws {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        // Snapping to the nearest keyframe instead of decoding to an exact time
        // makes this an order of magnitude faster, and any nearby frame is an
        // equally good thumbnail.
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity

        // Sample from the middle: intros and fades make poor thumbnails.
        let duration = (try? await asset.load(.duration).seconds) ?? 0
        let target = duration.isFinite && duration > 0 ? duration * 0.4 : 0
        let time = CMTime(seconds: target, preferredTimescale: 600)

        let cgImage: CGImage
        do {
            (cgImage, _) = try await generator.image(at: time)
        } catch {
            (cgImage, _) = try await generator.image(at: .zero)
        }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            throw WallpsError.thumbnailFailed
        }
        try data.write(to: destination, options: .atomic)
    }
}
