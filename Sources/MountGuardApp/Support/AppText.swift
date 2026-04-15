import Foundation

enum AppText {
    static func current(_ chinese: String, _ english: String) -> String {
        if Locale.preferredLanguages.first?.hasPrefix("zh") == true {
            return chinese
        }
        return english
    }
}
