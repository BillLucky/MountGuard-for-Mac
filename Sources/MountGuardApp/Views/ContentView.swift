import MountGuardKit
import SwiftUI

struct ContentView: View {
    @AppStorage("app.language") private var appLanguageCode = AppLanguage.english.rawValue
    @AppStorage("settings.autoMountNewDisks") private var autoMountNewDisks = true
    @ObservedObject var model: DiskDashboardModel

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageCode) ?? .english
    }

    var body: some View {
        NavigationSplitView {
            List(model.volumes, selection: $model.selectedVolumeID) { volume in
                DiskRowView(volume: volume)
                    .tag(volume.id)
            }
            .navigationTitle(AppText.current("磁盘列表", "Disks", language: appLanguage))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await model.refresh(reason: AppText.current("手动刷新", "Manual refresh", language: appLanguage))
                        }
                    } label: {
                        Label(AppText.current("刷新", "Refresh", language: appLanguage), systemImage: "arrow.clockwise")
                    }
                }
            }
        } detail: {
            if let volume = model.selectedVolume {
                DiskDetailView(model: model, volume: volume)
            } else {
                EmptyStateView(
                    title: AppText.current("未发现外接磁盘", "No External Disk", language: appLanguage),
                    systemImage: "externaldrive.badge.questionmark",
                    message: AppText.current("插入移动硬盘或点击刷新重新扫描。", "Insert a removable disk or refresh to scan again.", language: appLanguage)
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            FooterBar(appLanguageCode: $appLanguageCode)
        }
        .overlay {
            if model.isLoading {
                ProgressView(AppText.current("正在同步磁盘状态...", "Syncing disk status...", language: appLanguage))
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert(
            AppText.current("操作失败", "Operation Failed", language: appLanguage),
            isPresented: Binding(
                get: { model.lastErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.lastErrorMessage = nil
                    }
                }
            )
        ) {
            Button(AppText.current("知道了", "OK", language: appLanguage), role: .cancel) {}
        } message: {
            Text(model.lastErrorMessage ?? "")
        }
    }
}

private struct DiskRowView: View {
    let volume: DiskVolume

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(volume.displayName)
                    .font(.headline)
                HStack(spacing: 10) {
                    Label(volume.fileSystemName, systemImage: "internaldrive")
                    Text(volume.isWritable ? AppText.current("可写", "Writable") : AppText.current("只读", "Read Only"))
                    Text(volume.isMounted ? AppText.current("已挂载", "Mounted") : AppText.current("未挂载", "Not Mounted"))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if volume.isMounted {
                Image(systemName: volume.isWritable ? "bolt.horizontal.circle.fill" : "lock.circle")
                    .foregroundStyle(volume.isWritable ? .green : .orange)
            } else {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DiskDetailView: View {
    @ObservedObject var model: DiskDashboardModel
    let volume: DiskVolume

    @AppStorage("app.language") private var appLanguageCode = AppLanguage.english.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageCode) ?? .english
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                GroupBox(AppText.current("挂载控制", "Mount Controls", language: appLanguage)) {
                    mountControlView
                }
                GroupBox(AppText.current("核心信息", "Overview", language: appLanguage)) {
                    detailGrid
                }
                GroupBox(AppText.current("占用进程", "Open Processes", language: appLanguage)) {
                    usageView
                }
                GroupBox(AppText.current("磁盘自测", "Disk Self-Test", language: appLanguage)) {
                    ioTestView
                }
                GroupBox(AppText.current("最近日志", "Recent Logs", language: appLanguage)) {
                    logsView
                }
            }
            .padding(24)
        }
        .navigationTitle(volume.displayName)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(volume.displayName)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                    Text(volume.mountPoint ?? AppText.current("当前未挂载", "Not mounted", language: appLanguage))
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text(model.accessStrategyDescription(for: volume))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.open(volume)
                } label: {
                    Label(AppText.current("打开磁盘", "Open", language: appLanguage), systemImage: "folder")
                }
                .disabled(volume.mountPoint == nil)

                Button {
                    Task {
                        await model.inspectUsage(of: volume)
                    }
                } label: {
                    Label(AppText.current("扫描占用", "Scan Usage", language: appLanguage), systemImage: "magnifyingglass")
                }
                .disabled(volume.mountPoint == nil)

                if volume.isMounted {
                    Button {
                        Task {
                            await model.unmount(volume)
                        }
                    } label: {
                        Label(AppText.current("卸载", "Unmount", language: appLanguage), systemImage: "tray.and.arrow.down")
                    }
                } else {
                    Button {
                        Task {
                            await model.mountDefault(volume)
                        }
                    } label: {
                        Label(AppText.current("挂载", "Mount", language: appLanguage), systemImage: "tray.and.arrow.up")
                    }
                }

                Button(role: .destructive) {
                    Task {
                        await model.eject(volume)
                    }
                } label: {
                    Label(AppText.current("安全移除", "Safe Eject", language: appLanguage), systemImage: "eject")
                }
                .disabled(!volume.isEjectable)
            }

            ProgressView(value: volume.usageFraction) {
                Text(DiskFormatters.capacitySummary(for: volume))
                    .font(.headline)
            } currentValueLabel: {
                Text("剩余 \(DiskFormatters.bytes(volume.freeBytes))")
            }
            .tint(volume.isWritable ? .accentColor : .orange)
        }
    }

    private var mountControlView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    volume.isMounted
                        ? AppText.current("当前已挂载", "Currently mounted", language: appLanguage)
                        : AppText.current("当前未挂载", "Currently unmounted", language: appLanguage),
                    systemImage: volume.isMounted ? "checkmark.circle" : "pause.circle"
                )
                .foregroundStyle(volume.isMounted ? .green : .secondary)

                Spacer()

                if volume.isMounted {
                    Button {
                        Task {
                            await model.unmount(volume)
                        }
                    } label: {
                        Label(AppText.current("卸载", "Unmount", language: appLanguage), systemImage: "eject")
                    }
                } else {
                    Button {
                        Task {
                            await model.mountDefault(volume)
                        }
                    } label: {
                        Label(AppText.current("系统挂载", "System Mount", language: appLanguage), systemImage: "externaldrive.badge.plus")
                    }
                }
            }

            if volume.fileSystemType.lowercased() == "ntfs" {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppText.current("NTFS 读写说明", "NTFS Read/Write", language: appLanguage))
                        .font(.headline)
                    Text(model.accessStrategyDescription(for: volume))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        Task {
                            await model.remountNTFSReadWrite(volume)
                        }
                    } label: {
                        Label(AppText.current("增强读写挂载", "Enhanced RW Mount", language: appLanguage), systemImage: "arrow.triangle.2.circlepath.circle")
                    }
                    .disabled(!model.supportsEnhancedReadWrite(for: volume))

                    Text(AppText.current("增强读写挂载会弹出一次管理员授权，并把 NTFS 挂到你的家目录 `~/MountGuardVolumes/磁盘名` 下。它不是“完全磁盘访问”权限。", "Enhanced RW Mount prompts once for administrator approval and mounts NTFS under `~/MountGuardVolumes/<disk-name>`. This is not Full Disk Access.", language: appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !model.supportsEnhancedReadWrite(for: volume) {
                        Text(AppText.current("当前机器缺少可用的 ntfs-3g / macFUSE 读写链路，仍可走系统只读挂载。", "This Mac does not currently have a usable ntfs-3g / macFUSE RW path, so MountGuard falls back to system read-only mount.", language: appLanguage))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(AppText.current("对 exFAT、APFS、HFS+ 等系统可写文件系统，MountGuard 优先使用系统默认挂载能力，保证稳定和传输效率。", "For exFAT, APFS, HFS+, and other system-writable filesystems, MountGuard prefers the default macOS mount path for stability and throughput.", language: appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var detailGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
            GridRow {
                DetailCell(title: AppText.current("设备", "Device", language: appLanguage), value: volume.deviceNode)
                DetailCell(title: AppText.current("整盘", "Whole Disk", language: appLanguage), value: volume.wholeDiskIdentifier)
            }
            GridRow {
                DetailCell(title: AppText.current("文件系统", "File System", language: appLanguage), value: volume.fileSystemName)
                DetailCell(title: AppText.current("总容量", "Capacity", language: appLanguage), value: DiskFormatters.bytes(volume.totalBytes))
            }
            GridRow {
                DetailCell(title: AppText.current("总线协议", "Bus", language: appLanguage), value: volume.busProtocol)
                DetailCell(title: AppText.current("空闲空间", "Free Space", language: appLanguage), value: DiskFormatters.bytes(volume.freeBytes))
            }
            GridRow {
                DetailCell(title: AppText.current("写入状态", "Write Mode", language: appLanguage), value: volume.isWritable ? AppText.current("可写", "Writable", language: appLanguage) : AppText.current("只读", "Read Only", language: appLanguage))
                DetailCell(title: "SMART", value: volume.smartStatus)
            }
            GridRow {
                DetailCell(title: AppText.current("卷 UUID", "Volume UUID", language: appLanguage), value: volume.diskUUID ?? "-")
                DetailCell(title: AppText.current("内容类型", "Content", language: appLanguage), value: volume.contentDescription)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var usageView: some View {
        let usages = model.usage(for: volume)

        return VStack(alignment: .leading, spacing: 10) {
            if usages.isEmpty {
                Text(AppText.current("当前未检测到占用进程。", "No blocking process is detected.", language: appLanguage))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(usages) { usage in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(usage.summary)
                            .font(.headline)
                        Text("\(AppText.current("用户", "User", language: appLanguage)): \(usage.user)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(usage.filePaths.prefix(3), id: \.self) { path in
                            Text(path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var ioTestView: some View {
        let report = model.ioTestReport(for: volume)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    Task {
                        await model.runIOTest(on: volume)
                    }
                } label: {
                    Label(AppText.current("运行自测", "Run Self-Test", language: appLanguage), systemImage: "checkmark.shield")
                }
                .disabled(volume.mountPoint == nil)

                if let report {
                    Text(statusText(for: report.status))
                        .font(.caption)
                        .foregroundStyle(statusColor(for: report.status))
                }
            }

            if let report {
                ForEach(report.steps) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: iconName(for: step.status))
                            .foregroundStyle(statusColor(for: step.status))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.name)
                                .font(.headline)
                            Text(step.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text(AppText.current("自测会只操作 MountGuard 自己创建的隐藏目录，并在结束后清理。", "Self-test only touches a MountGuard-owned hidden folder and cleans it afterwards.", language: appLanguage))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var logsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.logs.isEmpty {
                Text(AppText.current("暂无日志", "No logs yet", language: appLanguage))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.logs.prefix(12)) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: entry.level.symbolName)
                            .foregroundStyle(color(for: entry.level))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.message)
                            Text(entry.createdAt.formatted(date: .omitted, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private func color(for level: OperationLogEntry.Level) -> Color {
        switch level {
        case .info:
            return .blue
        case .success:
            return .green
        case .error:
            return .orange
        }
    }

    private func statusText(for status: DiskIOTestStatus) -> String {
        switch status {
        case .passed:
            return AppText.current("通过", "Passed", language: appLanguage)
        case .skipped:
            return AppText.current("已跳过", "Skipped", language: appLanguage)
        case .failed:
            return AppText.current("失败", "Failed", language: appLanguage)
        }
    }

    private func statusColor(for status: DiskIOTestStatus) -> Color {
        switch status {
        case .passed:
            return .green
        case .skipped:
            return .secondary
        case .failed:
            return .orange
        }
    }

    private func iconName(for status: DiskIOTestStatus) -> String {
        switch status {
        case .passed:
            return "checkmark.circle"
        case .skipped:
            return "arrow.uturn.forward.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
}

private struct FooterBar: View {
    @Binding var appLanguageCode: String
    @AppStorage("settings.autoMountNewDisks") private var autoMountNewDisks = true

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageCode) ?? .english
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppText.current("Bill 用爱创作🩷，让Mac 读写移动硬盘更加省心", "Made with love by Bill making reading and writing to external drives on your Mac completely hassle-free.", language: appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link("github.com/BillLucky/MountGuard-for-Mac", destination: URL(string: "https://github.com/BillLucky/MountGuard-for-Mac")!)
                    .font(.caption)
                Text(AppBuildInfo.versionText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(
                AppText.current("自动挂载新盘", "Auto-mount new disks", language: appLanguage),
                isOn: $autoMountNewDisks
            )
            .toggleStyle(.switch)
            .font(.caption)
            Picker(AppText.current("语言", "Language", language: appLanguage), selection: $appLanguageCode) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.label).tag(language.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .onChange(of: appLanguageCode) { newValue in
                if let language = AppLanguage(rawValue: newValue) {
                    AppText.setLanguage(language)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

private struct DetailCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
