import Foundation

public enum DiskCommandError: LocalizedError, Equatable {
    case notEjectable
    case volumeBusy([DiskProcessUsage])

    public var errorDescription: String? {
        switch self {
        case .notEjectable:
            return "当前卷不支持安全移除。"
        case let .volumeBusy(processes):
            let details = processes.prefix(5).map(\.summary).joined(separator: ", ")
            if details.isEmpty {
                return "磁盘仍被占用，暂时无法安全移除。"
            }
            return "磁盘仍被占用，暂时无法安全移除：\(details)"
        }
    }
}

public struct DiskCommandService: Sendable {
    private let runner: any CommandRunning
    private let usageInspector: DiskUsageInspector

    public init(
        runner: any CommandRunning = ProcessCommandRunner(),
        usageInspector: DiskUsageInspector? = nil
    ) {
        self.runner = runner
        self.usageInspector = usageInspector ?? DiskUsageInspector(runner: runner)
    }

    public func inspectUsage(of volume: DiskVolume) throws -> [DiskProcessUsage] {
        try usageInspector.inspect(volume: volume)
    }

    public func eject(_ volume: DiskVolume) throws {
        guard volume.isEjectable else {
            throw DiskCommandError.notEjectable
        }

        let processes = try inspectUsage(of: volume)
        if !processes.isEmpty {
            throw DiskCommandError.volumeBusy(processes)
        }

        _ = try runner.run(URL(fileURLWithPath: "/usr/bin/sync"), arguments: [])

        if volume.isMounted {
            do {
                _ = try runner.run(
                    URL(fileURLWithPath: "/usr/sbin/diskutil"),
                    arguments: ["unmount", volume.deviceIdentifier]
                )
            } catch let error as CommandError {
                if !canIgnoreUnmountFailure(error) {
                    throw error
                }
            }
        }

        _ = try runner.run(
            URL(fileURLWithPath: "/usr/sbin/diskutil"),
            arguments: ["eject", volume.wholeDiskIdentifier]
        )
    }

    private func canIgnoreUnmountFailure(_ error: CommandError) -> Bool {
        guard case let .executionFailed(_, _, _, output) = error else {
            return false
        }

        let normalized = output.lowercased()
        return normalized.contains("not mounted") || normalized.contains("not currently mounted")
    }
}
