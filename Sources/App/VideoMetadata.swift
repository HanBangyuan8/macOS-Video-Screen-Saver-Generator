import AVFoundation
import Foundation

struct VideoMetadata: Sendable {
    let fileName: String
    let container: String
    let duration: String
    let dimensions: String
    let fileSize: String

    static func load(for url: URL, completion: @escaping (VideoMetadata?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let byteCount = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            let asset = AVURLAsset(url: url)

            Task {
                let durationSeconds: Double
                let tracks: [AVAssetTrack]
                do {
                    durationSeconds = try await asset.load(.duration).seconds
                    tracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
                } catch {
                    durationSeconds = 0
                    tracks = []
                }

                let duration = durationSeconds.isFinite && durationSeconds > 0
                    ? Self.formatDuration(durationSeconds)
                    : "Unavailable"

                var dimensions = "Unavailable"
                if let track = tracks.first,
                   let naturalSize = try? await track.load(.naturalSize),
                   let preferredTransform = try? await track.load(.preferredTransform) {
                    let size = naturalSize.applying(preferredTransform)
                    let width = Int(abs(size.width).rounded())
                    let height = Int(abs(size.height).rounded())
                    if width > 0, height > 0 {
                        dimensions = "\(width) × \(height)"
                    }
                }

                let result = VideoMetadata(
                    fileName: url.lastPathComponent,
                    container: url.pathExtension.isEmpty ? "MOV" : url.pathExtension.uppercased(),
                    duration: duration,
                    dimensions: dimensions,
                    fileSize: ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
                )

                await MainActor.run {
                    completion(result)
                }
            }
        }
    }

    private static func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
