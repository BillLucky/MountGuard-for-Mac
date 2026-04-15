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

@MainActor
final class DiskDashboardModel: ObservableObject {
    @Published private(set) var volumes: [DiskVolume] = []
    @Published private(set) var logs: [OperationLogEntry] = []
    @Published private(set) var usageByVolumeID: [DiskVolume.ID: [DiskProcessUsage]] = [:]
    @Published private(set) var ioTestReportsByVolumeID: [DiskVolume.ID: DiskIOTestReport] = [:]
    @Published var selectedVolumeID: DiskVolume.ID?
    @Published var isLoading = false
    @Published var lastErrorMessage: String?

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
    private let monitor: DiskArbitrationMonitor?
    private let logger = Logger(subsystem: "com.mountguard.local", category: "dashboard")
    private var hasStarted = false
    private var knownVolumeIDs: Set<String> = []

    init(
        inventoryService: DiskInventoryService = DiskInventoryService(),
        commandService: DiskCommandService = DiskCommandService(),
        ioTestService: DiskIOTestService = DiskIOTestService(),
        monitor: DiskArbitrationMonitor? = DiskArbitrationMonitor()
    ) {
        self.inventoryService = inventoryService
        self.commandService = commandService
        self.ioTestService = ioTestService
        self.monitor = monitor
        self.monitor?.onChange = { [weak self] in
            Task {
                await self?.refresh(reason: "检测到磁盘变化", logSuccess: true, attemptAutoMount: true)
            }
        }
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            await refresh(reason: "应用启动", logSuccess: false, attemptAutoMount: true)
        }
    }

    func supportsEnhancedReadWrite(for volume: DiskVolume) -> Bool {
        commandService.supportsEnhancedReadWrite(for: volume)
    }

    func accessStrategyDescription(for volume: DiskVolume) -> String {
        commandService.accessStrategyDescription(for: volume)
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
                appendLog(.success, "\(reason)：已刷新 \(fetchedVolumes.count) 个外接卷")
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "\(reason)：\(error.localizedDescription)")
        }
    }

    func mountDefault(_ volume: DiskVolume, isAutomatic: Bool = false) async {
        do {
            let commandService = self.commandService
            try await Task.detached(priority: .userInitiated) {
                try commandService.mountDefault(volume)
            }.value

            let prefix = isAutomatic ? "自动挂载完成" : "手动挂载完成"
            appendLog(.success, "\(prefix)：\(volume.displayName)")
            await refresh(reason: prefix, logSuccess: false)
        } catch {
            lastErrorMessage = error.localizedDescription
            let prefix = isAutomatic ? "自动挂载失败" : "挂载失败"
            appendLog(.error, "\(prefix)：\(volume.displayName) - \(error.localizedDescription)")
            await refresh(reason: "\(prefix) 后同步状态", logSuccess: false)
        }
    }

    func remountNTFSReadWrite(_ volume: DiskVolume) async {
        do {
            let commandService = self.commandService
            try await Task.detached(priority: .userInitiated) {
                try commandService.remountNTFSReadWrite(volume)
            }.value

            appendLog(.success, "增强读写挂载完成：\(volume.displayName)")
            await refresh(reason: "增强读写挂载完成", logSuccess: false)
        } catch {
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "增强读写挂载失败：\(volume.displayName) - \(error.localizedDescription)")
            await refresh(reason: "增强读写挂载失败后同步状态", logSuccess: false)
        }
    }

    func unmount(_ volume: DiskVolume) async {
        do {
            let commandService = self.commandService
            try await Task.detached(priority: .userInitiated) {
                try commandService.unmount(volume)
            }.value

            appendLog(.success, "已卸载 \(volume.displayName)")
            await refresh(reason: "卸载完成", logSuccess: false)
        } catch {
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "卸载失败：\(volume.displayName) - \(error.localizedDescription)")
            await refresh(reason: "卸载失败后同步状态", logSuccess: false)
        }
    }

    func open(_ volume: DiskVolume) {
        guard let mountPoint = volume.mountPoint else {
            lastErrorMessage = "磁盘当前未挂载，无法打开。"
            appendLog(.error, "打开失败：\(volume.displayName) 当前未挂载")
            return
        }

        let url = URL(fileURLWithPath: mountPoint)
        guard FileManager.default.fileExists(atPath: mountPoint) else {
            lastErrorMessage = "挂载点已不存在，正在刷新磁盘状态。"
            appendLog(.error, "打开失败：\(volume.displayName) 的挂载点不存在")
            Task {
                await refresh(reason: "打开失败后同步状态", logSuccess: false)
            }
            return
        }

        if NSWorkspace.shared.open(url) {
            appendLog(.info, "已在 Finder 中打开 \(volume.displayName)")
        } else {
            lastErrorMessage = "Finder 未能打开该挂载点。"
            appendLog(.error, "打开失败：Finder 无法打开 \(volume.displayName)")
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
            lastErrorMessage = "磁盘当前未挂载，无法扫描占用。"
            appendLog(.error, "占用扫描失败：\(volume.displayName) 当前未挂载")
            return
        }

        appendLog(.info, "正在扫描占用：\(volume.displayName)")
        do {
            let commandService = self.commandService
            let processes = try await Task.detached(priority: .userInitiated) {
                try commandService.inspectUsage(of: volume)
            }.value

            usageByVolumeID[volume.id] = processes
            if processes.isEmpty {
                appendLog(.success, "占用扫描完成：\(volume.displayName) 当前无占用进程")
            } else {
                appendLog(.info, "占用扫描完成：\(volume.displayName) 检测到 \(processes.count) 个占用进程")
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "占用扫描失败：\(volume.displayName) - \(error.localizedDescription)")
            await refresh(reason: "占用扫描失败后同步状态", logSuccess: false)
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
            appendLog(.success, "磁盘自测通过：\(volume.displayName)")
        case .skipped:
            appendLog(.info, "磁盘自测已跳过：\(volume.displayName)")
        case .failed:
            lastErrorMessage = report.steps.last(where: { $0.status == .failed })?.detail ?? "磁盘自测失败"
            appendLog(.error, "磁盘自测失败：\(volume.displayName)")
        }
    }

    func eject(_ volume: DiskVolume) async {
        do {
            let commandService = self.commandService
            try await Task.detached(priority: .userInitiated) {
                try commandService.eject(volume)
            }.value

            usageByVolumeID[volume.id] = []

            appendLog(.success, "已请求安全移除 \(volume.displayName)")
            await refresh(reason: "安全移除完成", logSuccess: false)
        } catch let error as DiskCommandError {
            if case let .volumeBusy(processes) = error {
                usageByVolumeID[volume.id] = processes
            }
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "移除失败：\(volume.displayName) - \(error.localizedDescription)")
            await refresh(reason: "安全移除失败后同步状态", logSuccess: false)
        } catch {
            lastErrorMessage = error.localizedDescription
            appendLog(.error, "移除失败：\(volume.displayName) - \(error.localizedDescription)")
            await refresh(reason: "安全移除失败后同步状态", logSuccess: false)
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
