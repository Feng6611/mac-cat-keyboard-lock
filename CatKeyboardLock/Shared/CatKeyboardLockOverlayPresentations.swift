import Foundation
import KikiOverlay

enum CatKeyboardLockOverlayPresentations {
    @MainActor
    static func style(for settings: LockSettings) -> KikiScreenEdgeOverlayStyle {
        .screenEdge(glowIntensity: settings.overlayGlowIntensity)
    }

    static func lockStarted() -> KikiScreenEdgeOverlayPresentation {
        .lockStarted(
            title: "Keyboard locked",
            subtitle: "Hold ⌃⌥⌘L to unlock"
        )
    }

    static func lockEnded(reason: InputLockUnlockReason?) -> KikiScreenEdgeOverlayPresentation {
        .lockEnded(
            title: unlockTitle(for: reason),
            subtitle: "Your keyboard is active.",
            tint: KikiScreenEdgeOverlayPalette.success,
            companionTint: KikiScreenEdgeOverlayPalette.deepSuccess
        )
    }

    static func warning(reason: String) -> KikiScreenEdgeOverlayPresentation {
        .warning(
            title: "Lock stopped",
            subtitle: reason
        )
    }

    static func settingsPreview() -> KikiScreenEdgeOverlayPresentation {
        return KikiScreenEdgeOverlayPresentation(
            title: "Visual feedback",
            subtitle: "Preview",
            systemImage: "sparkles",
            tint: KikiScreenEdgeOverlayPalette.orange,
            companionTint: KikiScreenEdgeOverlayPalette.deepOrange,
            behavior: .momentary(duration: edgeDuration + 0.45),
            motion: .breathingWithEntryBurst,
            toastDuration: 1.4,
            edgeDuration: edgeDuration
        )
    }

    private static let edgeDuration: TimeInterval = 4.4

    static func unlockTitle(for reason: InputLockUnlockReason?) -> String {
        switch reason {
        case .fallbackShortcut:
            return "Unlocked with shortcut"
        case .triggerCorner:
            return "Unlocked from corner"
        case .timeout:
            return "Lock duration ended"
        case .manual, .none:
            return "Keyboard unlocked"
        case .tapDisabled:
            return "Keyboard restored"
        case .appTerminated:
            return "Keyboard unlocked"
        }
    }
}
