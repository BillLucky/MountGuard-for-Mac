import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }
}

enum AppText {
    private static let storageKey = "app.language"

    static var currentLanguage: AppLanguage {
        let stored = UserDefaults.standard.string(forKey: storageKey) ?? AppLanguage.english.rawValue
        return AppLanguage(rawValue: stored) ?? .english
    }

    static func setLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
    }

    static func current(_ chinese: String, _ english: String, language: AppLanguage? = nil) -> String {
        let resolvedLanguage = language ?? currentLanguage
        if resolvedLanguage == .chinese {
            return chinese
        }
        return english
    }
}
