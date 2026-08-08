import SwiftUI

enum SaverContentMode: String, CaseIterable, Identifiable, Sendable {
    case fill
    case fit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fill: "Fill"
        case .fit: "Fit"
        }
    }

    var explanation: String {
        switch self {
        case .fill: "Fills the display and crops the edges when needed."
        case .fit: "Shows the complete frame with possible letterboxing."
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("interfaceMotion") private var motionIntensityID = MotionIntensity.enhanced.rawValue
    @AppStorage("interfaceAccent") private var accentColorID = "purple"

    private var accentColor: Color {
        AccentColorOption.option(for: accentColorID).color
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: "Settings",
                    subtitle: "Tune the appearance of Video Screen Saver Generator.",
                    systemImage: "slider.horizontal.3",
                    accentColor: accentColor
                )

                appearancePanel
                    .softAppear()

                behaviorPanel
                    .softAppear(delay: 0.04)

                diagnosticsPanel
                    .softAppear(delay: 0.08)
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Appearance", systemImage: "paintbrush.pointed")
                .font(.headline)

            SettingsRow("Accent Color") {
                VStack(alignment: .leading, spacing: 8) {
                    AccentColorPicker(selection: $accentColorID)
                    Text("The accent is used for actions, selection, and preview states.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            SettingsRow("Motion") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Motion", selection: $motionIntensityID) {
                        ForEach(MotionIntensity.allCases) { intensity in
                            Text(intensity.title).tag(intensity.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    Text("Reduce Motion in System Settings always takes priority.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .interactivePanel(accentColor: accentColor)
    }

    private var behaviorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Export behavior", systemImage: "shippingbox")
                .font(.headline)
            Text("Generated screen savers contain a copy of the selected video. The original file is never moved, transcoded, or modified.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield")
                    .foregroundStyle(accentColor)
                Text("Universal 2 app and screen saver")
                Spacer()
            }
            .font(.callout)
            HStack(spacing: 10) {
                Image(systemName: "lock.open")
                    .foregroundStyle(accentColor)
                Text("Generated bundles use local ad-hoc signing")
                Spacer()
            }
            .font(.callout)
        }
        .padding(18)
        .interactivePanel(accentColor: accentColor)
    }

    private var diagnosticsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("About", systemImage: "info.circle")
                .font(.headline)
            Text("Video Screen Saver Generator")
                .font(.title3.weight(.semibold))
            Text("A native macOS utility for turning local video into an installable legacy ScreenSaver bundle.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("If an export fails, expand the technical details on the Create page to copy the complete signing diagnostics.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .interactivePanel(accentColor: accentColor)
    }
}
