import AppKit
import SwiftUI

/// Settings window. Standard AppKit/SwiftUI controls only, so on macOS 26 it picks up
/// Liquid Glass automatically. The window sizes itself to fit the content.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    /// Builds the window off-screen so the first open is instant.
    func prepare() {
        guard window == nil else { return }
        makeWindow()
        window?.contentView?.layoutSubtreeIfNeeded()
    }

    func show() {
        makeWindow()
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView())
            host.sizingOptions = [.preferredContentSize]
            let w = NSWindow(contentViewController: host)
            w.title = "ClipGlyph"
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
        }
    }

    func windowWillClose(_ notification: Notification) { ShortcutRecorder.shared.stop() }
    func windowDidResignKey(_ notification: Notification) { ShortcutRecorder.shared.stop() }
}

struct SettingsView: View {
    @AppStorage(Settings.Key.notify) private var notify = false
    @AppStorage(Settings.Key.keepLineBreaks) private var keepLineBreaks = true
    @AppStorage(Settings.Key.automaticLanguage) private var automaticLanguage = true
    @AppStorage(Settings.Key.languages) private var languages = "en-US"
    @AppStorage(Settings.Key.detectCodes) private var detectCodes = false
    @AppStorage(Settings.Key.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(Settings.Key.shortcutKeyCode) private var shortcutKeyCode = Int(Shortcut.default.keyCode)
    @AppStorage(Settings.Key.shortcutModifiers) private var shortcutModifiers = Int(Shortcut.default.modifiers)
    @ObservedObject private var state = AppState.shared

    private let supported = OCR.supportedLanguages

    var body: some View {
        Form {
            Section {
                LabeledContent("Shortcut") { shortcutField }
                Toggle(isOn: $showMenuBarIcon) {
                    InfoLabel("Menu bar icon", help: "When hidden, open Settings by launching ClipGlyph again.")
                }
                Toggle(isOn: notifyBinding) {
                    InfoLabel("Notifications", help: "Show what happened after each run: text copied, no image, no text found, and so on.")
                }
            } footer: {
                if !state.hotKeyRegistered && !state.isRecording {
                    Text("This shortcut couldn't be registered. Try another one.")
                        .foregroundStyle(.red)
                } else if notify && state.notificationsDenied {
                    HStack(spacing: 4) {
                        Text("Notifications are off in System Settings.")
                        Button("Open") { Notifier.openSystemSettings() }.buttonStyle(.link)
                    }
                }
            }

            Section {
                Toggle(isOn: $keepLineBreaks) {
                    InfoLabel("Keep line breaks", help: "On: each line of text stays on its own line.\nOff: lines are joined into one paragraph with spaces.")
                }
                Toggle(isOn: $detectCodes) {
                    InfoLabel("Read QR codes & barcodes", help: "When the image contains a QR code or barcode, its contents are copied instead of the text.")
                }
                Toggle(isOn: $automaticLanguage) {
                    InfoLabel("Detect language", help: "Recognizes the language automatically. Turn off to choose specific languages.\nAll languages are built into macOS. Nothing is downloaded.")
                }
                if !automaticLanguage {
                    LabeledContent("Languages") { languageMenu }
                }
            } footer: {
                Text("Version \(Self.version)")
                    .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .toggleStyle(.switch)
        .controlSize(.small)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: refreshNotificationStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshNotificationStatus()
        }
    }

    // MARK: Shortcut

    private var shortcut: Shortcut {
        Shortcut(keyCode: UInt32(shortcutKeyCode), modifiers: UInt32(shortcutModifiers))
    }

    private var shortcutField: some View {
        HStack(spacing: 6) {
            if shortcut != .default && !state.isRecording {
                Button {
                    Settings.shortcut = .default
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Reset to \(Shortcut.default.displayString)")
            }
            Button {
                state.isRecording ? ShortcutRecorder.shared.stop() : ShortcutRecorder.shared.start()
            } label: {
                Text(state.isRecording ? "Type shortcut…" : shortcut.displayString)
                    .frame(minWidth: 80)
            }
            .help("Click, then press a new key combination using ⌘, ⌥ or ⌃. Esc cancels.")
        }
    }

    // MARK: Languages

    private var languageMenu: some View {
        Menu(languageSummary) {
            ForEach(supported, id: \.self) { code in
                Toggle(Self.name(code), isOn: binding(for: code))
            }
        }
        .fixedSize()
    }

    private var languageSummary: String {
        let selected = Settings.decode(languages)
        guard let first = selected.first else { return "None" }
        let name = Self.name(first)
        return selected.count == 1 ? name : "\(name) +\(selected.count - 1)"
    }

    private func binding(for code: String) -> Binding<Bool> {
        Binding(
            get: { Settings.decode(languages).contains(code) },
            set: { on in
                var list = Settings.decode(languages).filter { $0 != code }
                if on { list.append(code) }
                languages = Settings.encode(list)
            }
        )
    }

    // MARK: Notifications

    private var notifyBinding: Binding<Bool> {
        Binding(
            get: { notify },
            set: { on in
                notify = on
                if on { Notifier.requestPermission { _ in refreshNotificationStatus() } }
            }
        )
    }

    private func refreshNotificationStatus() {
        Notifier.checkDenied { AppState.shared.notificationsDenied = $0 }
    }

    // MARK: Helpers

    private static func name(_ code: String) -> String {
        Locale.current.localizedString(forIdentifier: code) ?? code
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

/// Which ⓘ popover is open (one at a time). Separate from AppState so opening one
/// only re-renders the info labels, not the whole form.
private final class InfoPopoverState: ObservableObject {
    static let shared = InfoPopoverState()
    @Published var openInfo: String?
}

/// A row title with an ⓘ: hover for a tooltip, click for a popover.
private struct InfoLabel: View {
    let title: String
    let help: String
    @ObservedObject private var state = InfoPopoverState.shared

    init(_ title: String, help: String) {
        self.title = title
        self.help = help
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Button {
                state.openInfo = state.openInfo == title ? nil : title
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
            .buttonStyle(.borderless)
            .help(help)
            .popover(isPresented: Binding(
                get: { state.openInfo == title },
                set: { if !$0 && state.openInfo == title { state.openInfo = nil } }
            ), arrowEdge: .bottom) {
                Text(help)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 240, alignment: .leading)
                    .padding(12)
            }
        }
    }
}
