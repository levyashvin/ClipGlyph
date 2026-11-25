import Foundation

enum Settings {
    enum Key {
        static let notify = "notify"
        static let keepLineBreaks = "keepLineBreaks"
        static let automaticLanguage = "automaticLanguage"
        static let languages = "languages"
        static let detectCodes = "detectCodes"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let shortcutKeyCode = "shortcutKeyCode"
        static let shortcutModifiers = "shortcutModifiers"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.notify: false,
            Key.keepLineBreaks: true,
            Key.automaticLanguage: true,
            Key.languages: "en-US",
            Key.detectCodes: false,
            Key.showMenuBarIcon: true,
            Key.shortcutKeyCode: Int(Shortcut.default.keyCode),
            Key.shortcutModifiers: Int(Shortcut.default.modifiers),
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

    static var shortcut: Shortcut {
        get { Shortcut(keyCode: UInt32(d.integer(forKey: Key.shortcutKeyCode)),
                       modifiers: UInt32(d.integer(forKey: Key.shortcutModifiers))) }
        set {
            d.set(Int(newValue.keyCode), forKey: Key.shortcutKeyCode)
            d.set(Int(newValue.modifiers), forKey: Key.shortcutModifiers)
        }
    }

    static var hasLaunchedBefore: Bool {
        get { d.bool(forKey: Key.hasLaunchedBefore) }
        set { d.set(newValue, forKey: Key.hasLaunchedBefore) }
    }

    /// Drops saved languages this macOS version no longer supports (Vision would reject the request).
    static func sanitize() {
        let supported = Set(OCR.supportedLanguages)
        let kept = languages.filter(supported.contains)
        if kept != languages { d.set(encode(kept), forKey: Key.languages) }
    }

    static func decode(_ s: String) -> [String] { s.split(separator: ",").map(String.init) }
    static func encode(_ a: [String]) -> String { a.joined(separator: ",") }
}
