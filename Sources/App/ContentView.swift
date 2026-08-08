import SwiftUI

private enum AppPage: String, CaseIterable, Hashable {
    case create
    case settings
}

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("languageCode") private var languageCode = AppLanguage.simplifiedChinese.rawValue
    @AppStorage("accentColorID") private var accentColorID = "purple"
    @AppStorage("motionIntensityID") private var motionIntensityID = MotionIntensity.enhanced.rawValue
    @StateObject private var workflow = SaverWorkflowModel()
    @State private var selectedPage: AppPage = .create
    @State private var navigationDirection: PageNavigationDirection = .downward

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .simplifiedChinese
    }

    private var motionIntensity: MotionIntensity {
        MotionIntensity(rawValue: motionIntensityID) ?? .enhanced
    }

    private var accentColor: Color {
        AccentColorOption.option(for: accentColorID).color
    }

    private var runtimeProfile: VersionedMotionProfile {
        VersionedMotionProfile(runtimeProfile: .current, intensity: motionIntensity)
    }

    private var interfaceAnimation: Animation? {
        guard !reduceMotion, motionIntensity != .none else { return nil }
        return runtimeProfile.pageSwitchAnimation
    }

    private var pageTransition: AnyTransition {
        navigationDirection.transition(reduceMotion: reduceMotion, intensity: motionIntensity)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 248, ideal: 272, max: 330)
        } detail: {
            GeometryReader { geometry in
                detailPage
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .id(selectedPage)
                    .transition(pageTransition)
                    .versionedPageSwitchMotion(
                        profile: runtimeProfile,
                        pageID: selectedPage.rawValue,
                        direction: navigationDirection
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
            .navigationTitle(L10n.text(selectedPage == .create ? "Create" : "Settings", language: language))
            .coordinateSpace(name: "detailScroll")
        }
        .frame(minWidth: 1100, minHeight: 760)
        .tint(accentColor)
        .environment(\.locale, Locale(identifier: language.localeIdentifier))
        .animation(interfaceAnimation, value: selectedPage)
        .animation(interfaceAnimation, value: languageCode)
        .animation(interfaceAnimation, value: accentColorID)
        .animation(interfaceAnimation, value: motionIntensityID)
        .versionedStartupMotion(profile: runtimeProfile)
    }

    private var sidebar: some View {
        List {
            Section(L10n.text("Language", language: language)) {
                Picker("", selection: $languageCode) {
                    ForEach(AppLanguage.allCases) { value in
                        Text(value.title).tag(value.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Section(L10n.text("Motion", language: language)) {
                Picker("", selection: $motionIntensityID) {
                    ForEach(MotionIntensity.allCases) { intensity in
                        Text(intensity.title(for: language)).tag(intensity.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Section(L10n.text("Accent Color", language: language)) {
                AccentColorPicker(selection: $accentColorID, language: language)
            }

            Section(L10n.text("Workflow", language: language)) {
                pageButton(.create, title: L10n.text("Create", language: language), systemImage: "play.rectangle")
            }

            Section(L10n.text("Application", language: language)) {
                pageButton(.settings, title: L10n.text("Settings", language: language), systemImage: "slider.horizontal.3")
            }

            Section(L10n.text("Status", language: language)) {
                SidebarStatusRow(title: L10n.text("Selected video", language: language)) {
                    Text(workflow.selectedVideo?.lastPathComponent ?? L10n.text("None", language: language))
                }
                SidebarStatusRow(title: L10n.text("Generator", language: language)) {
                    Text(workflow.isBusy ? L10n.text("Busy", language: language) : L10n.text("Ready", language: language))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(L10n.text("Video Screen Saver Generator", language: language))
    }

    private func pageButton(_ page: AppPage, title: String, systemImage: String) -> some View {
        Button {
            selectPage(page)
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if selectedPage == page {
                    Image(systemName: "checkmark")
                        .foregroundStyle(accentColor)
                }
            }
        }
        .buttonStyle(
            VersionedPagePressButtonStyle(
                isSelected: selectedPage == page,
                accentColor: accentColor,
                profile: runtimeProfile
            )
        )
    }

    @ViewBuilder
    private var detailPage: some View {
        switch selectedPage {
        case .create:
            CreateSaverView(
                workflow: workflow,
                accentColor: accentColor,
                motionIntensity: motionIntensity,
                language: language,
                navigationDirection: navigationDirection
            )
        case .settings:
            SettingsPage(
                languageCode: $languageCode,
                accentColorID: $accentColorID,
                motionIntensityID: $motionIntensityID
            )
        }
    }

    private func selectPage(_ page: AppPage) {
        guard page != selectedPage else { return }
        let order = AppPage.allCases
        let currentIndex = order.firstIndex(of: selectedPage) ?? 0
        let nextIndex = order.firstIndex(of: page) ?? currentIndex
        navigationDirection = nextIndex >= currentIndex ? .downward : .upward
        withAnimation(interfaceAnimation) {
            selectedPage = page
        }
    }
}
