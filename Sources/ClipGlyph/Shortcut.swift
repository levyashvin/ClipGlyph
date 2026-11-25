import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut in Carbon terms (virtual key code + Carbon modifier mask).
struct Shortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = Shortcut(keyCode: UInt32(kVK_ANSI_O), modifiers: UInt32(controlKey | optionKey | cmdKey))

    /// Builds a shortcut from a key press. Requires ⌘, ⌥ or ⌃ so plain typing can't become global.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.intersection([.command, .option, .control]).isEmpty else { return nil }
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        self.init(keyCode: UInt32(event.keyCode), modifiers: m)
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + keyName
    }

    /// Menu-item form, for showing the shortcut next to "Read Clipboard Image".
    var menuKeyEquivalent: (String, NSEvent.ModifierFlags) {
        var f: NSEvent.ModifierFlags = []
        if modifiers & UInt32(cmdKey) != 0 { f.insert(.command) }
        if modifiers & UInt32(optionKey) != 0 { f.insert(.option) }
        if modifiers & UInt32(controlKey) != 0 { f.insert(.control) }
        if modifiers & UInt32(shiftKey) != 0 { f.insert(.shift) }
        let key = Self.special[Int(keyCode)]?.menu ?? keyName.lowercased()
        return (key, f)
    }

    private var keyName: String {
        if let s = Self.special[Int(keyCode)] { return s.label }
        return Self.character(for: keyCode)?.uppercased() ?? "#\(keyCode)"
    }

    private static let special: [Int: (label: String, menu: String)] = {
        func ch(_ c: Int) -> String { String(UnicodeScalar(UInt16(c)).map(Character.init) ?? " ") }
        var m: [Int: (String, String)] = [
            kVK_Return: ("↩", "\r"), kVK_Tab: ("⇥", "\t"), kVK_Space: ("Space", " "),
            kVK_Delete: ("⌫", ch(NSBackspaceCharacter)), kVK_ForwardDelete: ("⌦", ch(NSDeleteFunctionKey)),
            kVK_Escape: ("⎋", "\u{1b}"),
            kVK_LeftArrow: ("←", ch(NSLeftArrowFunctionKey)), kVK_RightArrow: ("→", ch(NSRightArrowFunctionKey)),
            kVK_UpArrow: ("↑", ch(NSUpArrowFunctionKey)), kVK_DownArrow: ("↓", ch(NSDownArrowFunctionKey)),
            kVK_Home: ("↖", ch(NSHomeFunctionKey)), kVK_End: ("↘", ch(NSEndFunctionKey)),
            kVK_PageUp: ("⇞", ch(NSPageUpFunctionKey)), kVK_PageDown: ("⇟", ch(NSPageDownFunctionKey)),
        ]
        let fKeys = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
                     kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]
        for (i, k) in fKeys.enumerated() { m[k] = ("F\(i + 1)", ch(NSF1FunctionKey + i)) }
        return m
    }()

    /// The character this key produces on the current keyboard layout (no modifiers).
    private static func character(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        return data.withUnsafeBytes { raw -> String? in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var dead: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                        UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                        &dead, chars.count, &length, &chars)
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: length)
        }
    }
}

/// Captures the next key combination typed while Settings is focused.
final class ShortcutRecorder {
    static let shared = ShortcutRecorder()
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        AppState.shared.isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == UInt16(kVK_Escape) && event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
                self.stop()
            } else if let shortcut = Shortcut(event: event) {
                Settings.shortcut = shortcut
                self.stop()
            } else {
                NSSound.beep()   // needs ⌘, ⌥ or ⌃
            }
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        AppState.shared.isRecording = false
    }
}
