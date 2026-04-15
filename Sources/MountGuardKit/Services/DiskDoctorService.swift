import Foundation

public enum DiskDoctorError: LocalizedError, Equatable {
    case repairUnavailable
    case repairRequiresAdministrator

    public var errorDescription: String? {
        switch self {
        case .repairUnavailable:
            return MountGuardLocalized.text("当前机器没有可用的 NTFS 修复工具，无法在 macOS 本地执行自动修复。", "This Mac does not have an NTFS repair tool available for guided local repair.")
        case .repairRequiresAdministrator:
            return MountGuardLocalized.text("磁盘医生修复需要管理员授权；这是系统提权，不是“完全磁盘访问”权限。", "Disk Doctor repair needs administrator approval. This is system elevation, not Full Disk Access.")
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
                    title: MountGuardLocalized.text("未发现阻断项", "No blocker found"),
                    detail: MountGuardLocalized.text("当前没有检测到阻止正常挂载的明显风险信号。", "No obvious signal is blocking normal mount right now.")
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
                    title: MountGuardLocalized.text("无法启动系统校验", "Cannot start system verification"),
                    detail: error.localizedDescription,
                    recommendation: MountGuardLocalized.text("先确保磁盘保持连接稳定，再重试诊断。", "Keep the disk connected and try diagnosis again.")
                )
            ]
        }

        let output = String(data: result.data, encoding: .utf8) ?? ""
        if output.localizedCaseInsensitiveContains("Invalid request") && volume.fileSystemType.lowercased() == "ntfs" {
            return [
                DiskDoctorIssue(
                    id: "verify-unsupported-ntfs",
                    status: .warning,
                    title: MountGuardLocalized.text("macOS 原生校验不支持这块 NTFS 卷", "macOS verification is not meaningful for this NTFS volume"),
                    detail: MountGuardLocalized.text("系统返回 Invalid request，说明这类 NTFS 卷不能依赖 `diskutil verifyVolume` 做有效校验。", "`diskutil verifyVolume` returned Invalid request, so this NTFS volume cannot rely on native macOS verification."),
                    recommendation: MountGuardLocalized.text("请结合只读 `ntfsfix -n` 诊断结果来判断是否安全。", "Use the read-only `ntfsfix -n` diagnosis to judge whether RW is safe.")
                )
            ]
        }

        if result.terminationStatus != 0 {
            return [
                DiskDoctorIssue(
                    id: "verify-failed",
                    status: .warning,
                    title: MountGuardLocalized.text("系统校验未完成", "System verification did not complete"),
                    detail: output.isEmpty ? MountGuardLocalized.text("系统校验失败，但没有返回更多信息。", "System verification failed without extra details.") : output.trimmingCharacters(in: .whitespacesAndNewlines),
                    recommendation: MountGuardLocalized.text("先使用只读诊断确认卷状态，再决定下一步修复。", "Use read-only diagnosis first, then decide on the next repair step.")
                )
            ]
        }

        return [
            DiskDoctorIssue(
                id: "verify-ok",
                status: .healthy,
                title: MountGuardLocalized.text("系统校验已完成", "System verification completed"),
                detail: MountGuardLocalized.text("macOS 原生校验命令已完成，没有返回阻断信息。", "Native macOS verification completed without blocker signals.")
            )
        ]
    }

    func ntfsNoActionIssues(for volume: DiskVolume) -> [DiskDoctorIssue] {
        guard FileManager.default.isExecutableFile(atPath: ntfsfixPath) else {
            return [
                DiskDoctorIssue(
                    id: "ntfsfix-missing",
                    status: .warning,
                    title: MountGuardLocalized.text("缺少 NTFS 只读诊断工具", "Missing NTFS diagnosis tool"),
                    detail: MountGuardLocalized.text("当前机器没有检测到 `ntfsfix`，无法进一步分析 NTFS unsafe state。", "This Mac does not have `ntfsfix`, so Disk Doctor cannot inspect NTFS unsafe state further."),
                    recommendation: MountGuardLocalized.text("安装 ntfs-3g 工具链后再运行磁盘医生。", "Install the ntfs-3g toolchain and run Disk Doctor again.")
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
                    title: MountGuardLocalized.text("NTFS 只读诊断未执行", "NTFS read-only diagnosis did not run"),
                    detail: error.localizedDescription,
                    recommendation: MountGuardLocalized.text("点击“运行诊断”时允许管理员授权；该诊断不会改写磁盘。", "Allow administrator approval when running diagnosis. This check does not write to the disk.")
                )
            ]
        }

        let output = String(data: result.data, encoding: .utf8) ?? ""
        if Self.isAuthorizationFailure(output) {
            return [
                DiskDoctorIssue(
                    id: "ntfsfix-canceled",
                    status: .warning,
                    title: MountGuardLocalized.text("管理员授权已取消", "Administrator approval was canceled"),
                    detail: MountGuardLocalized.text("磁盘医生没有拿到原始设备的只读诊断权限，因此无法继续分析 unsafe state。", "Disk Doctor could not get read-only device access, so it cannot continue the unsafe-state diagnosis."),
                    recommendation: MountGuardLocalized.text("重新运行诊断并允许管理员授权；`ntfsfix -n` 只做检查，不会写盘。", "Run diagnosis again and allow administrator approval. `ntfsfix -n` is read-only.")
                )
            ]
        }

        let parsedIssues = Self.parseNTFSNoActionOutput(output)
        if result.terminationStatus != 0 && Self.hasOnlyNoBlockerIssue(parsedIssues) {
            return [
                DiskDoctorIssue(
                    id: "ntfsfix-failed",
                    status: .warning,
                    title: MountGuardLocalized.text("NTFS 只读诊断未完成", "NTFS read-only diagnosis did not complete"),
                    detail: output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? MountGuardLocalized.text("只读诊断命令提前退出，没有返回足够的 NTFS 状态信息。", "The read-only diagnosis exited early without enough NTFS state details.")
                        : output.trimmingCharacters(in: .whitespacesAndNewlines),
                    recommendation: MountGuardLocalized.text("先重新运行只读诊断；如果仍然失败，请检查 ntfs-3g 工具链与管理员授权。", "Run the read-only diagnosis again. If it still fails, check the ntfs-3g toolchain and administrator approval.")
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
                    title: MountGuardLocalized.text("当前仍处于只读路径", "Still on the read-only path"),
                    detail: MountGuardLocalized.text("这块 NTFS 卷目前没有进入稳定的读写挂载状态。", "This NTFS volume is not in a stable RW mount state yet."),
                    recommendation: MountGuardLocalized.text("先做只读诊断，确认没有 unsafe state 之后再尝试增强读写挂载。", "Run read-only diagnosis first, then retry enhanced RW only if no blocker remains.")
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
                    title: MountGuardLocalized.text("检测到休眠或快速启动残留", "Hibernation or fast-startup residue detected"),
                    detail: MountGuardLocalized.text("NTFS 报告该分区处于 unsafe state，常见原因是卷仍带着休眠或快速启动残留。", "NTFS reports an unsafe state, usually caused by hibernation or fast-startup residue on the volume."),
                    recommendation: MountGuardLocalized.text("先在 MountGuard 中尝试本地修复；如果阻断仍存在，再使用更完整的外部修复方案。", "Try the guided local repair in MountGuard first. If the blocker remains, use a fuller external repair path.")
                )
            )
        }

        if normalized.contains("volume is corrupt") || normalized.contains("you should run chkdsk") {
            issues.append(
                DiskDoctorIssue(
                    id: "ntfs-corrupt",
                    status: .blocked,
                    title: MountGuardLocalized.text("检测到文件系统错误", "Filesystem errors detected"),
                    detail: MountGuardLocalized.text("只读诊断提示卷存在错误，需要先修复再尝试读写。", "The read-only diagnosis reports filesystem errors. Repair the volume before trying RW."),
                    recommendation: MountGuardLocalized.text("先在 MountGuard 中尝试本地修复；如果修复后仍被阻断，再使用更完整的外部修复方案。", "Try the guided local repair in MountGuard first. If it stays blocked, use a fuller external repair path.")
                )
            )
        }

        if issues.isEmpty {
            issues.append(
                DiskDoctorIssue(
                    id: "ntfs-no-blocker",
                    status: .healthy,
                    title: MountGuardLocalized.text("未发现 NTFS 阻断项", "No NTFS blocker found"),
                    detail: MountGuardLocalized.text("只读 NTFS 诊断没有返回明显阻断信息。", "The read-only NTFS diagnosis did not report an obvious blocker.")
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
                title: MountGuardLocalized.text("Mac 本地修复计划", "Guided Mac Repair"),
                summary: canRunOnMac
                    ? MountGuardLocalized.text("MountGuard 可以先在 macOS 上执行一次谨慎的 NTFS 修复，然后重新诊断。", "MountGuard can try a cautious NTFS repair on macOS, then run diagnosis again.")
                    : MountGuardLocalized.text("当前机器缺少 `ntfsfix`，MountGuard 还不能在本地自动修复。", "This Mac is missing `ntfsfix`, so guided local repair is not available yet."),
                warning: MountGuardLocalized.text("这一步会写入 NTFS 元数据，但不是完整的 `chkdsk` 替代。只有在你确认后才会执行。", "This step writes NTFS metadata, but it is not a full `chkdsk` replacement. It runs only after you confirm."),
                canRunOnMac: canRunOnMac,
                actionTitle: canRunOnMac ? MountGuardLocalized.text("在 Mac 上尝试修复", "Run Guided Repair") : nil,
                steps: [
                    DiskDoctorRepairStep(
                        id: "doctor-review",
                        title: MountGuardLocalized.text("确认风险说明", "Review the risk"),
                        detail: MountGuardLocalized.text("先看清楚阻断项，再决定是否允许 MountGuard 在本地执行修复。", "Review the blocker first, then decide whether to let MountGuard repair it locally."),
                        isAutomatic: false
                    ),
                    DiskDoctorRepairStep(
                        id: "doctor-repair",
                        title: MountGuardLocalized.text("执行 ntfsfix 修复", "Run ntfsfix"),
                        detail: canRunOnMac
                            ? MountGuardLocalized.text("MountGuard 会请求管理员授权，并调用 `ntfsfix <device>` 修复常见 NTFS 元数据问题。", "MountGuard asks for administrator approval and runs `ntfsfix <device>` for common NTFS metadata issues.")
                            : MountGuardLocalized.text("先安装 ntfs-3g / ntfsfix 工具链，再回到磁盘医生执行本地修复。", "Install the ntfs-3g / ntfsfix toolchain first, then come back to Disk Doctor."),
                        isAutomatic: canRunOnMac
                    ),
                    DiskDoctorRepairStep(
                        id: "doctor-verify",
                        title: MountGuardLocalized.text("重新诊断并决定是否挂载读写", "Re-check before RW mount"),
                        detail: MountGuardLocalized.text("修复结束后，MountGuard 会重新跑诊断；只有阻断项消失后，才建议再次尝试增强读写挂载。", "After repair, MountGuard runs diagnosis again and recommends RW remount only if the blocker is gone."),
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
            return MountGuardLocalized.text("当前没有检测到明显的阻断项。", "No obvious blocker is detected.")
        case .warning:
            return MountGuardLocalized.text("检测到需要注意的风险信号，建议先完成诊断提示再继续。", "A warning signal was detected. Review Disk Doctor before you continue.")
        case .blocked:
            return MountGuardLocalized.text("检测到阻断读写的风险信号；为了保护数据，当前不建议继续尝试增强读写挂载。", "A blocker is preventing safe RW access. MountGuard will keep the safer path.")
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
