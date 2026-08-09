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
    @EnvironmentObject private var model: AppModel

    private var versionedMotionProfile: VersionedMotionProfile {
        VersionedMotionProfile(runtimeProfile: model.runtimeProfile, intensity: model.motionIntensity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t("Settings"))
                .font(.title2.bold())
                .versionedComponentAppear(profile: versionedMotionProfile, pageID: "settings", direction: .unchanged)

            SettingsPanel(model: model)
                .versionedComponentAppear(profile: versionedMotionProfile, pageID: "settings", direction: .unchanged)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SettingsPanel: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var settingsAnimation: Animation? {
        reduceMotion ? nil : MotionTokens.soft
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsSection(title: model.t("General"), index: 0) {
                languageRow
                motionRow
                accentRow
            }

            settingsSection(title: model.t("Screen Saver"), index: 1) {
                defaultsRow
                muteRow
            }

            settingsSection(title: model.t("Export"), index: 2) {
                exportSafetyRow
                bundleRow
            }

            settingsSection(title: model.t("Diagnostics"), index: 3) {
                diagnosticsRow
            }
        }
        .animation(settingsAnimation, value: model.languageCode)
        .animation(settingsAnimation, value: model.accentColorID)
        .animation(settingsAnimation, value: model.motionIntensityID)
        .animation(settingsAnimation, value: model.defaultContentModeID)
        .animation(settingsAnimation, value: model.defaultMuted)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func settingsSection<Content: View>(title: String, index: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .settingsSolidCard(accentColor: model.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .staggeredGroupAppear(index: index)
    }

    private var languageRow: some View {
        SettingsRow(title: model.t("Language")) {
            Picker("", selection: $model.languageCode) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var motionRow: some View {
        SettingsRow(title: model.t("Motion")) {
            Picker("", selection: $model.motionIntensityID) {
                ForEach(MotionIntensity.allCases) { intensity in
                    Text(intensity.title(for: model.language)).tag(intensity.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var accentRow: some View {
        SettingsRow(title: model.t("Accent Color")) {
            VStack(alignment: .leading, spacing: 6) {
                AccentColorPicker(model: model)
                Text(model.t("The accent is used for actions, selection, and preview states."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var defaultsRow: some View {
        SettingsRow(title: model.t("Default content mode")) {
            Picker("", selection: $model.defaultContentModeID) {
                ForEach(SaverContentMode.allCases) { mode in
                    Text(mode.localizedTitle(for: model.language)).tag(mode.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var muteRow: some View {
        SettingsRow(title: model.t("Default mute")) {
            Toggle(model.t("Mute screen saver audio"), isOn: $model.defaultMuted)
                .toggleStyle(.switch)
        }
    }

    private var exportSafetyRow: some View {
        SettingsRow(title: model.t("Source file safety")) {
            Label(
                model.t("The original video is read-only during export."),
                systemImage: "checkmark.shield"
            )
            .foregroundStyle(.secondary)
        }
    }

    private var bundleRow: some View {
        SettingsRow(title: model.t("Bundle")) {
            VStack(alignment: .leading, spacing: 5) {
                Label(model.t("Universal 2 app and screen saver"), systemImage: "cpu")
                Label(model.t("Generated bundles use local ad-hoc signing"), systemImage: "signature")
            }
            .foregroundStyle(.secondary)
        }
    }

    private var diagnosticsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SidebarStatusRow(title: model.t("Application version")) {
                Text("1.0.4").monospacedDigit()
            }
            SidebarStatusRow(title: model.t("Universal 2")) {
                Text("arm64 + x86_64")
            }
            SidebarStatusRow(title: model.t("Local ad-hoc signature")) {
                Text(model.t("Enabled"))
            }
            Text(model.t("Settings apply immediately to the native shell."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
