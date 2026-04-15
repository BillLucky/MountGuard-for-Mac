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
