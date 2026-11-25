import Carbon.HIToolbox

/// Global hotkeys via Carbon. No Accessibility or Input Monitoring permission needed.
///   Control-Option-Command-O     → OCR the clipboard image
///   Control-Option-Command-,     → open Settings
final class HotKeys {
    private let onOCR: () -> Void
    private let onSettings: () -> Void
    private var refs: [EventHotKeyRef?] = []

    init(onOCR: @escaping () -> Void, onSettings: @escaping () -> Void) {
        self.onOCR = onOCR
        self.onSettings = onSettings

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let me = Unmanaged<HotKeys>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { id.id == 1 ? me.onOCR() : me.onSettings() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
        guard status == noErr else {
            log.error("InstallEventHandler failed: \(status, privacy: .public)")
            return
        }
        register(id: 1, key: kVK_ANSI_O, name: "Control-Option-Command-O")
        register(id: 2, key: kVK_ANSI_Comma, name: "Control-Option-Command-,")
    }

    private func register(id: UInt32, key: Int, name: String) {
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x434C_4759) /* 'CLGY' */, id: id)
        let mods = UInt32(controlKey | optionKey | cmdKey)
        let status = RegisterEventHotKey(UInt32(key), mods, hkID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            refs.append(ref)
            log.info("Registered hotkey \(name, privacy: .public)")
        } else {
            log.error("Failed to register hotkey \(name, privacy: .public): \(status, privacy: .public)")
        }
    }
}
