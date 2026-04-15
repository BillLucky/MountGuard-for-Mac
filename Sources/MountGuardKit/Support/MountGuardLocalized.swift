import Foundation

public enum MountGuardLanguage: String, Sendable {
    case english = "en"
    case chinese = "zh-Hans"
}

public enum MountGuardLocalized {
    private static let storageKey = "app.language"

    public static var currentLanguage: MountGuardLanguage {
        if let rawValue = UserDefaults.standard.string(forKey: storageKey),
           let language = MountGuardLanguage(rawValue: rawValue) {
            return language
        }
        return .english
    }

    public static func text(_ chinese: String, _ english: String) -> String {
        currentLanguage == .chinese ? chinese : english
    }
}
