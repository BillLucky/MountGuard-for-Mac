import Foundation

public struct DiskVolume: Codable, Equatable, Identifiable, Sendable {
    public let deviceIdentifier: String
    public let deviceNode: String
    public let wholeDiskIdentifier: String
    public let diskUUID: String?
    public let volumeName: String
    public let mountPoint: String?
    public let fileSystemName: String
    public let fileSystemType: String
    public let busProtocol: String
    public let contentDescription: String
    public let totalBytes: Int64
    public let freeBytes: Int64
    public let isMounted: Bool
    public let isWritable: Bool
    public let isExternal: Bool
    public let isEjectable: Bool
    public let isBootable: Bool
    public let smartStatus: String

    public init(
        deviceIdentifier: String,
        deviceNode: String,
        wholeDiskIdentifier: String,
        diskUUID: String?,
        volumeName: String,
        mountPoint: String?,
        fileSystemName: String,
        fileSystemType: String,
        busProtocol: String,
        contentDescription: String,
        totalBytes: Int64,
        freeBytes: Int64,
        isMounted: Bool,
        isWritable: Bool,
        isExternal: Bool,
        isEjectable: Bool,
        isBootable: Bool,
        smartStatus: String
    ) {
        self.deviceIdentifier = deviceIdentifier
        self.deviceNode = deviceNode
        self.wholeDiskIdentifier = wholeDiskIdentifier
        self.diskUUID = diskUUID
        self.volumeName = volumeName
        self.mountPoint = mountPoint
        self.fileSystemName = fileSystemName
        self.fileSystemType = fileSystemType
        self.busProtocol = busProtocol
        self.contentDescription = contentDescription
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.isMounted = isMounted
        self.isWritable = isWritable
        self.isExternal = isExternal
        self.isEjectable = isEjectable
        self.isBootable = isBootable
        self.smartStatus = smartStatus
    }

    public var id: String {
        deviceIdentifier
    }

    public var usedBytes: Int64 {
        max(totalBytes - freeBytes, 0)
    }

    public var usageFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    public var displayName: String {
        volumeName.isEmpty ? deviceIdentifier : volumeName
    }

    public var mountStatusText: String {
        isMounted ? "已挂载" : "未挂载"
    }

    public var writeStatusText: String {
        isWritable ? "可写" : "只读"
    }

    public func resolved(
        mountPoint: String?,
        isMounted: Bool,
        isWritable: Bool? = nil
    ) -> DiskVolume {
        DiskVolume(
            deviceIdentifier: deviceIdentifier,
            deviceNode: deviceNode,
            wholeDiskIdentifier: wholeDiskIdentifier,
            diskUUID: diskUUID,
            volumeName: volumeName,
            mountPoint: mountPoint,
            fileSystemName: fileSystemName,
            fileSystemType: fileSystemType,
            busProtocol: busProtocol,
            contentDescription: contentDescription,
            totalBytes: totalBytes,
            freeBytes: freeBytes,
            isMounted: isMounted,
            isWritable: isWritable ?? self.isWritable,
            isExternal: isExternal,
            isEjectable: isEjectable,
            isBootable: isBootable,
            smartStatus: smartStatus
        )
    }
}
