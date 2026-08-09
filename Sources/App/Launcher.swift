import AppKit
import SwiftUI

@main
enum VideoScreenSaverGeneratorLauncher {
    static func main() {
        NativeVideoScreenSaverGeneratorApp.main()
    }
}

@available(macOS 15.0, *)
struct NativeVideoScreenSaverGeneratorApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            NativeModernContentView()
                .environmentObject(model)
        }

        Settings {
            NativeModernContentView()
                .environmentObject(model)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Preferences...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
