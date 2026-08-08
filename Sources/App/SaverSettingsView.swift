import SwiftUI

enum SaverContentMode: String, CaseIterable, Identifiable, Sendable {
    case fill
    case fit

    var id: String { rawValue }

    func localizedTitle(for language: AppLanguage) -> String {
        L10n.text(rawValue == "fill" ? "Fill" : "Fit", language: language)
    }

    func localizedExplanation(for language: AppLanguage) -> String {
        switch self {
        case .fill:
            L10n.text("Fills the display and crops the edges when needed.", language: language)
        case .fit:
            L10n.text("Shows the complete frame with possible letterboxing.", language: language)
        }
    }
}

struct SettingsPage: View {
    @Binding var languageCode: String
    @Binding var accentColorID: String
    @Binding var motionIntensityID: String

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .simplifiedChinese
    }

    private var accentColor: Color {
        AccentColorOption.option(for: accentColorID).color
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("Settings", language: language))
                    .font(.title2.bold())
                    .versionedComponentAppear(
                        profile: motionProfile,
                        pageID: "settings",
                        direction: .unchanged
                    )

                settingsRows
                    .versionedComponentAppear(
                        profile: motionProfile,
                        pageID: "settings",
                        direction: .unchanged
                    )
            }
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.automatic)
        .tint(accentColor)
    }

    private var motionProfile: VersionedMotionProfile {
        VersionedMotionProfile(
            runtimeProfile: .current,
            intensity: MotionIntensity(rawValue: motionIntensityID) ?? .enhanced
        )
    }

    private var settingsRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsSection(L10n.text("General", language: language), index: 0) {
                languageRow
                motionRow
                accentRow
            }

            settingsSection(L10n.text("Screen Saver", language: language), index: 1) {
                defaultsRow
                muteRow
            }

            settingsSection(L10n.text("Export", language: language), index: 2) {
                exportSafetyRow
                bundleRow
            }

            settingsSection(L10n.text("Diagnostics", language: language), index: 3) {
                diagnosticsRow
            }
        }
    }

    private func settingsSection<Content: View>(_ title: String, index: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .settingsSolidCard(accentColor: accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .staggeredGroupAppear(index: index)
    }

    private var languageRow: some View {
        SettingsRow(L10n.text("Language", language: language)) {
            Picker("", selection: Binding(
                get: { languageCode },
                set: { languageCode = $0 }
            )) {
                ForEach(AppLanguage.allCases) { value in
                    Text(value.title).tag(value.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var motionRow: some View {
        SettingsRow(L10n.text("Motion", language: language)) {
            Picker("", selection: $motionIntensityID) {
                ForEach(MotionIntensity.allCases) { intensity in
                    Text(intensity.title(for: language)).tag(intensity.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var accentRow: some View {
        SettingsRow(L10n.text("Accent Color", language: language)) {
            VStack(alignment: .leading, spacing: 6) {
                AccentColorPicker(selection: $accentColorID, language: language)
                Text(L10n.text("The accent is used for actions, selection, and preview states.", language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var defaultsRow: some View {
        SettingsRow(L10n.text("Default content mode", language: language)) {
            @AppStorage("defaultContentMode") var defaultContentModeID = SaverContentMode.fill.rawValue
            Picker("", selection: $defaultContentModeID) {
                ForEach(SaverContentMode.allCases) { mode in
                    Text(mode.localizedTitle(for: language)).tag(mode.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var muteRow: some View {
        SettingsRow(L10n.text("Default mute", language: language)) {
            @AppStorage("defaultMuted") var defaultMuted = true
            Toggle(L10n.text("Mute screen saver audio", language: language), isOn: $defaultMuted)
                .toggleStyle(.switch)
        }
    }

    private var exportSafetyRow: some View {
        SettingsRow(L10n.text("Source file safety", language: language)) {
            Label(
                L10n.text("The original video is read-only during export.", language: language),
                systemImage: "checkmark.shield"
            )
            .foregroundStyle(.secondary)
        }
    }

    private var bundleRow: some View {
        SettingsRow(L10n.text("Bundle", language: language)) {
            VStack(alignment: .leading, spacing: 5) {
                Label(L10n.text("Universal 2 app and screen saver", language: language), systemImage: "cpu")
                Label(L10n.text("Generated bundles use local ad-hoc signing", language: language), systemImage: "signature")
            }
            .foregroundStyle(.secondary)
        }
    }

    private var diagnosticsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SidebarStatusRow(title: L10n.text("Application version", language: language)) {
                Text("1.0.2").monospacedDigit()
            }
            SidebarStatusRow(title: L10n.text("Universal 2", language: language)) {
                Text("arm64 + x86_64")
            }
            SidebarStatusRow(title: L10n.text("Local ad-hoc signature", language: language)) {
                Text(L10n.text("Enabled", language: language))
            }
            Text(L10n.text("Settings apply immediately to the native shell.", language: language))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
