import SwiftUI

private enum AppPage: Hashable {
    case create
    case settings
}

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("interfaceMotion") private var motionIntensityID = MotionIntensity.enhanced.rawValue
    @AppStorage("interfaceAccent") private var accentColorID = "purple"
    @StateObject private var workflow = SaverWorkflowModel()
    @State private var selectedPage: AppPage = .create

    private var motionIntensity: MotionIntensity {
        MotionIntensity(rawValue: motionIntensityID) ?? .enhanced
    }

    private var accentColor: Color {
        AccentColorOption.option(for: accentColorID).color
    }

    private var interfaceAnimation: Animation? {
        makeInterfaceAnimation(reduceMotion: reduceMotion, intensity: motionIntensity)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 214, ideal: 238, max: 290)
        } detail: {
            detail
        }
        .frame(minWidth: 980, minHeight: 700)
        .tint(accentColor)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(interfaceAnimation, value: selectedPage)
        .animation(interfaceAnimation, value: accentColorID)
        .animation(interfaceAnimation, value: motionIntensityID)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 34, height: 34)
                    .background(accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Video Screen Saver")
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Text("Generator")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            List(selection: $selectedPage) {
                Section("Motion") {
                    Picker("Motion", selection: $motionIntensityID) {
                        ForEach(MotionIntensity.allCases) { intensity in
                            Text(intensity.title).tag(intensity.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                Section("Accent Color") {
                    AccentColorPicker(selection: $accentColorID)
                }

                Section("Workflow") {
                    Label("Create", systemImage: "play.rectangle")
                        .tag(AppPage.create)

                }

                Section("Application") {
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .tag(AppPage.settings)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedPage {
        case .create:
            CreateSaverView(workflow: workflow, accentColor: accentColor, motionIntensity: motionIntensity)
                .id(AppPage.create)
        case .settings:
            AppearanceSettingsView()
                .id(AppPage.settings)
        }
    }
}
