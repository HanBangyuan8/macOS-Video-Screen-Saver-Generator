import AVFoundation
import AVKit
import Combine
import Foundation

final class PreviewPlayerController: ObservableObject {
    @Published private(set) var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    @MainActor
    func load(url: URL, muted: Bool) {
        cleanup()

        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = muted
        newPlayer.actionAtItemEnd = .pause

        if let item = newPlayer.currentItem {
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak newPlayer] _ in
                newPlayer?.seek(to: .zero)
                newPlayer?.play()
            }
        }

        player = newPlayer
        newPlayer.play()
    }

    @MainActor
    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }

    @MainActor
    func cleanup() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        player?.pause()
    }
}
