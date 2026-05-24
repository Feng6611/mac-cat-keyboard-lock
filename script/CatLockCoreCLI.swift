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

private enum CLIError: Error, CustomStringConvertible {
    case invalidArgument(String)

    var description: String {
        switch self {
        case .invalidArgument(let message):
            return message
        }
    }
}
