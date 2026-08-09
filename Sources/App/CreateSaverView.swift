import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct CreatePanelHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

@MainActor
final class SaverWorkflowModel: ObservableObject {
    let preview = PreviewPlayerController()

    @Published private(set) var selectedVideo: URL?
    @Published var saverName = "My Video Screen Saver"
    @Published var contentMode: SaverContentMode = .fill
    @Published var muted = true
    @Published private(set) var metadata: VideoMetadata?
    @Published private(set) var isBusy = false
    @Published private(set) var statusMessage = "Choose a video to begin."
    @Published private(set) var resultURL: URL?
    @Published private(set) var errorMessage: String?
    @Published private(set) var technicalDetails: String?

    init() {
        let defaults = UserDefaults.standard
        contentMode = SaverContentMode(
            rawValue: defaults.string(forKey: "defaultContentMode") ?? SaverContentMode.fill.rawValue
        ) ?? .fill
        muted = defaults.object(forKey: "defaultMuted") as? Bool ?? true
    }

    func selectVideo(_ url: URL) {
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
            fail(summary: "The selected video could not be read.", details: "The URL does not point to an existing local file.")
            return
        }

        selectedVideo = url
        saverName = url.deletingPathExtension().lastPathComponent
        metadata = nil
        resultURL = nil
        errorMessage = nil
        technicalDetails = nil
        statusMessage = "Preparing preview…"
        preview.load(url: url, muted: muted)

        VideoMetadata.load(for: url) { [weak self] metadata in
            guard let self, self.selectedVideo == url else { return }
            self.metadata = metadata
            self.statusMessage = metadata == nil ? "Preview ready. Metadata is unavailable." : "Ready to export."
        }
    }

    func setMuted(_ value: Bool) {
        muted = value
        preview.setMuted(value)
    }

    func startExport(to destination: URL) {
        guard let videoURL = selectedVideo, !isBusy else { return }

        let displayName = saverName
        let mode = contentMode
        let shouldMute = muted
        isBusy = true
        resultURL = nil
        errorMessage = nil
        technicalDetails = nil
        statusMessage = "Generating screen saver…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome: Result<URL, Error>
            do {
                let exported = try Exporter.export(
                    videoURL: videoURL,
                    destinationURL: destination,
                    displayName: displayName,
                    contentMode: mode,
                    muted: shouldMute
                )
                outcome = .success(exported)
            } catch {
                outcome = .failure(error)
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                switch outcome {
                case .success(let url):
                    self.resultURL = url
                    self.statusMessage = "Screen saver generated successfully."
                case .failure(let error):
                    self.fail(summary: Self.summary(for: error), details: Self.details(for: error))
                }
            }
        }
    }

    func cleanup() {
        preview.cleanup()
    }

    func presentExternalError(_ error: Error) {
        fail(summary: Self.summary(for: error), details: Self.details(for: error))
    }

    private func fail(summary: String, details: String) {
        isBusy = false
        errorMessage = summary
        technicalDetails = details
        statusMessage = "The operation failed."
    }

    private static func summary(for error: Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
            return localized.components(separatedBy: "\n").first ?? localized
        }
        return error.localizedDescription
    }

    private static func details(for error: Error) -> String {
        if let exportError = error as? Exporter.ExportError,
           let details = exportError.technicalDetails {
            return details
        }
        return error.localizedDescription
    }
}

struct CreateSaverView: View {
    @ObservedObject var workflow: SaverWorkflowModel
    let navigationDirection: PageNavigationDirection

    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDropTargeted = false
    @State private var panelHeight: CGFloat?

    private var accentColor: Color { model.accentColor }
    private var language: AppLanguage { model.language }
    private var motionIntensity: MotionIntensity { model.motionIntensity }

    private var motionProfile: VersionedMotionProfile {
        VersionedMotionProfile(runtimeProfile: model.runtimeProfile, intensity: motionIntensity)
    }

    private func t(_ key: String) -> String {
        model.t(key)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: t("Create"),
                    subtitle: t("Turn a local video into a native macOS screen saver."),
                    systemImage: "play.rectangle.fill",
                    accentColor: accentColor
                )
                .versionedComponentAppear(profile: motionProfile, pageID: "create-header", direction: navigationDirection)

                HStack(alignment: .top, spacing: 18) {
                    equalHeightPanel(previewPanel)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .interactivePanel(accentColor: accentColor)
                    equalHeightPanel(settingsPanel)
                        .frame(width: 330)
                        .interactivePanel(accentColor: accentColor)
                }
                .versionedComponentAppear(profile: motionProfile, pageID: "create-panels", direction: navigationDirection)
                .onPreferenceChange(CreatePanelHeightPreferenceKey.self) { height in
                    guard height > 0, panelHeight != height else { return }
                    panelHeight = height
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.72))
        .tint(accentColor)
        .animation(makeInterfaceAnimation(reduceMotion: reduceMotion, intensity: motionIntensity), value: workflow.selectedVideo)
        .onChange(of: workflow.muted) { value in
            workflow.setMuted(value)
        }
        .onDisappear {
            workflow.cleanup()
        }
    }

    private func equalHeightPanel<Content: View>(_ content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: CreatePanelHeightPreferenceKey.self, value: proxy.size.height)
                }
            }
            .frame(height: panelHeight, alignment: .top)
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Video preview"))
                        .font(.headline)
                    Text(t("Drop a file anywhere on the preview surface."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(workflow.selectedVideo == nil ? t("Choose Video…") : t("Replace…"), action: chooseVideo)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(workflow.isBusy)
                    .controlButtonHover(accentColor: accentColor)
            }

            VideoPreviewView(
                player: workflow.preview.player,
                selectedVideo: workflow.selectedVideo,
                isDropTargeted: isDropTargeted,
                accentColor: accentColor,
                language: language,
                chooseVideo: chooseVideo
            )
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                workflow.selectVideo(url)
                return true
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }

            if let selectedVideo = workflow.selectedVideo {
                HStack(spacing: 9) {
                    Image(systemName: "film")
                        .foregroundStyle(accentColor)
                    Text(selectedVideo.lastPathComponent)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer(minLength: 4)
                }
                .font(.callout)
            } else {
                Text(t("No video selected"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let metadata = workflow.metadata {
                metadataGrid(metadata)
            }
        }
        .padding(18)
    }

    private func metadataGrid(_ metadata: VideoMetadata) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
            metadataItem(t("Container"), value: metadata.container, systemImage: "doc")
            metadataItem(t("Duration"), value: metadata.duration, systemImage: "clock")
            metadataItem(t("Dimensions"), value: metadata.dimensions, systemImage: "rectangle")
            metadataItem(t("File size"), value: metadata.fileSize, systemImage: "internaldrive")
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metadataItem(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .foregroundStyle(accentColor)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.monospacedDigit())
                    .lineLimit(1)
            }
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(t("Screen saver settings"), systemImage: "slider.horizontal.3")
                .font(.headline)

            VStack(alignment: .leading, spacing: 7) {
                Text(t("Display name"))
                    .font(.subheadline.weight(.medium))
                TextField("My Video Screen Saver", text: $workflow.saverName)
                    .textFieldStyle(.roundedBorder)
                    .disabled(workflow.isBusy)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(t("Content mode"))
                    .font(.subheadline.weight(.medium))
                Picker(t("Content mode"), selection: $workflow.contentMode) {
                    ForEach(SaverContentMode.allCases) { mode in
                        Text(mode.localizedTitle(for: language)).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .disabled(workflow.isBusy)
                Text(workflow.contentMode.localizedExplanation(for: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(t("Mute screen saver audio"), isOn: $workflow.muted)
                .disabled(workflow.isBusy)

            Divider()

            Button(action: exportSaver) {
                Label(t("Export .saver…"), systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(workflow.selectedVideo == nil || workflow.isBusy)

            Button(action: installSaver) {
                Label(t("Generate and Install"), systemImage: "arrow.down.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(workflow.selectedVideo == nil || workflow.isBusy)

            if workflow.isBusy {
                HStack(spacing: 9) {
                    ProgressView()
                        .controlSize(.small)
                    Text(t("Copying video and signing…"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else {
                Text(localizedStatusMessage)
                    .font(.caption)
                    .foregroundStyle(workflow.errorMessage == nil ? Color.secondary : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let resultURL = workflow.resultURL {
                successCard(resultURL)
            }

            if let errorMessage = workflow.errorMessage {
                errorCard(summary: errorMessage, details: workflow.technicalDetails)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
    }

    private func successCard(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(t("Ready"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline.weight(.semibold))
            Text(url.path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(3)
            HStack(spacing: 8) {
                Button(t("Reveal in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button(t("Copy Path")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.path, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.green.opacity(0.28), lineWidth: 1)
        }
    }

    private func errorCard(summary: String, details: String?) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(summary, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let details, !details.isEmpty {
                DisclosureGroup(t("Technical details")) {
                    ScrollView {
                        Text(details)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                }
                .font(.caption)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.28), lineWidth: 1)
        }
    }

    private func chooseVideo() {
        let panel = NSOpenPanel()
        panel.title = t("Choose a screen saver video")
        panel.prompt = t("Choose")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        workflow.selectVideo(url)
    }

    private func exportSaver() {
        let panel = NSSavePanel()
        panel.title = t("Export Screen Saver")
        panel.prompt = t("Export")
        panel.nameFieldStringValue = Exporter.safeFileName(workflow.saverName) + ".saver"
        panel.allowedContentTypes = [UTType(filenameExtension: "saver") ?? .bundle]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let destination = panel.url else { return }
        workflow.startExport(to: destination)
    }

    private var localizedStatusMessage: String {
        t(workflow.statusMessage)
    }

    private func installSaver() {
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent(
                Exporter.safeFileName(workflow.saverName) + ".saver",
                isDirectory: true
            )
            workflow.startExport(to: destination)
        } catch {
            // This is a local folder creation failure, so keep the same diagnostic
            // surface as exporter failures without opening a modal alert.
            workflow.presentExternalError(error)
        }
    }
}
