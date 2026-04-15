import Foundation

public enum DiskIOTestStatus: String, Codable, Sendable {
    case passed
    case skipped
    case failed
}

public struct DiskIOTestStepResult: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let status: DiskIOTestStatus
    public let detail: String

    public init(id: UUID = UUID(), name: String, status: DiskIOTestStatus, detail: String) {
        self.id = id
        self.name = name
        self.status = status
        self.detail = detail
    }
}

public struct DiskIOTestReport: Codable, Equatable, Sendable {
    public let volumeIdentifier: String
    public let volumeName: String
    public let workspacePath: String?
    public let status: DiskIOTestStatus
    public let startedAt: Date
    public let finishedAt: Date
    public let steps: [DiskIOTestStepResult]

    public init(
        volumeIdentifier: String,
        volumeName: String,
        workspacePath: String?,
        status: DiskIOTestStatus,
        startedAt: Date,
        finishedAt: Date,
        steps: [DiskIOTestStepResult]
    ) {
        self.volumeIdentifier = volumeIdentifier
        self.volumeName = volumeName
        self.workspacePath = workspacePath
        self.status = status
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.steps = steps
    }
}
