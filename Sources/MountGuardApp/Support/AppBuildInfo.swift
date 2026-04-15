import Foundation

enum AppBuildInfo {
    static var versionText: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let buildDate = bundle.object(forInfoDictionaryKey: "MountGuardBuildDate") as? String ?? "unknown-date"
        let commit = bundle.object(forInfoDictionaryKey: "MountGuardGitCommit") as? String ?? "unknown"
        return "v\(version) • \(buildDate) • \(commit)"
    }
}
