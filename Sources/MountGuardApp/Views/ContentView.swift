import MountGuardKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: DiskDashboardModel

    var body: some View {
        NavigationSplitView {
            List(model.volumes, selection: $model.selectedVolumeID) { volume in
                DiskRowView(volume: volume)
                    .tag(volume.id)
            }
            .navigationTitle(AppText.current("磁盘列表", "Disks"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await model.refresh(reason: AppText.current("手动刷新", "Manual refresh"))
                        }
                    } label: {
                        Label(AppText.current("刷新", "Refresh"), systemImage: "arrow.clockwise")
                    }
                }
            }
        } detail: {
            if let volume = model.selectedVolume {
                DiskDetailView(model: model, volume: volume)
            } else {
                EmptyStateView(
                    title: AppText.current("未发现外接磁盘", "No External Disk"),
                    systemImage: "externaldrive.badge.questionmark",
                    message: AppText.current("插入移动硬盘或点击刷新重新扫描。", "Insert a removable disk or refresh to scan again.")
                )
            }
        }
        .overlay {
            if model.isLoading {
                ProgressView(AppText.current("正在同步磁盘状态...", "Syncing disk status..."))
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert(
            AppText.current("操作失败", "Operation Failed"),
            isPresented: Binding(
                get: { model.lastErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.lastErrorMessage = nil
                    }
                }
            )
        ) {
            Button(AppText.current("知道了", "OK"), role: .cancel) {}
        } message: {
            Text(model.lastErrorMessage ?? "")
        }
    }
}

private struct DiskRowView: View {
    let volume: DiskVolume

    var body: some View {
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
        .padding(.vertical, 4)
    }
}

private struct DiskDetailView: View {
    @ObservedObject var model: DiskDashboardModel
    let volume: DiskVolume

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                GroupBox(AppText.current("核心信息", "Overview")) {
                    detailGrid
                }
                GroupBox(AppText.current("占用进程", "Open Processes")) {
                    usageView
                }
                GroupBox(AppText.current("磁盘自测", "Disk Self-Test")) {
                    ioTestView
                }
                GroupBox(AppText.current("最近日志", "Recent Logs")) {
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
                    Text(volume.mountPoint ?? "当前未挂载")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.open(volume)
                } label: {
                    Label(AppText.current("打开磁盘", "Open"), systemImage: "folder")
                }
                .disabled(volume.mountPoint == nil)

                Button {
                    Task {
                        await model.inspectUsage(of: volume)
                    }
                } label: {
                    Label(AppText.current("扫描占用", "Scan Usage"), systemImage: "magnifyingglass")
                }
                .disabled(volume.mountPoint == nil)

                Button(role: .destructive) {
                    Task {
                        await model.eject(volume)
                    }
                } label: {
                    Label(AppText.current("安全移除", "Safe Eject"), systemImage: "eject")
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

    private var detailGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
            GridRow {
                DetailCell(title: "设备", value: volume.deviceNode)
                DetailCell(title: AppText.current("整盘", "Whole Disk"), value: volume.wholeDiskIdentifier)
            }
            GridRow {
                DetailCell(title: AppText.current("文件系统", "File System"), value: volume.fileSystemName)
                DetailCell(title: AppText.current("总容量", "Capacity"), value: DiskFormatters.bytes(volume.totalBytes))
            }
            GridRow {
                DetailCell(title: AppText.current("总线协议", "Bus"), value: volume.busProtocol)
                DetailCell(title: AppText.current("空闲空间", "Free Space"), value: DiskFormatters.bytes(volume.freeBytes))
            }
            GridRow {
                DetailCell(title: AppText.current("写入状态", "Write Mode"), value: volume.isWritable ? AppText.current("可写", "Writable") : AppText.current("只读", "Read Only"))
                DetailCell(title: "SMART", value: volume.smartStatus)
            }
            GridRow {
                DetailCell(title: AppText.current("卷 UUID", "Volume UUID"), value: volume.diskUUID ?? "-")
                DetailCell(title: AppText.current("内容类型", "Content"), value: volume.contentDescription)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var usageView: some View {
        let usages = model.usage(for: volume)

        return VStack(alignment: .leading, spacing: 10) {
            if usages.isEmpty {
                Text(AppText.current("当前未检测到占用进程。", "No blocking process is detected."))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(usages) { usage in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(usage.summary)
                            .font(.headline)
                        Text("\(AppText.current("用户", "User")): \(usage.user)")
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
                    Label(AppText.current("运行自测", "Run Self-Test"), systemImage: "checkmark.shield")
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
                Text(AppText.current("自测会只操作 MountGuard 自己创建的隐藏目录，并在结束后清理。", "Self-test only touches a MountGuard-owned hidden folder and cleans it afterwards."))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var logsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.logs.isEmpty {
                Text(AppText.current("暂无日志", "No logs yet"))
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
            return AppText.current("通过", "Passed")
        case .skipped:
            return AppText.current("已跳过", "Skipped")
        case .failed:
            return AppText.current("失败", "Failed")
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
