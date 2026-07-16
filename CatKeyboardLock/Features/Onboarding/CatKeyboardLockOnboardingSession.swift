import Combine
import Foundation
import KikiTriggerCorner

enum CatKeyboardLockOnboardingPhase: String, CaseIterable, Equatable {
    case welcome
    case permission
    case permissionSuccess
    case lockPractice
    case unlockPractice
    case unlockSuccess

    var progressIndex: Int {
        switch self {
        case .welcome:
            return 0
        case .permission, .permissionSuccess:
            return 1
        case .lockPractice, .unlockPractice:
            return 2
        case .unlockSuccess:
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
    private var didCompleteCornerPractice = false
    private var previousTriggerCornerEnabled: Bool?

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
            beginCornerPractice()
        case .lockPractice, .unlockPractice:
            break
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

        if let previousTriggerCornerEnabled {
            lockSettings.triggerCornerEnabled = previousTriggerCornerEnabled || didCompleteCornerPractice
        }

        onFinish()
    }

    func handleCornerTrigger() {
        switch phase {
        case .lockPractice:
            inputLockController.lockForOnboardingPractice()
        case .unlockPractice:
            inputLockController.unlock(reason: .triggerCorner)
        default:
            break
        }
    }

    private func beginCornerPractice() {
        previousTriggerCornerEnabled = lockSettings.triggerCornerEnabled
        lockSettings.triggerCornerEnabled = false
        cornerMonitor.start()
        phase = .lockPractice
    }

    private func handlePermissionStatus(_ status: InputLockPermissionStatus) {
        guard phase == .permission, status.accessibilityTrusted else { return }
        phase = .permissionSuccess
    }

    private func handleLockState(_ state: InputLockState) {
        switch phase {
        case .lockPractice where state.isLocked:
            cornerMonitor.disarmUntilExit()
            phase = .unlockPractice
        case .unlockPractice where !state.isLocked:
            didCompleteCornerPractice = inputLockController.lastUnlockReason == .triggerCorner
            cornerMonitor.stop()
            phase = .unlockSuccess
        default:
            break
        }
    }
}
