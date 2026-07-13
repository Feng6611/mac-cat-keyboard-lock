import AppKit
import SwiftUI

@main
struct CatKeyboardLockApp: App {
    @NSApplicationDelegateAdaptor(CatKeyboardLockAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            let composition = appDelegate.composition
            CatKeyboardLockSettingsView(
                config: composition.definition.config,
                lockSettings: composition.lockSettings,
                inputLockController: composition.inputLockController,
                accessManager: composition.accessManager,
                settingsCoordinator: composition.settingsCoordinator,
                route: composition.settingsRoute,
                onTriggerOnboarding: composition.router.triggerOnboarding
            )
        }
    }
}

@MainActor
final class CatKeyboardLockAppDelegate: NSObject, NSApplicationDelegate {
    let composition = CatKeyboardLockAppComposition()

    func applicationDidFinishLaunching(_ notification: Notification) {
        composition.lifecycle.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        composition.lifecycle.stop()
    }
}

enum CatKeyboardLockLaunchScene: Equatable {
    case onboarding
    case settings
    case paywall
}

struct CatKeyboardLockLaunchOptions: Equatable {
    let scene: CatKeyboardLockLaunchScene?
    let settingsTab: CatKeyboardLockInitialSettingsTab?

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> Self {
        var scene: CatKeyboardLockLaunchScene?
        var settingsTab: CatKeyboardLockInitialSettingsTab?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case "--ui-smoke-onboarding":
                scene = .onboarding
            case "--ui-smoke-paywall":
                scene = .paywall
            case "--ui-smoke-settings":
                scene = .settings
                if index + 1 < arguments.count,
                   let tab = CatKeyboardLockInitialSettingsTab(rawValue: arguments[index + 1]) {
                    settingsTab = tab
                    index += 1
                }
            default:
                if argument.hasPrefix("--ui-smoke-settings=") {
                    scene = .settings
                    let rawTab = String(argument.dropFirst("--ui-smoke-settings=".count))
                    settingsTab = CatKeyboardLockInitialSettingsTab(rawValue: rawTab)
                }
            }

            index += 1
        }

        return Self(scene: scene, settingsTab: settingsTab)
    }
}
