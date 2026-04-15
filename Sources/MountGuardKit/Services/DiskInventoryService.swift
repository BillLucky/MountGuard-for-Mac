import Foundation

public struct DiskInventoryService: Sendable {
    private let runner: any CommandRunning

    public init(runner: any CommandRunning = ProcessCommandRunner()) {
        self.runner = runner
    }

    public func fetchExternalVolumes() throws -> [DiskVolume] {
        let listData = try runner.run(
            URL(fileURLWithPath: "/usr/sbin/diskutil"),
            arguments: ["list", "-plist", "external"]
        )
        let identifiers = try Self.externalVolumeIdentifiers(from: listData)

        let volumes = try identifiers.compactMap { identifier -> DiskVolume? in
            let volume = try fetchVolume(identifier: identifier)
            guard shouldInclude(volume) else {
                return nil
            }
            return volume
        }

        return volumes.sorted {
            if $0.isMounted != $1.isMounted {
                return $0.isMounted && !$1.isMounted
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    public func fetchVolume(identifier: String) throws -> DiskVolume {
        let infoData = try runner.run(
            URL(fileURLWithPath: "/usr/sbin/diskutil"),
            arguments: ["info", "-plist", identifier]
        )
        return try Self.volume(from: infoData)
    }

    private func shouldInclude(_ volume: DiskVolume) -> Bool {
        if let mountPoint = volume.mountPoint, !mountPoint.isEmpty {
            return true
        }

        if volume.fileSystemType != "unknown" {
            return true
        }

        let hiddenContents = [
            "Microsoft Reserved",
            "EFI",
        ]
        return !hiddenContents.contains(volume.contentDescription)
    }

    public static func externalVolumeIdentifiers(from data: Data) throws -> [String] {
        let plist = try plistDictionary(from: data)
        let disks = plist["AllDisksAndPartitions"] as? [[String: Any]] ?? []
        var identifiers: [String] = []

        for disk in disks {
            if let partitions = disk["Partitions"] as? [[String: Any]], !partitions.isEmpty {
                for partition in partitions {
                    if let identifier = partition["DeviceIdentifier"] as? String {
                        identifiers.append(identifier)
                    }
                }
                continue
            }

            if let identifier = disk["DeviceIdentifier"] as? String {
                identifiers.append(identifier)
            }
        }

        return identifiers
    }

    public static func volume(from data: Data) throws -> DiskVolume {
        let plist = try plistDictionary(from: data)

        let deviceIdentifier = stringValue(plist, key: "DeviceIdentifier")
        let deviceNode = stringValue(plist, key: "DeviceNode", default: "/dev/\(deviceIdentifier)")
        let wholeDisk = stringValue(plist, key: "ParentWholeDisk", default: deviceIdentifier)
        let volumeName = stringValue(
            plist,
            key: "VolumeName",
            default: stringValue(plist, key: "MediaName", default: deviceIdentifier)
        )
        let mountPoint = plist["MountPoint"] as? String
        let fileSystemName = stringValue(
            plist,
            key: "FilesystemName",
            default: stringValue(plist, key: "FilesystemUserVisibleName", default: "未知文件系统")
        )
        let fileSystemType = stringValue(plist, key: "FilesystemType", default: "unknown")
        let busProtocol = stringValue(plist, key: "BusProtocol", default: "Unknown")
        let content = stringValue(plist, key: "Content", default: "Unknown")
        let totalBytes = int64Value(plist, key: "TotalSize", fallbackKeys: ["VolumeSize", "IOKitSize", "Size"])
        let freeBytes = int64Value(plist, key: "FreeSpace")
        let isMounted = mountPoint != nil
        let isWritable = boolValue(plist, key: "WritableVolume", fallbackKeys: ["Writable"])
        let isExternal = boolValue(plist, key: "RemovableMediaOrExternalDevice", fallbackKeys: ["Ejectable", "Removable", "RemovableMedia"])
        let isEjectable = boolValue(plist, key: "Ejectable")
        let isBootable = boolValue(plist, key: "Bootable")
        let smartStatus = stringValue(plist, key: "SMARTStatus", default: "未知")
        let diskUUID = plist["DiskUUID"] as? String

        return DiskVolume(
            deviceIdentifier: deviceIdentifier,
            deviceNode: deviceNode,
            wholeDiskIdentifier: wholeDisk,
            diskUUID: diskUUID,
            volumeName: volumeName,
            mountPoint: mountPoint,
            fileSystemName: fileSystemName,
            fileSystemType: fileSystemType,
            busProtocol: busProtocol,
            contentDescription: content,
            totalBytes: totalBytes,
            freeBytes: freeBytes,
            isMounted: isMounted,
            isWritable: isWritable,
            isExternal: isExternal,
            isEjectable: isEjectable,
            isBootable: isBootable,
            smartStatus: smartStatus
        )
    }

    private static func plistDictionary(from data: Data) throws -> [String: Any] {
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dictionary = plist as? [String: Any] else {
            throw CommandError.invalidPropertyList
        }
        return dictionary
    }

    private static func stringValue(_ dictionary: [String: Any], key: String, default defaultValue: String = "") -> String {
        dictionary[key] as? String ?? defaultValue
    }

    private static func int64Value(_ dictionary: [String: Any], key: String, fallbackKeys: [String] = []) -> Int64 {
        let keys = [key] + fallbackKeys
        for candidate in keys {
            if let number = dictionary[candidate] as? NSNumber {
                return number.int64Value
            }
        }
        return 0
    }

    private static func boolValue(_ dictionary: [String: Any], key: String, fallbackKeys: [String] = []) -> Bool {
        let keys = [key] + fallbackKeys
        for candidate in keys {
            if let value = dictionary[candidate] as? Bool {
                return value
            }
            if let number = dictionary[candidate] as? NSNumber {
                return number.boolValue
            }
        }
        return false
    }
}
