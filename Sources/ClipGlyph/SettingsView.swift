import AppKit
import SwiftUI

/// Settings window. Uses only standard AppKit/SwiftUI controls, so on macOS 26 it
/// automatically picks up Liquid Glass styling; on older macOS it looks native too.
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView())
            let w = NSWindow(contentViewController: host)
            w.title = "ClipGlyph Settings"
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.setContentSize(NSSize(width: SettingsView.width, height: SettingsView.height))
            w.isReleasedWhenClosed = false
            w.setFrameAutosaveName("ClipGlyphSettings")
            if !w.setFrameUsingName("ClipGlyphSettings") { w.center() }
            window = w
        }
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    static let width: CGFloat = 460
    static let height: CGFloat = 560

    @AppStorage(Settings.Key.notify) private var notify = false
    @AppStorage(Settings.Key.keepLineBreaks) private var keepLineBreaks = true
    @AppStorage(Settings.Key.automaticLanguage) private var automaticLanguage = true
    @AppStorage(Settings.Key.languages) private var languages = "en-US"
    @AppStorage(Settings.Key.detectCodes) private var detectCodes = false
    @AppStorage(Settings.Key.showMenuBarIcon) private var showMenuBarIcon = true

    @ObservedObject private var state = AppState.shared

    private let supported = OCR.supportedLanguages

    var body: some View {
        Form {
            if !state.hotKeyRegistered {
                Section {
                    Label("macOS wouldn't register ⌃⌥⌘O, so the shortcut isn't active. "
                          + "Quit and reopen ClipGlyph to try again. "
                          + "Read Clipboard Image in the menu bar icon still works.",
                          systemImage: "exclamationmark.triangle")
                }
            }

            Section {
                LabeledContent("Read clipboard image", value: "⌃⌥⌘O")
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
            } header: {
                Text("General")
            } footer: {
                if !showMenuBarIcon {
                    Text("To reopen Settings, launch ClipGlyph again.")
                }
            }

            Section {
                Picker("Line breaks", selection: $keepLineBreaks) {
                    Text("Keep").tag(true)
                    Text("Join into one paragraph").tag(false)
                }
                Toggle("Read QR codes and barcodes", isOn: $detectCodes)
            } header: {
                Text("Output")
            } footer: {
                Text("When a code is found, its contents are copied instead of the text.")
            }

            Section {
                Toggle("Detect automatically", isOn: $automaticLanguage)
                if !automaticLanguage {
                    ForEach(supported, id: \.self) { code in
                        Toggle(Self.name(code), isOn: binding(for: code))
                            .toggleStyle(.checkbox)
                    }
                }
            } header: {
                Text("Languages")
            } footer: {
                Text("All languages are built into macOS. Nothing is downloaded.")
            }

            Section {
                Toggle("Show a notification after each run", isOn: Binding(
                    get: { notify },
                    set: { on in
                        notify = on
                        if on { Notifier.requestPermission { _ in refreshNotificationStatus() } }
                    }
                ))
            } header: {
                Text("Notifications")
            } footer: {
                if notify && state.notificationsDenied {
                    HStack {
                        Text("Notifications are turned off for ClipGlyph in System Settings.")
                        Button("Open System Settings") { Notifier.openSystemSettings() }
                            .buttonStyle(.link)
                    }
                }
            }

            Section {
                LabeledContent("Version", value: Self.version)
                Button("Quit ClipGlyph", role: .destructive) { NSApp.terminate(nil) }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshNotificationStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshNotificationStatus()
        }
        .toggleStyle(.switch)
        .frame(width: Self.width)
        .frame(minHeight: 300, idealHeight: Self.height)
    }

    private func refreshNotificationStatus() {
        Notifier.checkDenied { AppState.shared.notificationsDenied = $0 }
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

    private static func name(_ code: String) -> String {
        Locale.current.localizedString(forIdentifier: code) ?? code
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
