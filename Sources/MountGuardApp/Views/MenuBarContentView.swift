import AppKit
import MountGuardKit
import SwiftUI

struct MenuBarContentView: View {
    @AppStorage("app.language") private var appLanguageCode = AppLanguage.english.rawValue
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var model: DiskDashboardModel

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageCode) ?? .english
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MountGuard")
                        .font(.headline)
                    Text(AppText.current("已发现 \(model.volumes.count) 个外接卷", "\(model.volumes.count) external volumes", language: appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task {
                        await model.refresh(reason: AppText.current("菜单栏刷新", "Menu refresh", language: appLanguage))
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
                    Text(AppText.current("未发现磁盘", "No Disk", language: appLanguage))
                        .font(.headline)
                    Text(AppText.current("插入磁盘后会自动刷新。", "Insert a disk to refresh automatically.", language: appLanguage))
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
                            Text(volume.isWritable ? AppText.current("可写", "Writable", language: appLanguage) : AppText.current("只读", "Read Only", language: appLanguage))
                                .font(.caption)
                                .foregroundStyle(volume.isWritable ? .green : .orange)
                        }

                        HStack {
                            if volume.isMounted {
                                Button(AppText.current("打开", "Open", language: appLanguage)) {
                                    model.open(volume)
                                }
                                .disabled(volume.mountPoint == nil)

                                Button(AppText.current("卸载", "Unmount", language: appLanguage)) {
                                    Task {
                                        await model.unmount(volume)
                                    }
                                }
                            } else {
                                Button(AppText.current("挂载", "Mount", language: appLanguage)) {
                                    Task {
                                        await model.mountDefault(volume)
                                    }
                                }
                            }

                            if volume.fileSystemType.lowercased() == "ntfs" && model.supportsEnhancedReadWrite(for: volume) {
                                Button(AppText.current("读写挂载", "RW Mount", language: appLanguage)) {
                                    Task {
                                        await model.remountNTFSReadWrite(volume)
                                    }
                                }
                            }

                            Button(AppText.current("安全移除", "Safe Eject", language: appLanguage), role: .destructive) {
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
                Button(AppText.current("主窗口", "Main Window", language: appLanguage)) {
                    openWindow(id: "main")
                    model.revealMainWindow()
                }
                Spacer()
                Link("GitHub", destination: URL(string: "https://github.com/BillLucky/MountGuard-for-Mac")!)
                    .font(.caption)
                Button(AppText.current("退出", "Quit", language: appLanguage)) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 360)
    }
}
