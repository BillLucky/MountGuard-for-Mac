import Foundation

public enum DiskDoctorError: LocalizedError, Equatable {
    case repairUnavailable
    case repairRequiresAdministrator

    public var errorDescription: String? {
        switch self {
        case .repairUnavailable:
            return "当前机器没有可用的 NTFS 修复工具，无法在 macOS 本地执行自动修复。"
        case .repairRequiresAdministrator:
            return "磁盘医生修复需要管理员授权；这是系统提权，不是“完全磁盘访问”权限。"
        }
    }
}

public struct DiskDoctorService: Sendable {
    private let runner: any CommandRunning
    private let ntfsfixPath: String

    public init(
        runner: any CommandRunning = ProcessCommandRunner(),
        ntfsfixPath: String? = nil
    ) {
        self.runner = runner
        self.ntfsfixPath = ntfsfixPath
            ?? Self.firstExistingPath(candidates: ["/opt/homebrew/bin/ntfsfix", "/usr/local/bin/ntfsfix"])
            ?? "/opt/homebrew/bin/ntfsfix"
    }

    public func diagnose(_ volume: DiskVolume) throws -> DiskDoctorReport {
        var issues: [DiskDoctorIssue] = []

        if volume.fileSystemType.lowercased() == "ntfs" {
            issues.append(contentsOf: ntfsBaselineIssues(for: volume))
            issues.append(contentsOf: verifyVolumeIssues(for: volume))
            issues.append(contentsOf: ntfsNoActionIssues(for: volume))
        } else {
            issues.append(contentsOf: verifyVolumeIssues(for: volume))
        }

        if issues.isEmpty {
            issues.append(
                DiskDoctorIssue(
                    id: "healthy",
                    status: .healthy,
                    title: "未发现阻断项",
                    detail: "当前没有检测到阻止正常挂载的明显风险信号。"
                )
            )
        }

        let status = issues.reduce(DiskDoctorStatus.healthy) { partial, issue in
            switch (partial, issue.status) {
            case (.blocked, _):
                return .blocked
            case (_, .blocked):
                return .blocked
            case (.warning, _):
                return .warning
            case (_, .warning):
                return .warning
            default:
                return .healthy
            }
        }

        return DiskDoctorReport(
            volumeID: volume.id,
            status: status,
            summary: summaryText(for: status),
            issues: issues,
            repairPlan: repairPlan(for: volume, issues: issues, status: status)
        )
    }

    public func repair(_ volume: DiskVolume) throws -> DiskDoctorReport {
        guard volume.fileSystemType.lowercased() == "ntfs" else {
            return try diagnose(volume)
        }

        guard FileManager.default.isExecutableFile(atPath: ntfsfixPath) else {
            throw DiskDoctorError.repairUnavailable
        }

        let shellScript = "\(shellQuote(ntfsfixPath)) \(shellQuote(volume.deviceNode))"
        let script = "do shell script \(appleScriptString(shellScript)) with administrator privileges"
        let result = try runner.runResult(
            URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", script]
        )

        let output = String(data: result.data, encoding: .utf8) ?? ""
        if Self.isAuthorizationFailure(output) {
            throw DiskDoctorError.repairRequiresAdministrator
        }

        if result.terminationStatus != 0 {
            throw CommandError.executionFailed(
                executable: "/usr/bin/osascript",
                arguments: ["-e", script],
                status: result.terminationStatus,
                output: output.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return try diagnose(volume)
    }

    func verifyVolumeIssues(for volume: DiskVolume) -> [DiskDoctorIssue] {
        let result: CommandResult
        do {
            result = try runner.runResult(
                URL(fileURLWithPath: "/usr/sbin/diskutil"),
                arguments: ["verifyVolume", volume.deviceIdentifier]
            )
        } catch {
            return [
                DiskDoctorIssue(
                    id: "verify-unavailable",
                    status: .warning,
                    title: "无法启动系统校验",
                    detail: error.localizedDescription,
                    recommendation: "先确保磁盘保持连接稳定，再重试诊断。"
                )
            ]
        }

        let output = String(data: result.data, encoding: .utf8) ?? ""
        if output.localizedCaseInsensitiveContains("Invalid request") && volume.fileSystemType.lowercased() == "ntfs" {
            return [
                DiskDoctorIssue(
                    id: "verify-unsupported-ntfs",
                    status: .warning,
                    title: "macOS 原生校验不支持这块 NTFS 卷",
                    detail: "系统返回 Invalid request，说明这类 NTFS 卷不能依赖 `diskutil verifyVolume` 做有效校验。",
                    recommendation: "请结合 Windows 的 `chkdsk` 或只读 `ntfsfix -n` 诊断结果来判断是否安全。"
                )
            ]
        }

        if result.terminationStatus != 0 {
            return [
                DiskDoctorIssue(
                    id: "verify-failed",
                    status: .warning,
                    title: "系统校验未完成",
                    detail: output.isEmpty ? "系统校验失败，但没有返回更多信息。" : output.trimmingCharacters(in: .whitespacesAndNewlines),
                    recommendation: "先使用只读诊断确认卷状态，再决定是否去 Windows 执行修复。"
                )
            ]
        }

        return [
            DiskDoctorIssue(
                id: "verify-ok",
                status: .healthy,
                title: "系统校验已完成",
                detail: "macOS 原生校验命令已完成，没有返回阻断信息。"
            )
        ]
    }

    func ntfsNoActionIssues(for volume: DiskVolume) -> [DiskDoctorIssue] {
        guard FileManager.default.isExecutableFile(atPath: ntfsfixPath) else {
            return [
                DiskDoctorIssue(
                    id: "ntfsfix-missing",
                    status: .warning,
                    title: "缺少 NTFS 只读诊断工具",
                    detail: "当前机器没有检测到 `ntfsfix`，无法进一步分析 NTFS unsafe state。",
                    recommendation: "安装 ntfs-3g 工具链后再运行磁盘医生。"
                )
            ]
        }

        let shellScript = "\(shellQuote(ntfsfixPath)) -n \(shellQuote(volume.deviceNode))"
        let script = "do shell script \(appleScriptString(shellScript)) with administrator privileges"

        let result: CommandResult
        do {
            result = try runner.runResult(
                URL(fileURLWithPath: "/usr/bin/osascript"),
                arguments: ["-e", script]
            )
        } catch {
            return [
                DiskDoctorIssue(
                    id: "ntfsfix-unavailable",
                    status: .warning,
                    title: "NTFS 只读诊断未执行",
                    detail: error.localizedDescription,
                    recommendation: "点击“运行诊断”时允许管理员授权；该诊断不会改写磁盘。"
                )
            ]
        }

        let output = String(data: result.data, encoding: .utf8) ?? ""
        if Self.isAuthorizationFailure(output) {
            return [
                DiskDoctorIssue(
                    id: "ntfsfix-canceled",
                    status: .warning,
                    title: "管理员授权已取消",
                    detail: "磁盘医生没有拿到原始设备的只读诊断权限，因此无法继续分析 unsafe state。",
                    recommendation: "重新运行诊断并允许管理员授权；`ntfsfix -n` 只做检查，不会写盘。"
                )
            ]
        }

        let parsedIssues = Self.parseNTFSNoActionOutput(output)
        if result.terminationStatus != 0 && Self.hasOnlyNoBlockerIssue(parsedIssues) {
            return [
                DiskDoctorIssue(
                    id: "ntfsfix-failed",
                    status: .warning,
                    title: "NTFS 只读诊断未完成",
                    detail: output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "只读诊断命令提前退出，没有返回足够的 NTFS 状态信息。"
                        : output.trimmingCharacters(in: .whitespacesAndNewlines),
                    recommendation: "先重新运行只读诊断；如果仍然失败，请检查 ntfs-3g 工具链与管理员授权。"
                )
            ]
        }

        return parsedIssues
    }

    func ntfsBaselineIssues(for volume: DiskVolume) -> [DiskDoctorIssue] {
        var issues: [DiskDoctorIssue] = []

        if volume.fileSystemType.lowercased() == "ntfs" && !volume.isWritable {
            issues.append(
                DiskDoctorIssue(
                    id: "ntfs-read-only",
                    status: .warning,
                    title: "当前仍处于只读路径",
                    detail: "这块 NTFS 卷目前没有进入稳定的读写挂载状态。",
                    recommendation: "先做只读诊断，确认没有 unsafe state 之后再尝试增强读写挂载。"
                )
            )
        }

        return issues
    }

    static func parseNTFSNoActionOutput(_ output: String) -> [DiskDoctorIssue] {
        let normalized = output.lowercased()
        var issues: [DiskDoctorIssue] = []

        if normalized.contains("unsafe state") || normalized.contains("hibernation") || normalized.contains("fast restarting") {
            issues.append(
                DiskDoctorIssue(
                    id: "ntfs-unsafe-state",
                    status: .blocked,
                    title: "检测到 Windows 快速启动 / 休眠残留",
                    detail: "NTFS 报告该分区处于 unsafe state，常见原因是 Windows 没有完整关机、启用了快速启动，或卷仍保留休眠状态。",
                    recommendation: "回到 Windows 完整启动一次，关闭快速启动，执行正常关机，并运行 `chkdsk /f` 后再回到 MountGuard。当前不要强行切读写。"
                )
            )
        }

        if normalized.contains("volume is corrupt") || normalized.contains("you should run chkdsk") {
            issues.append(
                DiskDoctorIssue(
                    id: "ntfs-corrupt",
                    status: .blocked,
                    title: "检测到文件系统需要 Windows 修复",
                    detail: "只读诊断提示卷存在错误，并明确建议运行 `chkdsk`。",
                    recommendation: "先在 Windows 上运行 `chkdsk /f` 或图形化磁盘检查，确认修复完成后再尝试增强读写挂载。"
                )
            )
        }

        if issues.isEmpty {
            issues.append(
                DiskDoctorIssue(
                    id: "ntfs-no-blocker",
                    status: .healthy,
                    title: "未发现 NTFS unsafe blocker",
                    detail: "只读 NTFS 诊断没有返回明显的 unsafe state / hibernation / chkdsk 阻断信息。"
                )
            )
        }

        return issues
    }

    static func isAuthorizationFailure(_ output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("user canceled")
            || normalized.contains("not authorized")
            || normalized.contains("authorization cancelled")
            || normalized.contains("authentication canceled")
    }

    static func hasOnlyNoBlockerIssue(_ issues: [DiskDoctorIssue]) -> Bool {
        issues.count == 1 && issues[0].id == "ntfs-no-blocker"
    }

    private static func firstExistingPath(candidates: [String]) -> String? {
        let fileManager = FileManager.default
        return candidates.first(where: { fileManager.fileExists(atPath: $0) })
    }

    private func repairPlan(
        for volume: DiskVolume,
        issues: [DiskDoctorIssue],
        status: DiskDoctorStatus
    ) -> DiskDoctorRepairPlan? {
        guard volume.fileSystemType.lowercased() == "ntfs" else {
            return nil
        }

        let issueIDs = Set(issues.map(\.id))
        guard status == .blocked || issueIDs.contains("ntfs-read-only") else {
            return nil
        }

        let canRunOnMac = FileManager.default.isExecutableFile(atPath: ntfsfixPath)
        if issueIDs.contains("ntfs-unsafe-state") || issueIDs.contains("ntfs-corrupt") {
            return DiskDoctorRepairPlan(
                title: "Mac 本地修复计划",
                summary: canRunOnMac
                    ? "MountGuard 可以先在 macOS 上执行一次谨慎的 NTFS 修复，尝试清理常见不一致、重置日志，并重新做只读诊断。"
                    : "当前机器缺少 `ntfsfix`，MountGuard 还不能在本地自动修复，只能先给出修复路径。",
                warning: "这一步会真正写入 NTFS 元数据，但它不是 Windows `chkdsk` 的完整替代。MountGuard 只会在你确认后执行，并在执行后重新诊断。",
                canRunOnMac: canRunOnMac,
                actionTitle: canRunOnMac ? "在 Mac 上尝试修复" : nil,
                steps: [
                    DiskDoctorRepairStep(
                        id: "doctor-review",
                        title: "确认风险说明",
                        detail: "先看清楚阻断项，再决定是否允许 MountGuard 在本地执行修复。",
                        isAutomatic: false
                    ),
                    DiskDoctorRepairStep(
                        id: "doctor-repair",
                        title: "执行 ntfsfix 修复",
                        detail: canRunOnMac
                            ? "MountGuard 会请求管理员授权，并调用 `ntfsfix <device>` 修复常见 NTFS 元数据问题。"
                            : "先安装 ntfs-3g / ntfsfix 工具链，再回到磁盘医生执行本地修复。",
                        isAutomatic: canRunOnMac
                    ),
                    DiskDoctorRepairStep(
                        id: "doctor-verify",
                        title: "重新诊断并决定是否挂载读写",
                        detail: "修复结束后，MountGuard 会重新跑诊断；只有阻断项消失后，才建议再次尝试增强读写挂载。",
                        isAutomatic: canRunOnMac
                    ),
                ]
            )
        }

        return nil
    }

    private func summaryText(for status: DiskDoctorStatus) -> String {
        switch status {
        case .healthy:
            return "当前没有检测到明显的阻断项。"
        case .warning:
            return "检测到需要注意的风险信号，建议先完成诊断提示再继续。"
        case .blocked:
            return "检测到阻断读写的风险信号；为了保护数据，当前不建议继续尝试增强读写挂载。"
        }
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
}
