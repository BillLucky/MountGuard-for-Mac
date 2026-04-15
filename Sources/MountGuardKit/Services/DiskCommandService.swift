import Foundation
import Darwin

public enum DiskCommandError: LocalizedError, Equatable {
    case notEjectable
    case notMounted
    case enhancedReadWriteUnavailable
    case unsupportedFileSystemForEnhancedReadWrite
    case volumeBusy([DiskProcessUsage])

    public var errorDescription: String? {
        switch self {
        case .notEjectable:
            return "当前卷不支持安全移除。"
        case .notMounted:
            return "当前卷尚未挂载。"
        case .enhancedReadWriteUnavailable:
            return "当前机器没有可用的 NTFS 增强读写通道。"
        case .unsupportedFileSystemForEnhancedReadWrite:
            return "增强读写挂载当前仅用于 NTFS 卷。"
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
    private let ntfs3gPath: String?
    private let macFusePath: String?

    public init(
        runner: any CommandRunning = ProcessCommandRunner(),
        usageInspector: DiskUsageInspector? = nil
    ) {
        self.runner = runner
        self.usageInspector = usageInspector ?? DiskUsageInspector(runner: runner)
        self.ntfs3gPath = Self.firstExistingPath(
            candidates: [
                "/opt/homebrew/bin/ntfs-3g",
                "/usr/local/bin/ntfs-3g",
            ]
        )
        self.macFusePath = Self.firstExistingPath(
            candidates: [
                "/Library/Filesystems/macfuse.fs/Contents/Resources/mount_macfuse",
            ]
        )
    }

    public func inspectUsage(of volume: DiskVolume) throws -> [DiskProcessUsage] {
        try usageInspector.inspect(volume: volume)
    }

    public func supportsEnhancedReadWrite(for volume: DiskVolume) -> Bool {
        volume.fileSystemType.lowercased() == "ntfs" && ntfs3gPath != nil && macFusePath != nil
    }

    public func mountDefault(_ volume: DiskVolume) throws {
        _ = try runner.run(
            URL(fileURLWithPath: "/usr/sbin/diskutil"),
            arguments: ["mount", volume.deviceIdentifier]
        )
    }

    public func unmount(_ volume: DiskVolume) throws {
        guard volume.isMounted else {
            throw DiskCommandError.notMounted
        }

        _ = try runner.run(
            URL(fileURLWithPath: "/usr/sbin/diskutil"),
            arguments: ["unmount", volume.deviceIdentifier]
        )
    }

    public func remountNTFSReadWrite(_ volume: DiskVolume) throws {
        guard volume.fileSystemType.lowercased() == "ntfs" else {
            throw DiskCommandError.unsupportedFileSystemForEnhancedReadWrite
        }

        guard let ntfs3gPath, macFusePath != nil else {
            throw DiskCommandError.enhancedReadWriteUnavailable
        }

        if volume.isMounted {
            try unmountIgnoringAlreadyUnmounted(volume)
        }

        let mountPoint = volume.mountPoint ?? "/Volumes/\(sanitizedMountName(for: volume.displayName))"
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: URL(fileURLWithPath: mountPoint, isDirectory: true),
            withIntermediateDirectories: true
        )

        _ = try runner.run(
            URL(fileURLWithPath: ntfs3gPath),
            arguments: [
                volume.deviceNode,
                mountPoint,
                "-olocal",
                "-oauto_xattr",
                "-owindows_names",
                "-ouid=\(getuid())",
                "-ogid=\(getgid())",
            ]
        )
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

    public func accessStrategyDescription(for volume: DiskVolume) -> String {
        if volume.fileSystemType.lowercased() == "ntfs" {
            if supportsEnhancedReadWrite(for: volume) {
                return "系统默认会把 NTFS 挂成只读；当前机器已检测到 ntfs-3g，可尝试增强读写挂载。"
            }
            return "系统当前会把 NTFS 挂成只读；本机尚未就绪增强读写通道。"
        }

        if volume.isWritable {
            return "当前文件系统已具备系统级可写挂载能力，可直接双向读写。"
        }

        return "当前卷可挂载，但系统未报告可写能力。"
    }

    private func canIgnoreUnmountFailure(_ error: CommandError) -> Bool {
        guard case let .executionFailed(_, _, _, output) = error else {
            return false
        }

        let normalized = output.lowercased()
        return normalized.contains("not mounted") || normalized.contains("not currently mounted")
    }

    private func unmountIgnoringAlreadyUnmounted(_ volume: DiskVolume) throws {
        do {
            try unmount(volume)
        } catch let error as CommandError {
            if !canIgnoreUnmountFailure(error) {
                throw error
            }
        } catch let error as DiskCommandError {
            if error != .notMounted {
                throw error
            }
        }
    }

    private static func firstExistingPath(candidates: [String]) -> String? {
        let fileManager = FileManager.default
        return candidates.first(where: { fileManager.fileExists(atPath: $0) })
    }

    private func sanitizedMountName(for name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let parts = name.components(separatedBy: invalidCharacters)
        return parts.joined(separator: "-")
    }
}
