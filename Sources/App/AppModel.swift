import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var languageCode: String {
        didSet { UserDefaults.standard.set(languageCode, forKey: "languageCode") }
    }

    @Published var accentColorID: String {
        didSet { UserDefaults.standard.set(accentColorID, forKey: "accentColorID") }
    }

    @Published var motionIntensityID: String {
        didSet { UserDefaults.standard.set(motionIntensityID, forKey: "motionIntensityID") }
    }

    @Published var defaultContentModeID: String {
        didSet { UserDefaults.standard.set(defaultContentModeID, forKey: "defaultContentMode") }
    }

    @Published var defaultMuted: Bool {
        didSet { UserDefaults.standard.set(defaultMuted, forKey: "defaultMuted") }
    }

    var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .simplifiedChinese
    }

    var accentColor: Color {
        AccentColorOption.option(for: accentColorID).color
    }

    var motionIntensity: MotionIntensity {
        MotionIntensity(rawValue: motionIntensityID) ?? .enhanced
    }

    var locale: Locale {
        Locale(identifier: language.localeIdentifier)
    }

    var runtimeProfile: RuntimeOptimizationProfile {
        .current
    }

    func t(_ key: String) -> String {
        L10n.text(key, language: language)
    }

    init() {
        let defaults = UserDefaults.standard
        languageCode = defaults.string(forKey: "languageCode") ?? AppLanguage.simplifiedChinese.rawValue
        accentColorID = defaults.string(forKey: "accentColorID") ?? "purple"
        motionIntensityID = defaults.string(forKey: "motionIntensityID") ?? MotionIntensity.enhanced.rawValue
        defaultContentModeID = defaults.string(forKey: "defaultContentMode") ?? SaverContentMode.fill.rawValue
        defaultMuted = defaults.object(forKey: "defaultMuted") as? Bool ?? true
    }
}
