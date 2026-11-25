import Carbon.HIToolbox

/// Global hotkey (Control-Option-Command-O) via Carbon.
/// No Accessibility or Input Monitoring permission needed.
final class HotKey {
    private let onPress: () -> Void
    private var ref: EventHotKeyRef?

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { me.onPress() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
        guard status == noErr else {
            log.error("InstallEventHandler failed: \(status, privacy: .public)")
            return
        }
        let id = EventHotKeyID(signature: OSType(0x434C_4759) /* 'CLGY' */, id: 1)
        let mods = UInt32(controlKey | optionKey | cmdKey)
        let reg = RegisterEventHotKey(UInt32(kVK_ANSI_O), mods, id, GetApplicationEventTarget(), 0, &ref)
        if reg == noErr {
            log.info("Registered hotkey Control-Option-Command-O")
        } else {
            log.error("Failed to register hotkey Control-Option-Command-O: \(reg, privacy: .public)")
        }
    }
}
