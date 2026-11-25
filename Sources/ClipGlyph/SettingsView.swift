import AppKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "ClipGlyph Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @AppStorage(Settings.Key.notify) private var notify = false
    @AppStorage(Settings.Key.keepLineBreaks) private var keepLineBreaks = true
    @AppStorage(Settings.Key.automaticLanguage) private var automaticLanguage = true
    @AppStorage(Settings.Key.languages) private var languages = "en-US"
    @AppStorage(Settings.Key.detectCodes) private var detectCodes = false
    @AppStorage(Settings.Key.showMenuBarIcon) private var showMenuBarIcon = true

    private let supported = OCR.supportedLanguages

    var body: some View {
        Form {
            Section {
                LabeledContent("Read clipboard image", value: "⌃⌥⌘O")
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                if !showMenuBarIcon {
                    Text("To reopen Settings, launch ClipGlyph again.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: { Text("General") }

            Section {
                Picker("Line breaks", selection: $keepLineBreaks) {
                    Text("Keep line breaks").tag(true)
                    Text("Join into one paragraph").tag(false)
                }
                Toggle("Read QR codes and barcodes", isOn: $detectCodes)
                Text("When a code is found, its contents are copied instead of the text.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text("Output") }

            Section {
                Toggle("Detect language automatically", isOn: $automaticLanguage)
                if !automaticLanguage {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(supported, id: \.self) { code in
                                Toggle(Self.name(code), isOn: binding(for: code))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 160)
                }
                Text("All languages are built into macOS. Nothing is downloaded.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text("Languages") }

            Section {
                Toggle("Show a notification after each run", isOn: $notify)
                    .onChange(of: notify) { on in if on { Notifier.requestPermission() } }
            } header: { Text("Notifications") }

            Section {
                HStack {
                    Text("Version \(Self.version)").foregroundStyle(.secondary)
                    Spacer()
                    Button("Quit ClipGlyph") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
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
