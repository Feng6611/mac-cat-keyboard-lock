import Foundation
import KikiOverlay
import SwiftUI

enum CatKeyboardLockOverlayPresentations {
    @MainActor
    static func style(for settings: LockSettings) -> KikiScreenEdgeOverlayStyle {
        .screenEdge(glowIntensity: settings.overlayGlowIntensity)
    }

    static func lockStarted() -> KikiScreenEdgeOverlayPresentation {
        .lockStarted(
            title: "Keyboard locked",
            subtitle: "Input returns when you unlock or the timer ends."
        )
    }

    static func lockEnded(reason: InputLockUnlockReason?) -> KikiScreenEdgeOverlayPresentation {
        .lockEnded(
            tone: .success,
            title: unlockTitle(for: reason),
            subtitle: "Your keyboard is active."
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
            tint: previewTint,
            companionTint: previewCompanionTint,
            behavior: .momentary(duration: edgeDuration + 0.45),
            motion: .breathingWithEntryBurst,
            toastDuration: 1.4,
            edgeDuration: edgeDuration
        )
    }

    private static let previewTint = Color(red: 1.0, green: 0.49, blue: 0.12)
    private static let previewCompanionTint = Color(red: 0.86, green: 0.25, blue: 0.03)

    private static let edgeDuration: TimeInterval = 4.4

    static func unlockTitle(for reason: InputLockUnlockReason?) -> String {
        switch reason {
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
