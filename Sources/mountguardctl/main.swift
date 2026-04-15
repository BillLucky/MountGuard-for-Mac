import Foundation
import MountGuardKit

@main
struct MountGuardCLI {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let inventoryService = DiskInventoryService()
        let commandService = DiskCommandService()
        let ioTestService = DiskIOTestService()

        do {
            switch arguments.first {
            case "list":
                let volumes = try inventoryService.fetchExternalVolumes()
                if volumes.isEmpty {
                    print("未发现外接卷")
                    return
                }

                for volume in volumes {
                    print("\(volume.displayName)\t\(volume.deviceIdentifier)\t\(volume.fileSystemName)\t\(volume.writeStatusText)\t\(volume.mountPoint ?? "未挂载")")
                }
            case "eject":
                guard let identifier = arguments.dropFirst().first else {
                    printHelpAndExit()
                }

                let volume = try inventoryService.fetchVolume(identifier: identifier)
                try commandService.eject(volume)
                print("已完成安全移除流程 \(volume.displayName) (\(volume.wholeDiskIdentifier))")
            case "ps":
                guard let identifier = arguments.dropFirst().first else {
                    printHelpAndExit()
                }

                let volume = try inventoryService.fetchVolume(identifier: identifier)
                let usages = try commandService.inspectUsage(of: volume)
                if usages.isEmpty {
                    print("当前未检测到占用进程")
                    return
                }

                for usage in usages {
                    print("\(usage.summary)\tuser=\(usage.user)")
                    for path in usage.filePaths {
                        print("  \(path)")
                    }
                }
            case "selftest":
                guard let identifier = arguments.dropFirst().first else {
                    printHelpAndExit()
                }

                let volume = try inventoryService.fetchVolume(identifier: identifier)
                let report = ioTestService.run(on: volume)
                print("Self-Test: \(report.volumeName) [\(report.status.rawValue)]")
                for step in report.steps {
                    print("- \(step.name): \(step.status.rawValue) - \(step.detail)")
                }
            default:
                printHelpAndExit()
            }
        } catch {
            fputs("错误: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func printHelpAndExit() -> Never {
        print(
            """
            MountGuard CLI

            用法:
              mountguardctl list
              mountguardctl eject <diskIdentifier>
              mountguardctl ps <diskIdentifier>
              mountguardctl selftest <diskIdentifier>
            """
        )
        exit(0)
    }
}
