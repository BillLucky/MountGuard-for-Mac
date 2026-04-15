import Foundation

public enum DiskDoctorStatus: String, Sendable {
    case healthy
    case warning
    case blocked
}

public struct DiskDoctorIssue: Identifiable, Sendable, Equatable {
    public let id: String
    public let status: DiskDoctorStatus
    public let title: String
    public let detail: String
    public let recommendation: String?

    public init(
        id: String,
        status: DiskDoctorStatus,
        title: String,
        detail: String,
        recommendation: String? = nil
    ) {
        self.id = id
        self.status = status
        self.title = title
        self.detail = detail
        self.recommendation = recommendation
    }
}

public struct DiskDoctorRepairStep: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let detail: String
    public let isAutomatic: Bool

    public init(
        id: String,
        title: String,
        detail: String,
        isAutomatic: Bool
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isAutomatic = isAutomatic
    }
}

public struct DiskDoctorRepairPlan: Sendable, Equatable {
    public let title: String
    public let summary: String
    public let warning: String
    public let canRunOnMac: Bool
    public let actionTitle: String?
    public let steps: [DiskDoctorRepairStep]

    public init(
        title: String,
        summary: String,
        warning: String,
        canRunOnMac: Bool,
        actionTitle: String? = nil,
        steps: [DiskDoctorRepairStep]
    ) {
        self.title = title
        self.summary = summary
        self.warning = warning
        self.canRunOnMac = canRunOnMac
        self.actionTitle = actionTitle
        self.steps = steps
    }
}

public struct DiskDoctorReport: Sendable, Equatable {
    public let volumeID: String
    public let status: DiskDoctorStatus
    public let summary: String
    public let generatedAt: Date
    public let issues: [DiskDoctorIssue]
    public let repairPlan: DiskDoctorRepairPlan?

    public init(
        volumeID: String,
        status: DiskDoctorStatus,
        summary: String,
        generatedAt: Date = Date(),
        issues: [DiskDoctorIssue],
        repairPlan: DiskDoctorRepairPlan? = nil
    ) {
        self.volumeID = volumeID
        self.status = status
        self.summary = summary
        self.generatedAt = generatedAt
        self.issues = issues
        self.repairPlan = repairPlan
    }
}
