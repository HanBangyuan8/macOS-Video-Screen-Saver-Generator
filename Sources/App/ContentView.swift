import SwiftUI

@available(macOS 15.0, *)
struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        NativeModernContentView()
            .environmentObject(model)
    }
}

@available(macOS 15.0, *)
struct NativeModernContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var workflow = SaverWorkflowModel()
    @State private var selectedSidebarPage: String = "create"
    @State private var navigationDirection: PageNavigationDirection = .downward

    private var versionedMotionProfile: VersionedMotionProfile {
        VersionedMotionProfile(runtimeProfile: model.runtimeProfile, intensity: model.motionIntensity)
    }

    private var interfaceAnimation: Animation? {
        reduceMotion || model.motionIntensity == .none ? nil : versionedMotionProfile.pageSwitchAnimation
    }

    private var pageTransition: AnyTransition {
        navigationDirection.transition(reduceMotion: reduceMotion, intensity: model.motionIntensity)
    }

    private var sidebarPageOrder: [String] {
        ["settings", "create"]
    }

    var body: some View {
        NavigationSplitView {
            List {
                Section(model.t("Language")) {
                    Picker("", selection: $model.languageCode) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                Section(model.t("Motion")) {
                    Picker("", selection: $model.motionIntensityID) {
                        ForEach(MotionIntensity.allCases) { intensity in
                            Text(intensity.title(for: model.language)).tag(intensity.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                Section(model.t("Accent Color")) {
                    AccentColorPicker(model: model)
                }

                Section(model.t("Settings")) {
                    Button {
                        selectPage("settings")
                    } label: {
                        HStack {
                            Label(model.t("Settings"), systemImage: "slider.horizontal.3")
                            Spacer()
                            if selectedSidebarPage == "settings" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(
                        VersionedPagePressButtonStyle(
                            isSelected: selectedSidebarPage == "settings",
                            accentColor: model.accentColor,
                            profile: versionedMotionProfile
                        )
                    )
                }

                Section(model.t("Workflow")) {
                    Button {
                        selectPage("create")
                    } label: {
                        HStack {
                            Label(model.t("Create"), systemImage: "play.rectangle")
                            Spacer()
                            if selectedSidebarPage == "create" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(
                        VersionedPagePressButtonStyle(
                            isSelected: selectedSidebarPage == "create",
                            accentColor: model.accentColor,
                            profile: versionedMotionProfile
                        )
                    )
                }

                Section(model.t("Status")) {
                    LabeledContent(model.t("Selected video")) {
                        Text(workflow.selectedVideo?.lastPathComponent ?? model.t("None"))
                    }
                    LabeledContent(model.t("Generator")) {
                        Text(workflow.isBusy ? model.t("Busy") : model.t("Ready"))
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Video Screen Saver Generator")
            .navigationSplitViewColumnWidth(min: 248, ideal: 272, max: 330)
        } detail: {
            GeometryReader { _ in
                if selectedSidebarPage == "settings" {
                    SettingsPage()
                        .environmentObject(model)
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .id(selectedSidebarPage)
                        .transition(pageTransition)
                        .versionedPageSwitchMotion(
                            profile: versionedMotionProfile,
                            pageID: selectedSidebarPage,
                            direction: navigationDirection
                        )
                        .coordinateSpace(name: "detailScroll")
                } else {
                    CreateSaverView(
                        workflow: workflow,
                        navigationDirection: navigationDirection
                    )
                    .environmentObject(model)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .id(selectedSidebarPage)
                    .transition(pageTransition)
                    .versionedPageSwitchMotion(
                        profile: versionedMotionProfile,
                        pageID: selectedSidebarPage,
                        direction: navigationDirection
                    )
                    .coordinateSpace(name: "detailScroll")
                }
            }
            .navigationTitle("Video Screen Saver Generator")
        }
        .frame(minWidth: 1100, minHeight: 760)
        .tint(model.accentColor)
        .environment(\.locale, model.locale)
        .animation(interfaceAnimation, value: selectedSidebarPage)
        .animation(interfaceAnimation, value: model.languageCode)
        .animation(interfaceAnimation, value: model.accentColorID)
        .animation(interfaceAnimation, value: model.motionIntensityID)
        .versionedStartupMotion(profile: versionedMotionProfile)
    }

    private func selectPage(_ page: String) {
        guard page != selectedSidebarPage else { return }
        let currentIndex = sidebarPageOrder.firstIndex(of: selectedSidebarPage) ?? 0
        let nextIndex = sidebarPageOrder.firstIndex(of: page) ?? currentIndex
        navigationDirection = nextIndex >= currentIndex ? .downward : .upward
        withAnimation(interfaceAnimation) {
            selectedSidebarPage = page
        }
    }
}
