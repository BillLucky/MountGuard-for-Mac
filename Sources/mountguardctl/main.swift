import Foundation
import MountGuardKit

@main
struct MountGuardCLI {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let inventoryService = DiskInventoryService()
        let commandService = DiskCommandService()
        let ioTestService = DiskIOTestService()
        let doctorService = DiskDoctorService()

        do {
            switch arguments.first {
            case "list":
                let volumes = try inventoryService.fetchExternalVolumes()
                if volumes.isEmpty {
                    print(MountGuardLocalized.text("未发现外接卷", "No external volume found"))
                    return
                }

                for volume in volumes {
                    print("\(volume.displayName)\t\(volume.deviceIdentifier)\t\(volume.fileSystemName)\t\(volume.writeStatusText)\t\(volume.mountPoint ?? MountGuardLocalized.text("未挂载", "Not Mounted"))")
                }
            case "eject":
                guard let identifier = arguments.dropFirst().first else {
                    printHelpAndExit()
                }

                let volume = try inventoryService.fetchVolume(identifier: identifier)
                try commandService.eject(volume)
                print(MountGuardLocalized.text("已完成安全移除流程", "Safe eject finished") + " \(volume.displayName) (\(volume.wholeDiskIdentifier))")
            case "ps":
                guard let identifier = arguments.dropFirst().first else {
                    printHelpAndExit()
                }

                let volume = try inventoryService.fetchVolume(identifier: identifier)
                let usages = try commandService.inspectUsage(of: volume)
                if usages.isEmpty {
                    print(MountGuardLocalized.text("当前未检测到占用进程", "No blocking process detected"))
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
            case "doctor":
                guard let identifier = arguments.dropFirst().first else {
                    printHelpAndExit()
                }

                let volume = try inventoryService.fetchVolume(identifier: identifier)
                let report = try doctorService.diagnose(volume)
                print("Disk Doctor: \(volume.displayName) [\(report.status.rawValue)]")
                print(report.summary)
                for issue in report.issues {
                    print("- \(issue.title): \(issue.detail)")
                    if let recommendation = issue.recommendation {
                        print("  \(MountGuardLocalized.text("建议", "Recommendation")): \(recommendation)")
                    }
                }
                if let repairPlan = report.repairPlan {
                    print("Repair Plan: \(repairPlan.title)")
                    print(repairPlan.summary)
                    for step in repairPlan.steps {
                        print("  - \(step.title): \(step.detail)")
                    }
                }
            case "doctor-repair":
                guard let identifier = arguments.dropFirst().first else {
                    printHelpAndExit()
                }

                let volume = try inventoryService.fetchVolume(identifier: identifier)
                let report = try doctorService.repair(volume)
                print("Disk Doctor Repair: \(volume.displayName) [\(report.status.rawValue)]")
                print(report.summary)
            default:
                printHelpAndExit()
            }
        } catch {
            fputs("\(MountGuardLocalized.text("错误", "Error")): \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func printHelpAndExit() -> Never {
        print(
            """
            MountGuard CLI

            \(MountGuardLocalized.text("用法", "Usage")):
              mountguardctl list
              mountguardctl eject <diskIdentifier>
              mountguardctl ps <diskIdentifier>
              mountguardctl selftest <diskIdentifier>
              mountguardctl doctor <diskIdentifier>
              mountguardctl doctor-repair <diskIdentifier>
            """
        )
        exit(0)
    }
}
