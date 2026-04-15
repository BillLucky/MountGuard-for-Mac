import Foundation
import Testing
@testable import MountGuardKit

@Test("解析外接卷列表 plist")
func decodesExternalVolumeIdentifiers() throws {
    let data = Data(listFixture.utf8)
    let identifiers = try DiskInventoryService.externalVolumeIdentifiers(from: data)

    #expect(identifiers == ["disk4s1", "disk4s2"])
}

@Test("解析卷详情 plist")
func decodesMountedVolumeInfo() throws {
    let data = Data(infoFixture.utf8)
    let volume = try DiskInventoryService.volume(from: data)

    #expect(volume.deviceIdentifier == "disk4s2")
    #expect(volume.displayName == "Backup")
    #expect(volume.mountPoint == "/Volumes/Backup")
    #expect(volume.fileSystemName == "NTFS")
    #expect(volume.isWritable == false)
    #expect(volume.wholeDiskIdentifier == "disk4")
    #expect(volume.totalBytes == 4_000_650_883_072)
}

@Test("空挂载点不应被视为已挂载")
func treatsEmptyMountPointAsUnmounted() throws {
    let data = Data(unmountedInfoFixture.utf8)
    let volume = try DiskInventoryService.volume(from: data)

    #expect(volume.mountPoint == nil)
    #expect(volume.isMounted == false)
}

@Test("磁盘医生应识别 NTFS unsafe state")
func parsesUnsafeNTFSDoctorOutput() {
    let issues = DiskDoctorService.parseNTFSNoActionOutput(unsafeNTFSFixture)

    #expect(issues.contains(where: { $0.id == "ntfs-unsafe-state" && $0.status == .blocked }))
    #expect(issues.contains(where: { $0.id == "ntfs-corrupt" && $0.status == .blocked }))
}

@Test("磁盘医生应将管理员取消识别为警告而不是健康")
func doctorTreatsAuthorizationCancellationAsWarning() throws {
    let service = DiskDoctorService(
        runner: MockCommandRunner { executableURL, _ in
            #expect(executableURL.path == "/usr/bin/osascript")
            return CommandResult(data: Data("User canceled.".utf8), terminationStatus: 1)
        },
        ntfsfixPath: try makeExecutableStub(named: "ntfsfix-cancel")
    )

    let issues = service.ntfsNoActionIssues(for: sampleNTFSVolume)

    #expect(issues.count == 1)
    #expect(issues.first?.id == "ntfsfix-canceled")
    #expect(issues.first?.status == .warning)
}

@Test("磁盘医生应在未知失败时返回诊断失败而不是健康")
func doctorTreatsUnknownFailureAsWarning() throws {
    let service = DiskDoctorService(
        runner: MockCommandRunner { executableURL, _ in
            #expect(executableURL.path == "/usr/bin/osascript")
            return CommandResult(data: Data("ntfsfix: probe failed".utf8), terminationStatus: 1)
        },
        ntfsfixPath: try makeExecutableStub(named: "ntfsfix-failed")
    )

    let issues = service.ntfsNoActionIssues(for: sampleNTFSVolume)

    #expect(issues.count == 1)
    #expect(issues.first?.id == "ntfsfix-failed")
    #expect(issues.first?.status == .warning)
}

@Test("磁盘医生应在非零退出码下继续识别 unsafe blocker")
func doctorKeepsUnsafeBlockersWhenCommandExitsNonZero() throws {
    let service = DiskDoctorService(
        runner: MockCommandRunner { executableURL, _ in
            #expect(executableURL.path == "/usr/bin/osascript")
            return CommandResult(data: Data(unsafeNTFSFixture.utf8), terminationStatus: 1)
        },
        ntfsfixPath: try makeExecutableStub(named: "ntfsfix-unsafe")
    )

    let issues = service.ntfsNoActionIssues(for: sampleNTFSVolume)

    #expect(issues.contains(where: { $0.id == "ntfs-unsafe-state" && $0.status == DiskDoctorStatus.blocked }))
    #expect(issues.contains(where: { $0.id == "ntfs-corrupt" && $0.status == DiskDoctorStatus.blocked }))
}

@Test("磁盘医生应为阻断型 NTFS 问题生成 Mac 修复计划")
func doctorBuildsMacRepairPlanForBlockedNTFS() throws {
    let service = DiskDoctorService(
        runner: MockCommandRunner { executableURL, _ in
            if executableURL.path == "/usr/sbin/diskutil" {
                return CommandResult(data: Data("Invalid request (-69886)".utf8), terminationStatus: 1)
            }
            if executableURL.path == "/usr/bin/osascript" {
                return CommandResult(data: Data(unsafeNTFSFixture.utf8), terminationStatus: 1)
            }
            fatalError("Unexpected command: \(executableURL.path)")
        },
        ntfsfixPath: try makeExecutableStub(named: "ntfsfix-plan")
    )

    let report = try service.diagnose(sampleNTFSVolume)

    #expect(report.status == .blocked)
    #expect(report.repairPlan?.canRunOnMac == true)
    #expect(report.repairPlan?.actionTitle == "在 Mac 上尝试修复")
}

@Test("磁盘医生修复在取消授权时应明确报错")
func doctorRepairRequiresAdminAuthorization() throws {
    let service = DiskDoctorService(
        runner: MockCommandRunner { executableURL, _ in
            #expect(executableURL.path == "/usr/bin/osascript")
            return CommandResult(data: Data("User canceled.".utf8), terminationStatus: 1)
        },
        ntfsfixPath: try makeExecutableStub(named: "ntfsfix-repair")
    )

    #expect(throws: DiskDoctorError.repairRequiresAdministrator) {
        try service.repair(sampleNTFSVolume)
    }
}

private let listFixture = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AllDisksAndPartitions</key>
    <array>
        <dict>
            <key>DeviceIdentifier</key>
            <string>disk4</string>
            <key>Partitions</key>
            <array>
                <dict>
                    <key>DeviceIdentifier</key>
                    <string>disk4s1</string>
                </dict>
                <dict>
                    <key>DeviceIdentifier</key>
                    <string>disk4s2</string>
                </dict>
            </array>
        </dict>
    </array>
</dict>
</plist>
"""

private let infoFixture = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Bootable</key>
    <true/>
    <key>BusProtocol</key>
    <string>USB</string>
    <key>Content</key>
    <string>Microsoft Basic Data</string>
    <key>DeviceIdentifier</key>
    <string>disk4s2</string>
    <key>DeviceNode</key>
    <string>/dev/disk4s2</string>
    <key>DiskUUID</key>
    <string>AFEB9DCF-35BB-4C01-BE23-B42A458FE3F2</string>
    <key>Ejectable</key>
    <true/>
    <key>FilesystemName</key>
    <string>NTFS</string>
    <key>FilesystemType</key>
    <string>ntfs</string>
    <key>FreeSpace</key>
    <integer>929370611712</integer>
    <key>MountPoint</key>
    <string>/Volumes/Backup</string>
    <key>ParentWholeDisk</key>
    <string>disk4</string>
    <key>RemovableMediaOrExternalDevice</key>
    <true/>
    <key>SMARTStatus</key>
    <string>Not Supported</string>
    <key>TotalSize</key>
    <integer>4000650883072</integer>
    <key>VolumeName</key>
    <string>Backup</string>
    <key>WritableVolume</key>
    <false/>
</dict>
</plist>
"""

private let unmountedInfoFixture = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Bootable</key>
    <true/>
    <key>BusProtocol</key>
    <string>USB</string>
    <key>Content</key>
    <string>Microsoft Basic Data</string>
    <key>DeviceIdentifier</key>
    <string>disk4s2</string>
    <key>DeviceNode</key>
    <string>/dev/disk4s2</string>
    <key>Ejectable</key>
    <true/>
    <key>FilesystemName</key>
    <string>NTFS</string>
    <key>FilesystemType</key>
    <string>ntfs</string>
    <key>FreeSpace</key>
    <integer>0</integer>
    <key>MountPoint</key>
    <string></string>
    <key>ParentWholeDisk</key>
    <string>disk4</string>
    <key>RemovableMediaOrExternalDevice</key>
    <true/>
    <key>SMARTStatus</key>
    <string>Not Supported</string>
    <key>TotalSize</key>
    <integer>4000650887168</integer>
    <key>VolumeName</key>
    <string>Backup</string>
    <key>WritableVolume</key>
    <false/>
</dict>
</plist>
"""

private let unsafeNTFSFixture = """
Mounting volume... OK
Processing of $MFT and $MFTMirr completed successfully.
The NTFS partition is in an unsafe state. Please resume and shutdown Windows fully (no hibernation or fast restarting), or mount the volume read-only with the 'ro' mount option.
Volume is corrupt. You should run chkdsk.
"""

private let sampleNTFSVolume = DiskVolume(
    deviceIdentifier: "disk4s2",
    deviceNode: "/dev/disk4s2",
    wholeDiskIdentifier: "disk4",
    diskUUID: nil,
    volumeName: "Backup",
    mountPoint: nil,
    fileSystemName: "NTFS",
    fileSystemType: "ntfs",
    busProtocol: "USB",
    contentDescription: "Microsoft Basic Data",
    totalBytes: 4_000_650_887_168,
    freeBytes: 0,
    isMounted: false,
    isWritable: false,
    isExternal: true,
    isEjectable: true,
    isBootable: false,
    smartStatus: "Not Supported"
)

private struct MockCommandRunner: CommandRunning {
    let handler: @Sendable (URL, [String]) throws -> CommandResult

    func runResult(_ executableURL: URL, arguments: [String]) throws -> CommandResult {
        try handler(executableURL, arguments)
    }
}

private func makeExecutableStub(named name: String) throws -> String {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

    let fileURL = url.appendingPathComponent(name)
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: fileURL)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: fileURL.path
    )
    return fileURL.path
}
