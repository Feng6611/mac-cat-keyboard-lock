import Foundation

@main
struct CatLockCoreCLI {
    static func main() throws {
        var arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            printHelp()
            Foundation.exit(2)
        }
        arguments.removeFirst()

        switch command {
        case "evaluate":
            try evaluate(arguments)
        case "matrix":
            try matrix()
        case "help", "--help", "-h":
            printHelp()
        default:
            fputs("Unknown command: \(command)\n\n", stderr)
            printHelp()
            Foundation.exit(2)
        }
    }

    private static func evaluate(_ arguments: [String]) throws {
        let options = try parseOptions(arguments)
        let input = CatKeyboardLockCoreInput(
            access: try enumValue(
                options["access"] ?? "trial",
                CatKeyboardLockCoreAccess.self,
                name: "access"
            ),
            lockState: try enumValue(
                options["lock-state"] ?? "unlocked",
                CatKeyboardLockCoreLockState.self,
                name: "lock-state"
            ),
            accessibilityTrusted: try boolValue(options["accessibility"] ?? "allowed", name: "accessibility"),
            lockKeyboard: try boolValue(options["keyboard"] ?? "on", name: "keyboard"),
            lockMouseClicks: try boolValue(options["clicks"] ?? "off", name: "clicks"),
            lockPointerMovement: try boolValue(options["movement"] ?? "off", name: "movement")
        )

        let evaluation = CatKeyboardLockCore.evaluate(input)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(evaluation)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    private static func matrix() throws {
        let cases: [MatrixCase] = [
            MatrixCase(
                name: "trial-lock-ready",
                input: CatKeyboardLockCoreInput(
                    access: .trial,
                    accessibilityTrusted: true,
                    lockKeyboard: true,
                    lockMouseClicks: false,
                    lockPointerMovement: false
                ),
                expectedMenuLockTitle: "Lock Keyboard",
                expectedAction: .lock,
                expectedWarnings: []
            ),
            MatrixCase(
                name: "trial-needs-accessibility",
                input: CatKeyboardLockCoreInput(
                    access: .trial,
                    accessibilityTrusted: false,
                    lockKeyboard: true,
                    lockMouseClicks: false,
                    lockPointerMovement: false
                ),
                expectedMenuLockTitle: "Lock Keyboard",
                expectedAction: .openPermission,
                expectedWarnings: ["Accessibility is required before input can be locked."]
            ),
            MatrixCase(
                name: "pro-pointer-policy",
                input: CatKeyboardLockCoreInput(
                    access: .pro,
                    accessibilityTrusted: true,
                    lockKeyboard: true,
                    lockMouseClicks: true,
                    lockPointerMovement: true
                ),
                expectedMenuLockTitle: "Lock Input",
                expectedAction: .lock,
                expectedWarnings: []
            ),
            MatrixCase(
                name: "expired-routes-to-paywall",
                input: CatKeyboardLockCoreInput(
                    access: .expired,
                    accessibilityTrusted: true,
                    lockKeyboard: true,
                    lockMouseClicks: false,
                    lockPointerMovement: false
                ),
                expectedMenuLockTitle: "Upgrade to Lock...",
                expectedAction: .openPaywall,
                expectedWarnings: ["Access is not active."]
            ),
            MatrixCase(
                name: "not-started-routes-to-paywall",
                input: CatKeyboardLockCoreInput(
                    access: .notStarted,
                    accessibilityTrusted: true,
                    lockKeyboard: true,
                    lockMouseClicks: false,
                    lockPointerMovement: false
                ),
                expectedMenuLockTitle: "Start Trial / Upgrade...",
                expectedAction: .openPaywall,
                expectedWarnings: ["Access is not active."]
            ),
            MatrixCase(
                name: "locked-always-unlocks",
                input: CatKeyboardLockCoreInput(
                    access: .expired,
                    lockState: .locked,
                    accessibilityTrusted: false,
                    lockKeyboard: false,
                    lockMouseClicks: false,
                    lockPointerMovement: false
                ),
                expectedMenuLockTitle: "Unlock",
                expectedAction: .unlock,
                expectedWarnings: [
                    "Access is not active.",
                    "Choose at least one input type to lock."
                ]
            ),
            MatrixCase(
                name: "active-empty-policy",
                input: CatKeyboardLockCoreInput(
                    access: .trial,
                    accessibilityTrusted: true,
                    lockKeyboard: false,
                    lockMouseClicks: false,
                    lockPointerMovement: false
                ),
                expectedMenuLockTitle: "Lock Keyboard",
                expectedAction: .chooseInput,
                expectedWarnings: ["Choose at least one input type to lock."]
            )
        ]

        let results = cases.map { testCase in
            MatrixResult(case: testCase)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(results)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))

        if results.contains(where: { !$0.passed }) {
            Foundation.exit(1)
        }
    }

    private static func parseOptions(_ arguments: [String]) throws -> [String: String] {
        var options: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            guard argument.hasPrefix("--") else {
                throw CLIError.invalidArgument("Expected option, got \(argument)")
            }

            let keyValue = argument.dropFirst(2).split(separator: "=", maxSplits: 1).map(String.init)
            if keyValue.count == 2 {
                options[keyValue[0]] = keyValue[1]
                index += 1
                continue
            }

            guard index + 1 < arguments.count else {
                throw CLIError.invalidArgument("Missing value for \(argument)")
            }

            options[String(keyValue[0])] = arguments[index + 1]
            index += 2
        }

        return options
    }

    private static func enumValue<T>(
        _ rawValue: String,
        _ type: T.Type,
        name: String
    ) throws -> T where T: RawRepresentable, T.RawValue == String {
        guard let value = T(rawValue: rawValue) else {
            throw CLIError.invalidArgument("Invalid \(name): \(rawValue)")
        }

        return value
    }

    private static func boolValue(_ rawValue: String, name: String) throws -> Bool {
        switch rawValue.lowercased() {
        case "1", "true", "yes", "on", "allowed":
            return true
        case "0", "false", "no", "off", "denied":
            return false
        default:
            throw CLIError.invalidArgument("Invalid \(name): \(rawValue)")
        }
    }

    private static func printHelp() {
        print(
            """
            usage:
              script/catlock_core.sh evaluate [options]
              script/catlock_core.sh matrix

            options:
              --access notStarted|trial|expired|pro      default: trial
              --lock-state unlocked|locked               default: unlocked
              --accessibility allowed|denied             default: allowed
              --keyboard on|off                          default: on
              --clicks on|off                            default: off
              --movement on|off                          default: off

            example:
              script/catlock_core.sh evaluate --access trial --accessibility denied --keyboard on
            """
        )
    }
}

private struct MatrixCase {
    let name: String
    let input: CatKeyboardLockCoreInput
    let expectedMenuLockTitle: String
    let expectedAction: CatKeyboardLockCoreAction
    let expectedWarnings: [String]
}

private struct MatrixResult: Encodable {
    let name: String
    let passed: Bool
    let menuLockTitle: String
    let lockRequestAction: CatKeyboardLockCoreAction
    let warnings: [String]
    let expectedMenuLockTitle: String
    let expectedAction: CatKeyboardLockCoreAction
    let expectedWarnings: [String]

    init(case testCase: MatrixCase) {
        let evaluation = CatKeyboardLockCore.evaluate(testCase.input)
        self.name = testCase.name
        self.menuLockTitle = evaluation.menuLockTitle
        self.lockRequestAction = evaluation.lockRequestAction
        self.warnings = evaluation.warnings
        self.expectedMenuLockTitle = testCase.expectedMenuLockTitle
        self.expectedAction = testCase.expectedAction
        self.expectedWarnings = testCase.expectedWarnings
        self.passed = evaluation.menuLockTitle == testCase.expectedMenuLockTitle
            && evaluation.lockRequestAction == testCase.expectedAction
            && evaluation.warnings == testCase.expectedWarnings
    }
}

private enum CLIError: Error, CustomStringConvertible {
    case invalidArgument(String)

    var description: String {
        switch self {
        case .invalidArgument(let message):
            return message
        }
    }
}
