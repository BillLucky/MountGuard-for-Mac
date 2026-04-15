import Foundation

public struct DiskIOTestService: Sendable {
    public init() {}

    public func run(on volume: DiskVolume) -> DiskIOTestReport {
        let startedAt = Date()
        var steps: [DiskIOTestStepResult] = []

        guard let mountPoint = volume.mountPoint, !mountPoint.isEmpty else {
            steps.append(
                DiskIOTestStepResult(
                    name: "mount-check",
                    status: .skipped,
                    detail: MountGuardLocalized.text("卷当前未挂载，跳过 IO 自测。", "The volume is not mounted, so the IO self-test was skipped.")
                )
            )
            return DiskIOTestReport(
                volumeIdentifier: volume.deviceIdentifier,
                volumeName: volume.displayName,
                workspacePath: nil,
                status: .skipped,
                startedAt: startedAt,
                finishedAt: Date(),
                steps: steps
            )
        }

        if !volume.isWritable {
            steps.append(
                DiskIOTestStepResult(
                    name: "writable-check",
                    status: .skipped,
                    detail: MountGuardLocalized.text("卷当前为只读，已跳过写入型自测以避免无意义失败。", "The volume is read-only, so write checks were skipped.")
                )
            )
            return DiskIOTestReport(
                volumeIdentifier: volume.deviceIdentifier,
                volumeName: volume.displayName,
                workspacePath: mountPoint,
                status: .skipped,
                startedAt: startedAt,
                finishedAt: Date(),
                steps: steps
            )
        }

        let rootURL = URL(fileURLWithPath: mountPoint, isDirectory: true)
        return run(
            volumeIdentifier: volume.deviceIdentifier,
            volumeName: volume.displayName,
            rootURL: rootURL,
            startedAt: startedAt
        )
    }

    public func runForTesting(volumeIdentifier: String, volumeName: String, rootURL: URL) -> DiskIOTestReport {
        run(
            volumeIdentifier: volumeIdentifier,
            volumeName: volumeName,
            rootURL: rootURL,
            startedAt: Date()
        )
    }

    private func run(volumeIdentifier: String, volumeName: String, rootURL: URL, startedAt: Date) -> DiskIOTestReport {
        let fileManager = FileManager.default
        let workspaceURL = rootURL
            .appendingPathComponent(".mountguard-selftest", isDirectory: true)
            .appendingPathComponent(timestampToken(), isDirectory: true)

        var steps: [DiskIOTestStepResult] = []
        var overallStatus: DiskIOTestStatus = .passed

        func record(_ name: String, _ work: () throws -> String) {
            guard overallStatus == .passed else { return }

            do {
                let detail = try work()
                steps.append(DiskIOTestStepResult(name: name, status: .passed, detail: detail))
            } catch {
                overallStatus = .failed
                steps.append(DiskIOTestStepResult(name: name, status: .failed, detail: error.localizedDescription))
            }
        }

        record("create-workspace") {
            try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
            return MountGuardLocalized.text("已创建工作目录 \(workspaceURL.path)", "Created workspace \(workspaceURL.path)")
        }

        let textFileURL = workspaceURL.appendingPathComponent("probe.txt")
        let textPayload = "MountGuard self-test\n"

        record("write-text-file") {
            guard let textData = textPayload.data(using: .utf8) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
            try textData.write(to: textFileURL, options: .atomic)
            return MountGuardLocalized.text("已写入文本探针文件", "Wrote text probe file")
        }

        record("read-text-file") {
            let content = try String(contentsOf: textFileURL, encoding: .utf8)
            guard content == textPayload else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return MountGuardLocalized.text("文本读回校验通过", "Text readback passed")
        }

        let emptyFileURL = workspaceURL.appendingPathComponent("empty.bin")
        record("create-empty-file") {
            guard fileManager.createFile(atPath: emptyFileURL.path, contents: Data(), attributes: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let attributes = try fileManager.attributesOfItem(atPath: emptyFileURL.path)
            let size = (attributes[.size] as? NSNumber)?.intValue ?? -1
            guard size == 0 else {
                throw CocoaError(.fileWriteUnknown)
            }
            return MountGuardLocalized.text("空文件边界写入通过", "Empty-file boundary check passed")
        }

        let sourceDirectory = workspaceURL.appendingPathComponent("copy-source", isDirectory: true)
        let copiedDirectory = workspaceURL.appendingPathComponent("copy-destination", isDirectory: true)
        let nestedFile = sourceDirectory.appendingPathComponent("nested/file.txt")

        record("copy-directory-tree") {
            try fileManager.createDirectory(
                at: nestedFile.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            guard let treeData = "tree-copy".data(using: .utf8) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
            try treeData.write(to: nestedFile, options: .atomic)
            try fileManager.copyItem(at: sourceDirectory, to: copiedDirectory)
            let copiedFile = copiedDirectory.appendingPathComponent("nested/file.txt")
            guard fileManager.fileExists(atPath: copiedFile.path) else {
                throw CocoaError(.fileReadNoSuchFile)
            }
            return MountGuardLocalized.text("目录复制通过", "Directory copy passed")
        }

        let renamedFile = workspaceURL.appendingPathComponent("probe-renamed.txt")
        record("rename-file") {
            try fileManager.moveItem(at: textFileURL, to: renamedFile)
            guard fileManager.fileExists(atPath: renamedFile.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
            return MountGuardLocalized.text("重命名通过", "Rename passed")
        }

        let binaryFile = workspaceURL.appendingPathComponent("payload.bin")
        record("write-4k-binary") {
            let payload = Data((0..<4096).map { UInt8($0 % 251) })
            try payload.write(to: binaryFile, options: .atomic)
            let data = try Data(contentsOf: binaryFile)
            guard data == payload else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return MountGuardLocalized.text("4KB 二进制写读校验通过", "4 KB binary read/write check passed")
        }

        do {
            if fileManager.fileExists(atPath: workspaceURL.path) {
                try fileManager.removeItem(at: workspaceURL)
            }
            steps.append(
                DiskIOTestStepResult(
                    name: "cleanup",
                    status: .passed,
                    detail: MountGuardLocalized.text("已清理工作目录", "Cleaned up workspace")
                )
            )
        } catch {
            overallStatus = .failed
            steps.append(
                DiskIOTestStepResult(
                    name: "cleanup",
                    status: .failed,
                    detail: error.localizedDescription
                )
            )
        }

        return DiskIOTestReport(
            volumeIdentifier: volumeIdentifier,
            volumeName: volumeName,
            workspacePath: workspaceURL.path,
            status: overallStatus,
            startedAt: startedAt,
            finishedAt: Date(),
            steps: steps
        )
    }

    private func timestampToken() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
