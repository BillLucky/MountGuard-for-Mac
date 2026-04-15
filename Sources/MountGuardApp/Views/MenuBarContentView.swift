import AppKit
import MountGuardKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var model: DiskDashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MountGuard")
                        .font(.headline)
                    Text(AppText.current("已发现 \(model.volumes.count) 个外接卷", "\(model.volumes.count) external volumes"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task {
                        await model.refresh(reason: AppText.current("菜单栏刷新", "Menu refresh"))
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }

            if model.volumes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "externaldrive.badge.questionmark")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text(AppText.current("未发现磁盘", "No Disk"))
                        .font(.headline)
                    Text(AppText.current("插入磁盘后会自动刷新。", "Insert a disk to refresh automatically."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 320)
            } else {
                ForEach(model.volumes) { volume in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(volume.displayName)
                                    .font(.headline)
                                Text(volume.mountPoint ?? volume.deviceNode)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(volume.isWritable ? AppText.current("可写", "Writable") : AppText.current("只读", "Read Only"))
                                .font(.caption)
                                .foregroundStyle(volume.isWritable ? .green : .orange)
                        }

                        HStack {
                            Button(AppText.current("打开", "Open")) {
                                model.open(volume)
                            }
                            .disabled(volume.mountPoint == nil)

                            Button(AppText.current("安全移除", "Safe Eject"), role: .destructive) {
                                Task {
                                    await model.eject(volume)
                                }
                            }
                            .disabled(!volume.isEjectable)
                        }
                    }
                    if volume.id != model.volumes.last?.id {
                        Divider()
                    }
                }
            }

            Divider()

            HStack {
                Button(AppText.current("主窗口", "Main Window")) {
                    openWindow(id: "main")
                    model.revealMainWindow()
                }
                Spacer()
                Button(AppText.current("退出", "Quit")) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 360)
    }
}
