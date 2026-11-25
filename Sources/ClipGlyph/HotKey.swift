import Carbon.HIToolbox

/// The global OCR hotkey, via Carbon. No Accessibility or Input Monitoring permission needed.
final class HotKey {
    private let onPress: () -> Void
    private var ref: EventHotKeyRef?
    private(set) var isRegistered = false

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { me.onPress() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
        if status != noErr {
            log.error("InstallEventHandler failed: \(status, privacy: .public)")
        }
    }

    /// Replaces any existing registration. Pass nil to unregister.
    func register(_ shortcut: Shortcut?) {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        isRegistered = false
        guard let shortcut else { return }
        let id = EventHotKeyID(signature: OSType(0x434C_4759) /* 'CLGY' */, id: 1)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &ref)
        isRegistered = status == noErr
        if isRegistered {
            log.info("Registered hotkey \(shortcut.displayString, privacy: .public)")
        } else {
            log.error("Failed to register hotkey \(shortcut.displayString, privacy: .public): \(status, privacy: .public)")
        }
    }
}
