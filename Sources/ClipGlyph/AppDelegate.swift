import AppKit
import os

let log = Logger(subsystem: "io.github.levyashvin.clipglyph", category: "main")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem?
    private var hotKeyWarningItem: NSMenuItem?
    private let settingsWindow = SettingsWindowController()
    private var busy = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Only one copy: a second launch hands off to the running one (which opens Settings).
        let me = NSRunningApplication.current
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .first(where: { $0 != me }) {
            log.info("Already running (pid \(other.processIdentifier, privacy: .public)); exiting")
            NSWorkspace.shared.openApplication(at: other.bundleURL ?? Bundle.main.bundleURL,
                                               configuration: NSWorkspace.OpenConfiguration())
            exit(0)
        }

        Settings.registerDefaults()
        Settings.sanitize()
        Notifier.setUp()
        NSApp.mainMenu = Self.makeMenu()
        hotKey = HotKey { [weak self] in self?.runOCR() }
        AppState.shared.hotKeyRegistered = hotKey?.isRegistered ?? false
        setUpStatusItem()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) {
            [weak self] _ in self?.statusItem?.isVisible = Settings.showMenuBarIcon
        }

        if !Settings.hasLaunchedBefore || !AppState.shared.hotKeyRegistered {
            Settings.hasLaunchedBefore = true
            settingsWindow.show()
        }
    }

    /// Launching the app again (Finder, `open`, a second instance) opens Settings.
    /// This is the way back in when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return false
    }

    // MARK: Menu bar icon

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "ClipGlyph")
        let menu = NSMenu()
        if !AppState.shared.hotKeyRegistered {
            let warn = NSMenuItem(title: "Shortcut ⌃⌥⌘O isn't available", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
            menu.addItem(.separator())
        }
        let ocr = NSMenuItem(title: "Read Clipboard Image", action: #selector(menuOCR), keyEquivalent: "o")
        ocr.keyEquivalentModifierMask = [.control, .option, .command]
        ocr.target = self
        menu.addItem(ocr)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(menuSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(withTitle: "Quit ClipGlyph", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        item.isVisible = Settings.showMenuBarIcon
        statusItem = item
    }

    @objc private func menuOCR() { runOCR() }
    @objc private func menuSettings() { settingsWindow.show() }

    // MARK: OCR flow

    private func runOCR() {
        guard !busy else { return }
        let pb = NSPasteboard.general
        let changeCount = pb.changeCount
        guard let image = ClipboardImage.read(from: pb) else {
            log.info("Clipboard has no image")
            Notifier.post("No image on the clipboard", body: "Copy a screenshot first, then press ⌃⌥⌘O.")
            return
        }
        busy = true
        let options = OCR.Options.current
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = autoreleasepool { OCR.recognize(image, options: options) }
            DispatchQueue.main.async { self?.finish(result, changeCount: changeCount) }
        }
    }

    private func finish(_ result: OCR.Result, changeCount: Int) {
        defer { busy = false }
        let pb = NSPasteboard.general
        switch result {
        case .failed(let message):
            log.error("OCR failed: \(message, privacy: .public)")
            Notifier.post("OCR failed", body: message)
        case .empty:
            log.info("No text found")
            Notifier.post("No text found", body: "The image was left on the clipboard.")
        case .text(let text), .codes(let text):
            guard pb.changeCount == changeCount else {
                log.info("Clipboard changed during OCR; not overwriting")
                Notifier.post("Clipboard changed", body: "You copied something else while OCR was running, so it was left alone.")
                return
            }
            pb.clearContents()
            guard pb.setString(text, forType: .string) else {
                log.error("Failed to write text to the clipboard")
                Notifier.post("Couldn't write to the clipboard", body: "Try again.")
                return
            }
            if case .codes = result {
                Notifier.post("Copied QR/barcode contents", body: text)
            } else {
                Notifier.post("Copied text", body: text)
            }
        }
    }

    // Minimal menu so Cmd-W / Cmd-Q work while Settings is focused.
    private static func makeMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit ClipGlyph", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu
        main.addItem(fileItem)
        return main
    }
}

/// Runtime state shown in Settings.
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var hotKeyRegistered = true
    @Published var notificationsDenied = false
}
