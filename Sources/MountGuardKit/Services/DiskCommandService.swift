import Foundation
import Darwin

public enum DiskCommandError: LocalizedError, Equatable {
    case notEjectable
    case notMounted
    case enhancedReadWriteUnavailable
    case unsupportedFileSystemForEnhancedReadWrite
    case enhancedReadWriteRequiresAdministrator
    case ntfsUnsafeState
    case volumeBusy([DiskProcessUsage])

    public var errorDescription: String? {
        switch self {
        case .notEjectable:
            return MountGuardLocalized.text("当前卷不支持安全移除。", "This volume does not support safe eject.")
        case .notMounted:
            return MountGuardLocalized.text("当前卷尚未挂载。", "This volume is not mounted.")
        case .enhancedReadWriteUnavailable:
            return MountGuardLocalized.text("当前机器没有可用的 NTFS 增强读写通道。", "This Mac does not have an NTFS enhanced RW path available.")
        case .unsupportedFileSystemForEnhancedReadWrite:
            return MountGuardLocalized.text("增强读写挂载当前仅用于 NTFS 卷。", "Enhanced RW mount is available for NTFS volumes only.")
        case .enhancedReadWriteRequiresAdministrator:
            return MountGuardLocalized.text("NTFS 增强读写挂载需要管理员授权；这不是“完全磁盘访问”权限，而是系统提权。", "Enhanced RW mount needs administrator approval. This is system elevation, not Full Disk Access.")
        case .ntfsUnsafeState:
            return MountGuardLocalized.text("这块 NTFS 盘当前处于不安全状态，不能直接切到读写。请先修复后再试。为了保护数据，当前版本不会强行写入。", "This NTFS volume is in an unsafe state and cannot switch to RW yet. Repair it first. MountGuard will not force writes.")
        case let .volumeBusy(processes):
            let details = processes.prefix(5).map(\.summary).joined(separator: ", ")
            if details.isEmpty {
                return MountGuardLocalized.text("磁盘仍被占用，暂时无法安全移除。", "The disk is still busy and cannot be ejected safely yet.")
            }
            return MountGuardLocalized.text("磁盘仍被占用，暂时无法安全移除：\(details)", "The disk is still busy and cannot be ejected safely yet: \(details)")
        }
    }
}

public struct DiskCommandService: Sendable {
    private let runner: any CommandRunning
    private let usageInspector: DiskUsageInspector
    private let ntfs3gPath: String?
    private let macFusePath: String?
    private let ntfsfixPath: String?

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
        self.ntfsfixPath = Self.firstExistingPath(
            candidates: [
                "/opt/homebrew/bin/ntfsfix",
                "/usr/local/bin/ntfsfix",
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
        do {
            _ = try runner.run(
                URL(fileURLWithPath: "/usr/sbin/diskutil"),
                arguments: ["mount", volume.deviceIdentifier]
            )
        } catch let error as CommandError {
            if !canIgnoreMountFailure(error) {
                throw error
            }
        }
    }

    public func unmount(_ volume: DiskVolume) throws {
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

    public func remountNTFSReadWrite(_ volume: DiskVolume) throws {
        guard volume.fileSystemType.lowercased() == "ntfs" else {
            throw DiskCommandError.unsupportedFileSystemForEnhancedReadWrite
        }

        guard let ntfs3gPath, macFusePath != nil else {
            throw DiskCommandError.enhancedReadWriteUnavailable
        }

        try ensureSafeNTFSReadWriteAttempt(volume)

        let mountPoint = enhancedMountPoint(for: volume)
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: mountPoint.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let shellScript = [
            "/usr/sbin/diskutil unmount \(shellQuote(volume.deviceIdentifier)) >/dev/null 2>&1 || true",
            "/bin/mkdir -p \(shellQuote(mountPoint.path))",
            "\(shellQuote(ntfs3gPath)) \(shellQuote(volume.deviceNode)) \(shellQuote(mountPoint.path)) -olocal -oauto_xattr -owindows_names -ouid=\(getuid()) -ogid=\(getgid())",
        ].joined(separator: "; ")

        let script = "do shell script \(appleScriptString(shellScript)) with administrator privileges"
        let result = try runner.runResult(
            URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", script]
        )

        if result.terminationStatus != 0 {
            let output = String(data: result.data, encoding: .utf8) ?? MountGuardLocalized.text("未知错误", "Unknown error")
            if output.lowercased().contains("not authorized") || output.contains("User canceled") {
                throw DiskCommandError.enhancedReadWriteRequiresAdministrator
            }
            if isUnsafeNTFSState(output) {
                throw DiskCommandError.ntfsUnsafeState
            }
            throw CommandError.executionFailed(
                executable: "/usr/bin/osascript",
                arguments: ["-e", script],
                status: result.terminationStatus,
                output: output.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    public func eject(_ volume: DiskVolume) throws {
        guard volume.isEjectable else {
            throw DiskCommandError.notEjectable
        }

        let processes = try inspectUsage(of: volume)
        if !processes.isEmpty {
            throw DiskCommandError.volumeBusy(processes)
        }

        if volume.isMounted {
            _ = try runner.run(URL(fileURLWithPath: "/bin/sync"), arguments: [])
        }

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
                return MountGuardLocalized.text("系统默认会把 NTFS 挂成只读；可按需尝试增强读写。", "macOS mounts NTFS read-only by default. Enhanced RW is available if you need it.")
            }
            return MountGuardLocalized.text("系统当前会把 NTFS 挂成只读；本机尚未就绪增强读写通道。", "macOS will keep this NTFS volume read-only because the enhanced RW path is not ready on this Mac.")
        }

        if volume.isWritable {
            return MountGuardLocalized.text("当前文件系统已具备系统级可写挂载能力，可直接双向读写。", "This filesystem is writable through the default macOS path.")
        }

        return MountGuardLocalized.text("当前卷可挂载，但系统未报告可写能力。", "This volume can be mounted, but macOS does not report it as writable.")
    }

    private func canIgnoreUnmountFailure(_ error: CommandError) -> Bool {
        guard case let .executionFailed(_, _, _, output) = error else {
            return false
        }

        let normalized = output.lowercased()
        return normalized.contains("not mounted")
            || normalized.contains("not currently mounted")
            || normalized.contains("already unmounted")
    }

    private func canIgnoreMountFailure(_ error: CommandError) -> Bool {
        guard case let .executionFailed(_, _, _, output) = error else {
            return false
        }

        let normalized = output.lowercased()
        return normalized.contains("already mounted")
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

    private func enhancedMountPoint(for volume: DiskVolume) -> URL {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("MountGuardVolumes", isDirectory: true)
        return root.appendingPathComponent(sanitizedMountName(for: volume.displayName), isDirectory: true)
    }

    private func sanitizedMountName(for name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let parts = name.components(separatedBy: invalidCharacters)
        return parts.joined(separator: "-")
    }

    private func shellQuote(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    private func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func ensureSafeNTFSReadWriteAttempt(_ volume: DiskVolume) throws {
        guard let ntfsfixPath else {
            return
        }

        let shellScript = "\(shellQuote(ntfsfixPath)) -n \(shellQuote(volume.deviceNode))"
        let script = "do shell script \(appleScriptString(shellScript)) with administrator privileges"
        let result = try runner.runResult(
            URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", script]
        )

        let output = String(data: result.data, encoding: .utf8) ?? ""
        if DiskDoctorService.isAuthorizationFailure(output) {
            throw DiskCommandError.enhancedReadWriteRequiresAdministrator
        }

        let issues = DiskDoctorService.parseNTFSNoActionOutput(output)
        if issues.contains(where: { $0.status == .blocked }) {
            throw DiskCommandError.ntfsUnsafeState
        }

        if result.terminationStatus != 0 {
            throw CommandError.executionFailed(
                executable: "/usr/bin/osascript",
                arguments: ["-e", script],
                status: result.terminationStatus,
                output: output.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private func isUnsafeNTFSState(_ output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("unsafe state")
            || normalized.contains("fast restarting")
            || normalized.contains("hibernation")
            || normalized.contains("read-only with the 'ro' mount option")
            || normalized.contains("volume is corrupt")
            || normalized.contains("run chkdsk")
    }
}
