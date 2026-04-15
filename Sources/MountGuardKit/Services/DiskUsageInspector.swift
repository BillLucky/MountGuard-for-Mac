import Foundation

public struct DiskUsageInspector: Sendable {
    private let runner: any CommandRunning

    public init(runner: any CommandRunning = ProcessCommandRunner()) {
        self.runner = runner
    }

    public func inspect(volume: DiskVolume) throws -> [DiskProcessUsage] {
        guard let mountPoint = volume.mountPoint, !mountPoint.isEmpty else {
            return []
        }

        let result = try runner.runResult(
            URL(fileURLWithPath: "/usr/sbin/lsof"),
            arguments: ["-n", "-P", "-F", "pcLn0", "+f", "--", mountPoint]
        )

        if result.terminationStatus == 1 {
            return []
        }

        guard result.terminationStatus == 0 else {
            let output = String(data: result.data, encoding: .utf8) ?? "未知错误"
            throw CommandError.executionFailed(
                executable: "/usr/sbin/lsof",
                arguments: ["-n", "-P", "-F", "pcLn0", "+f", "--", mountPoint],
                status: result.terminationStatus,
                output: output.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return parse(result.data)
            .filter { !$0.filePaths.isEmpty }
            .sorted {
                if $0.command != $1.command {
                    return $0.command.localizedCaseInsensitiveCompare($1.command) == .orderedAscending
                }
                return $0.pid < $1.pid
            }
    }

    private func parse(_ data: Data) -> [DiskProcessUsage] {
        guard let payload = String(data: data, encoding: .utf8), !payload.isEmpty else {
            return []
        }

        var usages: [DiskProcessUsage] = []
        var currentPID: Int?
        var currentCommand = ""
        var currentUser = ""
        var currentPaths: [String] = []

        func flushCurrent() {
            guard let currentPID else { return }
            usages.append(
                DiskProcessUsage(
                    pid: currentPID,
                    command: currentCommand.isEmpty ? "unknown" : currentCommand,
                    user: currentUser.isEmpty ? "unknown" : currentUser,
                    filePaths: Array(Set(currentPaths)).sorted()
                )
            )
        }

        for token in payload.split(separator: "\0", omittingEmptySubsequences: true) {
            guard let prefix = token.first else { continue }
            let value = String(token.dropFirst())

            switch prefix {
            case "p":
                flushCurrent()
                currentPID = Int(value)
                currentCommand = ""
                currentUser = ""
                currentPaths = []
            case "c":
                currentCommand = value
            case "L":
                currentUser = value
            case "n":
                currentPaths.append(value)
            default:
                continue
            }
        }

        flushCurrent()
        return usages
    }
}
