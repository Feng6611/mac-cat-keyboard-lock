import Combine
import Foundation
import KikiTriggerCorner

enum CatKeyboardLockOnboardingPhase: String, CaseIterable, Equatable {
    case welcome
    case permission
    case permissionSuccess
    case lockWithCorner
    case lockSuccess
    case unlockWithCorner
    case unlockSuccess

    var progressIndex: Int {
        switch self {
        case .welcome:
            return 0
        case .permission, .permissionSuccess:
            return 1
        case .lockWithCorner, .lockSuccess:
            return 2
        case .unlockWithCorner, .unlockSuccess:
            return 3
        }
    }
}

@MainActor
final class CatKeyboardLockOnboardingSession: ObservableObject {
    @Published private(set) var phase: CatKeyboardLockOnboardingPhase = .welcome
    @Published var isPaywallPresented = false

    private let lockSettings: LockSettings
    private let inputLockController: InputLockController
    private let onFinish: @MainActor () -> Void
    private var cancellables: Set<AnyCancellable> = []
    private var didStart = false
    private var didComplete = false

    private lazy var cornerMonitor = KikiTriggerCornerMonitor(
        configurationProvider: { [weak self] in
            guard let self else { return .disabled }
            return KikiTriggerCornerConfiguration(
                isEnabled: true,
                corner: self.lockSettings.triggerCorner,
                edgeSize: LockSettings.triggerCornerEdgeSize
            )
        },
        onTrigger: { [weak self] _ in
            self?.handleCornerTrigger()
        }
    )

    init(
        lockSettings: LockSettings,
        inputLockController: InputLockController,
        onFinish: @escaping @MainActor () -> Void
    ) {
        self.lockSettings = lockSettings
        self.inputLockController = inputLockController
        self.onFinish = onFinish
    }

    var triggerCorner: KikiTriggerCorner {
        lockSettings.triggerCorner
    }

    func start() {
        guard !didStart else { return }
        didStart = true

        inputLockController.$permissionStatus
            .sink { [weak self] status in
                self?.handlePermissionStatus(status)
            }
            .store(in: &cancellables)

        inputLockController.$state
            .sink { [weak self] state in
                self?.handleLockState(state)
            }
            .store(in: &cancellables)

        inputLockController.refreshPermissions()
    }

    func advance() {
        switch phase {
        case .welcome:
            phase = .permission
            inputLockController.refreshPermissions()
            handlePermissionStatus(inputLockController.permissionStatus)
        case .permission:
            requestAccessibility()
        case .permissionSuccess:
            beginCornerTutorial()
        case .lockWithCorner, .unlockWithCorner:
            break
        case .lockSuccess:
            cornerMonitor.disarmUntilExit()
            phase = .unlockWithCorner
        case .unlockSuccess:
            isPaywallPresented = true
        }
    }

    func requestAccessibility() {
        inputLockController.requestPermissions()
        handlePermissionStatus(inputLockController.permissionStatus)
    }

    func refreshAccessibility() {
        inputLockController.refreshPermissions()
        handlePermissionStatus(inputLockController.permissionStatus)
    }

    func complete() {
        guard !didComplete else { return }
        didComplete = true
        isPaywallPresented = false
        cornerMonitor.stop()
        cancellables.removeAll()

        if inputLockController.state.isLocked {
            inputLockController.unlock(reason: .manual)
        }

        // Completing the tutorial opts in the corner the user just practiced.
        lockSettings.triggerCornerEnabled = true
        onFinish()
    }

    private func beginCornerTutorial() {
        // The tutorial owns its monitor. Keeping the persisted monitor disabled
        // avoids two monitors responding to the same dwell while onboarding.
        lockSettings.triggerCornerEnabled = false
        cornerMonitor.start()
        phase = .lockWithCorner
    }

    private func handlePermissionStatus(_ status: InputLockPermissionStatus) {
        guard phase == .permission, status.accessibilityTrusted else { return }
        phase = .permissionSuccess
    }

    func handleCornerTrigger() {
        switch phase {
        case .lockWithCorner:
            inputLockController.lock()
        case .unlockWithCorner:
            inputLockController.unlock(reason: .triggerCorner)
        default:
            break
        }
    }

    private func handleLockState(_ state: InputLockState) {
        switch phase {
        case .lockWithCorner where state.isLocked:
            cornerMonitor.disarmUntilExit()
            phase = .lockSuccess
        case .unlockWithCorner where !state.isLocked:
            guard inputLockController.lastUnlockReason == .triggerCorner else { return }
            cornerMonitor.stop()
            phase = .unlockSuccess
        default:
            break
        }
    }
}
