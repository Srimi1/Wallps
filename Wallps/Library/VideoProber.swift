import AVFoundation
import Foundation
import VideoToolbox

struct VideoProbe: Sendable {
    var duration: TimeInterval
    var pixelWidth: Int
    var pixelHeight: Int
    var nominalFrameRate: Float
    /// Four-character codec code, e.g. `hvc1` or `avc1`.
    var codec: String?
    /// False when this Mac has no fixed-function decoder for the codec, so
    /// playback would fall back to software decoding and burn CPU.
    var hardwareDecodable: Bool
}

/// Loads metadata for a video file and rejects anything unplayable.
enum VideoProber {
    /// Shorter than this and a looping wallpaper just stutters.
    static let minimumDuration: TimeInterval = 0.5

    static func probe(url: URL) async throws -> VideoProbe {
        let asset = AVURLAsset(url: url)
        let isPlayable: Bool
        let duration: CMTime
        let tracks: [AVAssetTrack]
        do {
            (isPlayable, duration, tracks) = try await asset.load(.isPlayable, .duration, .tracks)
        } catch {
            throw WallpsError.notAVideo(url)
        }
        guard isPlayable else { throw WallpsError.notAVideo(url) }
        guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
            throw WallpsError.noVideoTrack(url)
        }
        guard duration.seconds.isFinite, duration.seconds >= minimumDuration else {
            throw WallpsError.tooShort(url)
        }

        let (size, transform, frameRate, formats) = try await videoTrack.load(
            .naturalSize, .preferredTransform, .nominalFrameRate, .formatDescriptions
        )
        // Apply the track transform so rotated portrait video reports the size
        // it will actually display at.
        let rect = CGRect(origin: .zero, size: size).applying(transform)

        var codec: String?
        var hardwareDecodable = true
        if let format = formats.first {
            let subtype = CMFormatDescriptionGetMediaSubType(format)
            codec = fourCCString(subtype)
            hardwareDecodable = VTIsHardwareDecodeSupported(subtype)
        }

        return VideoProbe(
            duration: duration.seconds,
            pixelWidth: Int(abs(rect.width).rounded()),
            pixelHeight: Int(abs(rect.height).rounded()),
            nominalFrameRate: frameRate,
            codec: codec,
            hardwareDecodable: hardwareDecodable
        )
    }

    private static func fourCCString(_ value: FourCharCode) -> String {
        let bytes = [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
        ]
        return String(decoding: bytes, as: UTF8.self)
    }
}
