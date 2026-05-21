import CoreGraphics
import Foundation
import KikiTriggerCorner

@MainActor
final class LockSettings: ObservableObject {
    static let defaultLockDurationMinutes = 10
    static let lockDurationOptions = [5, 10, 30, 60]
    static let defaultOverlayEffectLevel = 4
    static let overlayEffectLevels = [1, 2, 3, 4, 5]
    static let defaultTriggerCorner = KikiTriggerCorner.topRight
    static let triggerCornerEdgeSize: CGFloat = 40

    @Published var lockKeyboard: Bool {
        didSet { defaults.set(lockKeyboard, forKey: Keys.lockKeyboard) }
    }
    @Published var lockMouseClicks: Bool {
        didSet { defaults.set(lockMouseClicks, forKey: Keys.lockMouseClicks) }
    }
    @Published var lockPointerMovement: Bool {
        didSet { defaults.set(lockPointerMovement, forKey: Keys.lockPointerMovement) }
    }
    @Published var lockDurationMinutes: Int {
        didSet { defaults.set(lockDurationMinutes, forKey: Keys.lockDurationMinutes) }
    }
    @Published var overlayEffectLevel: Int {
        didSet { defaults.set(overlayEffectLevel, forKey: Keys.overlayEffectLevel) }
    }
    @Published var triggerCornerEnabled: Bool {
        didSet { defaults.set(triggerCornerEnabled, forKey: Keys.triggerCornerEnabled) }
    }
    @Published var triggerCorner: KikiTriggerCorner {
        didSet { defaults.set(triggerCorner.rawValue, forKey: Keys.triggerCorner) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.lockKeyboard = defaults.object(forKey: Keys.lockKeyboard) as? Bool ?? true
        self.lockMouseClicks = defaults.object(forKey: Keys.lockMouseClicks) as? Bool ?? false
        self.lockPointerMovement = defaults.object(forKey: Keys.lockPointerMovement) as? Bool ?? false
        self.lockDurationMinutes = Self.validLockDurationMinutes(
            defaults.object(forKey: Keys.lockDurationMinutes) as? Int
        )
        self.overlayEffectLevel = Self.validOverlayEffectLevel(
            defaults.object(forKey: Keys.overlayEffectLevel) as? Int
        )
        self.triggerCornerEnabled = defaults.object(forKey: Keys.triggerCornerEnabled) as? Bool ?? false
        self.triggerCorner = Self.validTriggerCorner(
            defaults.string(forKey: Keys.triggerCorner)
        )
    }

    var policy: InputLockPolicy {
        InputLockPolicy(
            lockKeyboard: lockKeyboard,
            lockMouseClicks: lockMouseClicks,
            lockPointerMovement: lockPointerMovement
        )
    }

    var hasPointerLock: Bool {
        lockMouseClicks || lockPointerMovement
    }

    var lockDurationInterval: TimeInterval {
        TimeInterval(max(1, lockDurationMinutes) * 60)
    }

    var overlayGlowIntensity: Double {
        Double(overlayEffectLevel) / Double(Self.overlayEffectLevels.count)
    }

    var triggerCornerConfiguration: KikiTriggerCornerConfiguration {
        KikiTriggerCornerConfiguration(
            isEnabled: triggerCornerEnabled,
            corner: triggerCorner,
            edgeSize: Self.triggerCornerEdgeSize
        )
    }

    private static func validLockDurationMinutes(_ value: Int?) -> Int {
        guard let value, lockDurationOptions.contains(value) else {
            return defaultLockDurationMinutes
        }
        return value
    }

    private static func validOverlayEffectLevel(_ value: Int?) -> Int {
        guard let value, overlayEffectLevels.contains(value) else {
            return defaultOverlayEffectLevel
        }
        return value
    }

    private static func validTriggerCorner(_ value: String?) -> KikiTriggerCorner {
        guard let value, let triggerCorner = KikiTriggerCorner(rawValue: value) else {
            return defaultTriggerCorner
        }
        return triggerCorner
    }

    private enum Keys {
        static let lockKeyboard = "LockSettings.lockKeyboard"
        static let lockMouseClicks = "LockSettings.lockMouseClicks"
        static let lockPointerMovement = "LockSettings.lockPointerMovement"
        static let lockDurationMinutes = "LockSettings.lockDurationMinutes"
        static let overlayEffectLevel = "LockSettings.overlayEffectLevel"
        static let triggerCornerEnabled = "LockSettings.triggerCornerEnabled"
        static let triggerCorner = "LockSettings.triggerCorner"
    }
}

struct InputLockPolicy: Equatable {
    let lockKeyboard: Bool
    let lockMouseClicks: Bool
    let lockPointerMovement: Bool

    var eventTypes: [CGEventType] {
        var types = suppressedEventTypes
        types.appendUnique(contentsOf: Self.fallbackUnlockEventTypes)
        return types
    }

    var suppressedEventTypes: [CGEventType] {
        var types: [CGEventType] = []

        if lockKeyboard {
            types.appendUnique(contentsOf: [.keyDown, .keyUp, .flagsChanged])
        }

        if lockMouseClicks {
            types.appendUnique(contentsOf: [
                .leftMouseDown,
                .leftMouseUp,
                .rightMouseDown,
                .rightMouseUp,
                .otherMouseDown,
                .otherMouseUp
            ])
        }

        if lockPointerMovement {
            types.appendUnique(contentsOf: [
                .mouseMoved,
                .leftMouseDragged,
                .rightMouseDragged,
                .otherMouseDragged,
                .scrollWheel
            ])
        }

        return types
    }

    var eventMask: CGEventMask {
        eventTypes.reduce(CGEventMask(0)) { mask, type in
            mask | Self.mask(for: type)
        }
    }

    var isEmpty: Bool {
        suppressedEventTypes.isEmpty
    }

    func shouldSuppress(_ eventType: CGEventType) -> Bool {
        suppressedEventTypes.contains(eventType)
    }

    static func mask(for eventType: CGEventType) -> CGEventMask {
        CGEventMask(1) << CGEventMask(eventType.rawValue)
    }

    private static let fallbackUnlockEventTypes: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
}

private extension Array where Element == CGEventType {
    mutating func appendUnique(_ eventType: CGEventType) {
        if !contains(eventType) {
            append(eventType)
        }
    }

    mutating func appendUnique(contentsOf eventTypes: [CGEventType]) {
        for eventType in eventTypes {
            appendUnique(eventType)
        }
    }
}
