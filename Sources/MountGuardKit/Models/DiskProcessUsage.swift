import Foundation

public struct DiskProcessUsage: Identifiable, Equatable, Sendable {
    public let pid: Int
    public let command: String
    public let user: String
    public let filePaths: [String]

    public init(pid: Int, command: String, user: String, filePaths: [String]) {
        self.pid = pid
        self.command = command
        self.user = user
        self.filePaths = filePaths
    }

    public var id: String {
        "\(pid)-\(command)"
    }

    public var summary: String {
        "\(command) (PID: \(pid))"
    }
}
