import AppKit
import Combine
import MountGuardKit
import OSLog

struct OperationLogEntry: Identifiable {
    enum Level {
        case info
        case success
        case error

        var symbolName: String {
            switch self {
            case .info:
                return "info.circle"
            case .success:
                return "checkmark.circle"
            case .error:
                return "exclamationmark.triangle"
            }
        }
    }

    let id = UUID()
    let level: Level
    let message: String
    let createdAt: Date
}

struct DoctorRepairConfirmation: Identifiable {
    let id = UUID()
    let volumeID: DiskVolume.ID
    let title: String
    let message: String
}

@MainActor
final class DiskDashboardModel: ObservableObject {
    @Published private(set) var volumes: [DiskVolume] = []
    @Published private(set) var logs: [OperationLogEntry] = []
    @Published private(set) var usageByVolumeID: [DiskVolume.ID: [DiskProcessUsage]] = [:]
    @Published private(set) var ioTestReportsByVolumeID: [DiskVolume.ID: DiskIOTestReport] = [:]
    @Published private(set) var doctorReportsByVolumeID: [DiskVolume.ID: DiskDoctorReport] = [:]
    @Published var selectedVolumeID: DiskVolume.ID?
    @Published var isLoading = false
    @Published var lastErrorMessage: String?
    @Published var pendingDoctorRepairConfirmation: DoctorRepairConfirmation?

    var selectedVolume: DiskVolume? {
        volumes.first { $0.id == selectedVolumeID }
    }

    var menuBarSymbolName: String {
        if logs.first?.level == .error {
            return "externaldrive.badge.exclamationmark"
        }
        return volumes.isEmpty ? "externaldrive.badge.questionmark" : "externaldrive.badge.checkmark"
    }

    private let inventoryService: DiskInventoryService
    private let commandService: DiskCommandService
    private let ioTestService: DiskIOTestService
    private let doctorService: DiskDoctorService
    private let monitor: DiskArbitrationMonitor?
    private let logger = Logger(subsystem: "com.mountguard.local", category: "dashboard")
    private var hasStarted = false
    private var knownVolumeIDs: Set<String> = []

    init(
        inventoryService: DiskInventoryService = DiskInventoryService(),
        commandService: DiskCommandService = DiskCommandService(),
        ioTestService: DiskIOTestService = DiskIOTestService(),
        doctorService: DiskDoctorService = DiskDoctorService(),
        monitor: DiskArbitrationMonitor? = DiskArbitrationMonitor()
    ) {
        self.inventoryService = inventoryService
        self.commandService = commandService
        self.ioTestService = ioTestService
        self.doctorService = doctorService
        self.monitor = monitor
        self.monitor?.onChange = { [weak self] in
            Task {
                await self?.refresh(reason: AppText.current("检测到磁盘变化", "Disk change detected"), logSuccess: true, attemptAutoMount: true)
            }
        }
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            await refresh(reason: AppText.current("应用启动", "App launch"), logSuccess: false, attemptAutoMount: true)
        }
    }

    func supportsEnhancedReadWrite(for volume: DiskVolume) -> Bool {
        commandService.supportsEnhancedReadWrite(for: volume)
    }

    func accessStrategyDescription(for volume: DiskVolume) -> String {
        commandService.accessStrategyDescription(for: volume)
    }

    func doctorReport(for volume: DiskVolume) -> DiskDoctorReport? {
        doctorReportsByVolumeID[volume.id]
    }

    func shouldBlockEnhancedReadWrite(for volume: DiskVolume) -> Bool {
        doctorReportsByVolumeID[volume.id]?.status == .blocked
    }

    func refresh(reason: String, logSuccess: Bool = true, attemptAutoMount: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let inventoryService = self.inventoryService
            let fetchedVolumes = try await Task.detached(priority: .userInitiated) {
                try inventoryService.fetchExternalVolumes()
            }.value

            volumes = fetchedVolumes
            let previousIDs = knownVolumeIDs
            knownVolumeIDs = Set(fetchedVolumes.map(\.id))
            if let selectedVolumeID, fetchedVolumes.contains(where: { $0.id == selectedVolumeID }) {
                self.selectedVolumeID = selectedVolumeID
            } else {
                self.selectedVolumeID = fetchedVolumes.first?.id
            }

            if attemptAutoMount && autoMountNewDisksEnabled {
                let newUnmountedVolumes = fetchedVolumes.filter { volume in
                    !volume.isMounted && !previousIDs.contains(volume.id)
                }

                for volume in newUnmountedVolumes {
                    await mountDefault(volume, isAutomatic: true)
                }
            }

            if logSuccess {
                appendLog(.success, "\(reason): \(AppText.current("已刷新", "Refreshed")) \(fetchedVolumes.count) \(AppText.current("个外接卷", "external volume(s)"))")
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "\(reason): \(error.localizedDescription)")
        }
    }

    func mountDefault(_ volume: DiskVolume, isAutomatic: Bool = false) async {
        do {
            let commandService = self.commandService
            try await Task.detached(priority: .userInitiated) {
                try commandService.mountDefault(volume)
            }.value

            let prefix = isAutomatic ? AppText.current("自动挂载完成", "Auto-mount finished") : AppText.current("手动挂载完成", "Manual mount finished")
            appendLog(.success, "\(prefix): \(volume.displayName)")
            await refresh(reason: prefix, logSuccess: false)
        } catch {
            lastErrorMessage = error.localizedDescription
            let prefix = isAutomatic ? AppText.current("自动挂载失败", "Auto-mount failed") : AppText.current("挂载失败", "Mount failed")
            appendLog(.error, "\(prefix): \(volume.displayName) - \(error.localizedDescription)")
            await refresh(reason: AppText.current("\(prefix) 后同步状态", "Refresh after \(prefix.lowercased())"), logSuccess: false)
        }
    }

    func remountNTFSReadWrite(_ volume: DiskVolume) async {
        do {
            let commandService = self.commandService
            try await Task.detached(priority: .userInitiated) {
                try commandService.remountNTFSReadWrite(volume)
            }.value

            appendLog(.success, "\(AppText.current("增强读写挂载完成", "Enhanced RW mount finished")): \(volume.displayName)")
            await refresh(reason: AppText.current("增强读写挂载完成", "Enhanced RW mount finished"), logSuccess: false)
        } catch {
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "\(AppText.current("增强读写挂载失败", "Enhanced RW mount failed")): \(volume.displayName) - \(error.localizedDescription)")
            await refresh(reason: AppText.current("增强读写挂载失败后同步状态", "Refresh after enhanced RW mount failure"), logSuccess: false)
        }
    }

    func unmount(_ volume: DiskVolume) async {
        do {
            let commandService = self.commandService
            try await Task.detached(priority: .userInitiated) {
                try commandService.unmount(volume)
            }.value

            appendLog(.success, "\(AppText.current("已卸载", "Unmounted")) \(volume.displayName)")
            await refresh(reason: AppText.current("卸载完成", "Unmount completed"), logSuccess: false)
        } catch {
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "\(AppText.current("卸载失败", "Unmount failed")): \(volume.displayName) - \(error.localizedDescription)")
            await refresh(reason: AppText.current("卸载失败后同步状态", "Refresh after unmount failure"), logSuccess: false)
        }
    }

    func open(_ volume: DiskVolume) {
        guard let mountPoint = volume.mountPoint else {
            lastErrorMessage = AppText.current("磁盘当前未挂载，无法打开。", "The disk is not mounted, so it cannot be opened.")
            appendLog(.error, "\(AppText.current("打开失败", "Open failed")): \(volume.displayName)")
            return
        }

        let url = URL(fileURLWithPath: mountPoint)
        guard FileManager.default.fileExists(atPath: mountPoint) else {
            lastErrorMessage = AppText.current("挂载点已不存在，正在刷新磁盘状态。", "The mount point no longer exists. Refreshing disk state.")
            appendLog(.error, "\(AppText.current("打开失败", "Open failed")): \(volume.displayName)")
            Task {
                await refresh(reason: AppText.current("打开失败后同步状态", "Refresh after open failure"), logSuccess: false)
            }
            return
        }

        if NSWorkspace.shared.open(url) {
            appendLog(.info, "\(AppText.current("已在 Finder 中打开", "Opened in Finder")) \(volume.displayName)")
        } else {
            lastErrorMessage = AppText.current("Finder 未能打开该挂载点。", "Finder could not open this mount point.")
            appendLog(.error, "\(AppText.current("打开失败", "Open failed")): \(volume.displayName)")
        }
    }

    func revealMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func usage(for volume: DiskVolume) -> [DiskProcessUsage] {
        usageByVolumeID[volume.id] ?? []
    }

    func ioTestReport(for volume: DiskVolume) -> DiskIOTestReport? {
        ioTestReportsByVolumeID[volume.id]
    }

    func inspectUsage(of volume: DiskVolume) async {
        guard volume.mountPoint != nil else {
            lastErrorMessage = AppText.current("磁盘当前未挂载，无法扫描占用。", "The disk is not mounted, so usage cannot be scanned.")
            appendLog(.error, "\(AppText.current("占用扫描失败", "Usage scan failed")): \(volume.displayName)")
            return
        }

        appendLog(.info, "\(AppText.current("正在扫描占用", "Scanning usage")): \(volume.displayName)")
        do {
            let commandService = self.commandService
            let processes = try await Task.detached(priority: .userInitiated) {
                try commandService.inspectUsage(of: volume)
            }.value

            usageByVolumeID[volume.id] = processes
            if processes.isEmpty {
                appendLog(.success, "\(AppText.current("占用扫描完成", "Usage scan finished")): \(volume.displayName)")
            } else {
                appendLog(.info, "\(AppText.current("占用扫描完成", "Usage scan finished")): \(volume.displayName) • \(processes.count) \(AppText.current("个占用进程", "process(es)"))")
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "\(AppText.current("占用扫描失败", "Usage scan failed")): \(volume.displayName) - \(error.localizedDescription)")
            await refresh(reason: AppText.current("占用扫描失败后同步状态", "Refresh after usage scan failure"), logSuccess: false)
        }
    }

    func runIOTest(on volume: DiskVolume) async {
        let ioTestService = self.ioTestService
        let report = await Task.detached(priority: .utility) {
            ioTestService.run(on: volume)
        }.value

        ioTestReportsByVolumeID[volume.id] = report
        switch report.status {
        case .passed:
            appendLog(.success, "\(AppText.current("磁盘自测通过", "Disk self-test passed")): \(volume.displayName)")
        case .skipped:
            appendLog(.info, "\(AppText.current("磁盘自测已跳过", "Disk self-test skipped")): \(volume.displayName)")
        case .failed:
            lastErrorMessage = report.steps.last(where: { $0.status == .failed })?.detail ?? AppText.current("磁盘自测失败", "Disk self-test failed")
            appendLog(.error, "\(AppText.current("磁盘自测失败", "Disk self-test failed")): \(volume.displayName)")
        }
    }

    func runDoctorDiagnosis(on volume: DiskVolume) async {
        appendLog(.info, "\(AppText.current("开始只读诊断", "Starting read-only diagnosis")): \(volume.displayName)")

        do {
            let doctorService = self.doctorService
            let report = try await Task.detached(priority: .userInitiated) {
                try doctorService.diagnose(volume)
            }.value

            doctorReportsByVolumeID[volume.id] = report
            switch report.status {
            case .healthy:
                appendLog(.success, "\(AppText.current("磁盘医生", "Disk Doctor")): \(volume.displayName) • \(AppText.current("未发现阻断项", "No blocker found"))")
            case .warning:
                appendLog(.info, "\(AppText.current("磁盘医生", "Disk Doctor")): \(volume.displayName) • \(AppText.current("检测到提醒", "Warning detected"))")
            case .blocked:
                lastErrorMessage = report.summary
                appendLog(.error, "\(AppText.current("磁盘医生", "Disk Doctor")): \(volume.displayName) • \(AppText.current("检测到阻断", "Blocker detected"))")
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "\(AppText.current("磁盘医生执行失败", "Disk Doctor failed")): \(volume.displayName) - \(error.localizedDescription)")
        }
    }

    func requestDoctorRepair(on volume: DiskVolume) async {
        if doctorReportsByVolumeID[volume.id] == nil {
            await runDoctorDiagnosis(on: volume)
        }

        guard let report = doctorReportsByVolumeID[volume.id], let plan = report.repairPlan else {
            lastErrorMessage = AppText.current("当前诊断没有给出可执行的修复计划。", "The current diagnosis did not produce a repair plan.")
            appendLog(.info, "\(AppText.current("磁盘医生", "Disk Doctor")): \(volume.displayName) • \(AppText.current("没有可执行修复计划", "No repair plan available"))")
            return
        }

        guard plan.canRunOnMac else {
            lastErrorMessage = plan.summary
            appendLog(.info, "\(AppText.current("磁盘医生", "Disk Doctor")): \(volume.displayName) • \(AppText.current("仅提供手动修复路径", "Manual repair only"))")
            return
        }

        pendingDoctorRepairConfirmation = DoctorRepairConfirmation(
            volumeID: volume.id,
            title: AppText.current("确认执行 Mac 本地修复", "Confirm guided Mac repair"),
            message: AppText.current(
                "MountGuard 将对 \(volume.displayName) 调用 ntfsfix 做一次谨慎修复，并在修复后重新诊断。这个过程会写入 NTFS 元数据，但只有在你确认后才会继续。",
                "MountGuard will run a cautious ntfsfix repair on \(volume.displayName), then diagnose it again. This writes NTFS metadata and only runs after you confirm."
            )
        )
    }

    func dismissDoctorRepairConfirmation() {
        pendingDoctorRepairConfirmation = nil
    }

    func confirmDoctorRepair() async {
        guard let confirmation = pendingDoctorRepairConfirmation else {
            return
        }
        pendingDoctorRepairConfirmation = nil

        guard let volume = volumes.first(where: { $0.id == confirmation.volumeID }) else {
            lastErrorMessage = AppText.current("目标磁盘状态已经变化，请先刷新后再试。", "The disk state changed. Refresh and try again.")
            appendLog(.error, AppText.current("磁盘医生修复失败: 目标磁盘已不在当前列表中", "Disk Doctor repair failed: the target disk is no longer in the list"))
            return
        }

        appendLog(.info, "\(AppText.current("开始 Mac 本地修复", "Starting guided Mac repair")): \(volume.displayName)")
        do {
            let doctorService = self.doctorService
            let report = try await Task.detached(priority: .userInitiated) {
                try doctorService.repair(volume)
            }.value

            doctorReportsByVolumeID[volume.id] = report
            await refresh(reason: AppText.current("Mac 本地修复完成", "Guided Mac repair finished"), logSuccess: false)

            switch report.status {
            case .healthy:
                appendLog(.success, "\(AppText.current("磁盘医生修复完成", "Disk Doctor repair finished")): \(volume.displayName) • \(AppText.current("未发现阻断项", "No blocker found"))")
            case .warning:
                appendLog(.info, "\(AppText.current("磁盘医生修复完成", "Disk Doctor repair finished")): \(volume.displayName) • \(AppText.current("当前为提醒状态", "Now in warning state"))")
            case .blocked:
                lastErrorMessage = report.summary
                appendLog(.error, "\(AppText.current("磁盘医生修复后仍存在阻断项", "Blocker remains after Disk Doctor repair")): \(volume.displayName)")
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "\(AppText.current("磁盘医生修复失败", "Disk Doctor repair failed")): \(volume.displayName) - \(error.localizedDescription)")
        }
    }

    func eject(_ volume: DiskVolume) async {
        do {
            let commandService = self.commandService
            try await Task.detached(priority: .userInitiated) {
                try commandService.eject(volume)
            }.value

            usageByVolumeID[volume.id] = []

            appendLog(.success, "\(AppText.current("已请求安全移除", "Safe eject requested")) \(volume.displayName)")
            await refresh(reason: AppText.current("安全移除完成", "Safe eject completed"), logSuccess: false)
        } catch let error as DiskCommandError {
            if case let .volumeBusy(processes) = error {
                usageByVolumeID[volume.id] = processes
            }
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "\(AppText.current("移除失败", "Eject failed")): \(volume.displayName) - \(error.localizedDescription)")
            await refresh(reason: AppText.current("安全移除失败后同步状态", "Refresh after safe eject failure"), logSuccess: false)
        } catch {
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "\(AppText.current("移除失败", "Eject failed")): \(volume.displayName) - \(error.localizedDescription)")
            await refresh(reason: AppText.current("安全移除失败后同步状态", "Refresh after safe eject failure"), logSuccess: false)
        }
    }

    private func appendLog(_ level: OperationLogEntry.Level, _ message: String) {
        let entry = OperationLogEntry(level: level, message: message, createdAt: Date())
        logs.insert(entry, at: 0)
        logs = Array(logs.prefix(50))

        switch level {
        case .info:
            logger.info("\(message, privacy: .public)")
        case .success:
            logger.notice("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }

    private var autoMountNewDisksEnabled: Bool {
        if UserDefaults.standard.object(forKey: "settings.autoMountNewDisks") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "settings.autoMountNewDisks")
    }
}
