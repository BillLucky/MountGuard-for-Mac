import Foundation
import Testing
@testable import MountGuardKit

@Test("只读卷跳过写入自测")
func skipsWriteTestForReadOnlyVolume() {
    let service = DiskIOTestService()
    let volume = DiskVolume(
        deviceIdentifier: "disk-test",
        deviceNode: "/dev/disk-test",
        wholeDiskIdentifier: "disk-test",
        diskUUID: nil,
        volumeName: "ReadOnly",
        mountPoint: "/Volumes/ReadOnly",
        fileSystemName: "NTFS",
        fileSystemType: "ntfs",
        busProtocol: "USB",
        contentDescription: "Microsoft Basic Data",
        totalBytes: 1024,
        freeBytes: 512,
        isMounted: true,
        isWritable: false,
        isExternal: true,
        isEjectable: true,
        isBootable: false,
        smartStatus: "Unknown"
    )

    let report = service.run(on: volume)

    #expect(report.status == .skipped)
    #expect(report.steps.count == 1)
    #expect(report.steps.first?.status == .skipped)
}

@Test("自测在临时目录完成并清理工作区")
func runsSelfTestInTemporaryDirectory() throws {
    let service = DiskIOTestService()
    let rootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("mountguard-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: rootURL) }

    let report = service.runForTesting(
        volumeIdentifier: "tmp",
        volumeName: "Temporary",
        rootURL: rootURL
    )

    #expect(report.status == .passed)
    #expect(report.steps.contains { $0.name == "cleanup" && $0.status == .passed })

    if let workspacePath = report.workspacePath {
        #expect(FileManager.default.fileExists(atPath: workspacePath) == false)
    } else {
        Issue.record("workspacePath should not be nil")
    }
}
