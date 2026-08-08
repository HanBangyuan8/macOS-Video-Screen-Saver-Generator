import AVKit
import SwiftUI

struct VideoPreviewView: View {
    let player: AVPlayer?
    let selectedVideo: URL?
    let isDropTargeted: Bool
    let accentColor: Color
    let language: AppLanguage
    let chooseVideo: () -> Void

    private func t(_ key: String) -> String {
        L10n.text(key, language: language)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black)

            if let player {
                VideoPlayer(player: player)
                    .allowsHitTesting(false)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(accentColor)
                    Text(t("Drop a video here"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(t("or choose an MP4, MOV, or M4V file"))
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.64))
                    Button(t("Choose Video…"), action: chooseVideo)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(24)
            }

            if selectedVideo != nil {
                VStack {
                    HStack {
                        Label(t("Preview"), systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.48), in: Capsule(style: .continuous))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(14)
                .foregroundStyle(.white)
                .allowsHitTesting(false)
            }
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .frame(maxWidth: .infinity, minHeight: 230)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? accentColor : Color.white.opacity(0.14),
                    lineWidth: isDropTargeted ? 2 : 1
                )
        }
        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
        .animation(.easeInOut(duration: 0.18), value: isDropTargeted)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(t("Video preview"))
        .accessibilityValue(selectedVideo?.lastPathComponent ?? t("No video selected"))
    }
}
