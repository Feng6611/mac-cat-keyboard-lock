import Foundation

@main
struct CatLockCoreCLI {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        switch arguments.first {
        case "evaluate":
            try evaluate(arguments.dropFirst())
        case "matrix":
            try matrix()
        case "help", "--help", "-h", nil:
            printHelp()
        default:
            throw CLIError.invalidArgument("Unknown command")
        }
    }

    private static func evaluate(_ arguments: ArraySlice<String>) throws {
        let options = try parseOptions(arguments)
        let input = CatKeyboardLockCoreInput(
            lockState: try enumValue(options["lock-state"] ?? "unlocked", CatKeyboardLockCoreLockState.self),
            accessibilityTrusted: try boolValue(options["accessibility"] ?? "allowed")
        )
        try printJSON(CatKeyboardLockCore.evaluate(input))
    }

    private static func matrix() throws {
        let cases: [(String, CatKeyboardLockCoreInput, String, CatKeyboardLockCoreAction, [String])] = [
            ("free-lock-ready", .init(accessibilityTrusted: true), "Lock Keyboard", .lock, []),
            ("free-needs-accessibility", .init(accessibilityTrusted: false), "Lock Keyboard", .openPermission, ["Accessibility is required before input can be locked."]),
            ("locked-always-unlocks", .init(lockState: .locked, accessibilityTrusted: false), "Unlock", .unlock, ["Accessibility is required before input can be locked."])
        ]

        let results = cases.map { name, input, title, action, warnings in
            let evaluation = CatKeyboardLockCore.evaluate(input)
            return [
                "name": name,
                "passed": evaluation.menuLockTitle == title && evaluation.lockRequestAction == action && evaluation.warnings == warnings,
                "menuLockTitle": evaluation.menuLockTitle,
                "lockRequestAction": evaluation.lockRequestAction.rawValue,
                "warnings": evaluation.warnings
            ] as [String: Any]
        }
        let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
        if results.contains(where: { ($0["passed"] as? Bool) == false }) { Foundation.exit(1) }
    }

    private static func parseOptions(_ arguments: ArraySlice<String>) throws -> [String: String] {
        var result: [String: String] = [:]
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            guard argument.hasPrefix("--") else { throw CLIError.invalidArgument(argument) }
            let parts = argument.dropFirst(2).split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { result[parts[0]] = parts[1] }
            else if let value = iterator.next() { result[parts[0]] = value }
            else { throw CLIError.invalidArgument("Missing value for \(argument)") }
        }
        return result
    }

    private static func enumValue<T: RawRepresentable>(_ raw: String, _ type: T.Type) throws -> T where T.RawValue == String {
        guard let value = T(rawValue: raw) else { throw CLIError.invalidArgument(raw) }
        return value
    }

    private static func boolValue(_ raw: String) throws -> Bool {
        switch raw.lowercased() {
        case "1", "true", "yes", "on", "allowed": return true
        case "0", "false", "no", "off", "denied": return false
        default: throw CLIError.invalidArgument(raw)
        }
    }

    private static func printJSON<T: Encodable>(_ value: T) throws {
        let data = try JSONEncoder.pretty.encode(value)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    private static func printHelp() {
        print("usage: script/catlock_core.sh evaluate [--lock-state unlocked|locked] [--accessibility allowed|denied]\n       script/catlock_core.sh matrix")
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private enum CLIError: Error, CustomStringConvertible {
    case invalidArgument(String)
    var description: String { if case .invalidArgument(let message) = self { return message }; return "Invalid argument" }
}
