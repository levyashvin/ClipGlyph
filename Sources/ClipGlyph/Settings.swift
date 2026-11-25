import Foundation

enum Settings {
    enum Key {
        static let notify = "notify"
        static let keepLineBreaks = "keepLineBreaks"
        static let automaticLanguage = "automaticLanguage"
        static let languages = "languages"
        static let detectCodes = "detectCodes"
        static let showMenuBarIcon = "showMenuBarIcon"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.notify: false,
            Key.keepLineBreaks: true,
            Key.automaticLanguage: true,
            Key.languages: "en-US",
            Key.detectCodes: false,
            Key.showMenuBarIcon: true,
        ])
    }

    private static var d: UserDefaults { .standard }
    static var notify: Bool { d.bool(forKey: Key.notify) }
    static var keepLineBreaks: Bool { d.bool(forKey: Key.keepLineBreaks) }
    static var detectCodes: Bool { d.bool(forKey: Key.detectCodes) }
    static var showMenuBarIcon: Bool { d.bool(forKey: Key.showMenuBarIcon) }
    static var languages: [String] { decode(d.string(forKey: Key.languages) ?? "") }
    /// Falls back to automatic when no language is selected.
    static var automaticLanguage: Bool { d.bool(forKey: Key.automaticLanguage) || languages.isEmpty }

    static func decode(_ s: String) -> [String] { s.split(separator: ",").map(String.init) }
    static func encode(_ a: [String]) -> String { a.joined(separator: ",") }
}
