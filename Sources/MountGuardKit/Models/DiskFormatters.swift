import Foundation

public enum DiskFormatters {
    public static func bytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: value)
    }

    public static func capacitySummary(for volume: DiskVolume) -> String {
        MountGuardLocalized.text(
            "已用 \(bytes(volume.usedBytes)) / 总计 \(bytes(volume.totalBytes))",
            "Used \(bytes(volume.usedBytes)) / Total \(bytes(volume.totalBytes))"
        )
    }
}
