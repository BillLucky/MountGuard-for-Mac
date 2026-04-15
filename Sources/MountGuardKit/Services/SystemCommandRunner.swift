import Foundation

public struct CommandResult: Sendable {
    public let data: Data
    public let terminationStatus: Int32

    public init(data: Data, terminationStatus: Int32) {
        self.data = data
        self.terminationStatus = terminationStatus
    }
}

public protocol CommandRunning: Sendable {
    func runResult(_ executableURL: URL, arguments: [String]) throws -> CommandResult
}

public extension CommandRunning {
    func run(_ executableURL: URL, arguments: [String]) throws -> Data {
        let result = try runResult(executableURL, arguments: arguments)
        guard result.terminationStatus == 0 else {
            let message = String(data: result.data, encoding: .utf8) ?? "未知错误"
            throw CommandError.executionFailed(
                executable: executableURL.path,
                arguments: arguments,
                status: result.terminationStatus,
                output: message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return result.data
    }
}

public struct ProcessCommandRunner: CommandRunning {
    public init() {}

    public func runResult(_ executableURL: URL, arguments: [String]) throws -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return CommandResult(data: output, terminationStatus: process.terminationStatus)
    }
}

public enum CommandError: LocalizedError, Equatable {
    case executionFailed(executable: String, arguments: [String], status: Int32, output: String)
    case invalidPropertyList

    public var errorDescription: String? {
        switch self {
        case let .executionFailed(executable, arguments, status, output):
            let joinedArguments = arguments.joined(separator: " ")
            if output.isEmpty {
                return "命令执行失败: \(executable) \(joinedArguments) (exit: \(status))"
            }
            return "命令执行失败: \(executable) \(joinedArguments) (exit: \(status))\n\(output)"
        case .invalidPropertyList:
            return "系统返回了无法解析的 plist 数据。"
        }
    }
}
