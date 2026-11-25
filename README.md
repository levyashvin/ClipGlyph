# ClipGlyph

**Clipboard OCR for macOS that needs no Screen Recording permission and no admin password.**

It's built for managed and MDM-controlled Macs. You take screenshots with the macOS screenshot tool you already use. ClipGlyph only reads the image on your clipboard and replaces it with the text in it. Because it never captures the screen, it doesn't need the permissions your IT team may have locked down.

```
⌘⇧4 (screenshot to clipboard)  →  ⌃⌥⌘O  →  ⌘V  (pastes text)
```

## Features

- **No special permissions.** No Screen Recording, Accessibility, Input Monitoring or admin prompt.
- **Fully on-device.** Uses Apple's Vision framework. Nothing is uploaded and no models are downloaded.
- **Stays out of the way.** No Dock icon. A small menu-bar icon gives you Settings, and you can hide it.
- **Won't overwrite your clipboard by mistake.** If there's no text, or you copy something else while OCR is running, your clipboard is left alone.
- **Optional:** QR code and barcode reading, language choice (about 30 languages built into macOS), keep or join line breaks, and notifications describing what happened.

## Install

### Homebrew (recommended)

```sh
brew install levyashvin/tap/clipglyph
brew services start clipglyph     # start now and at every login
```

This is a formula rather than a cask on purpose. Homebrew builds ClipGlyph from source on your Mac, so Gatekeeper never blocks it and you never need to click **Open Anyway**, which often needs an admin password on managed Macs.

### From source

Requires the Xcode Command Line Tools.

```sh
git clone https://github.com/levyashvin/ClipGlyph.git
cd ClipGlyph
make install          # installs to ~/Applications and starts at login
```

## Usage

1. Copy a screenshot to the clipboard:
   - **⌃⌘⇧4** always copies to the clipboard.
   - Or set **⌘⇧5 → Options → Save to → Clipboard** so that plain **⌘⇧4** copies to the clipboard too.
   - Any copied image works as well.
2. Press **⌃⌥⌘O**.
3. Paste.

The menu-bar icon (a magnifier over text) has **Read Clipboard Image**, **Settings…** and **Quit**.

If you hide the icon, open Settings by launching ClipGlyph again:

```sh
open "$(brew --prefix)/opt/clipglyph/ClipGlyph.app"   # Homebrew
open ~/Applications/ClipGlyph.app                     # from source
```

## Settings

| Setting | Default |
| --- | --- |
| Show menu bar icon | On |
| Line breaks: keep / join into one paragraph | Keep |
| Read QR codes & barcodes (the code's contents are copied instead of the text) | Off |
| Language: automatic, or choose specific languages | Automatic |
| Notification after each run (copied / no image / no text / clipboard changed) | Off |

Turning on notifications triggers macOS's standard "Allow notifications" prompt. No admin is needed.

## Why not just use a screenshot-OCR app?

Most OCR tools capture the screen themselves, which requires **Screen Recording** permission. On managed Macs that permission is often blocked by MDM or needs an admin password. ClipGlyph leaves the capturing to macOS's built-in screenshot tool, which already works, and only does the OCR.

## Uninstall

```sh
brew services stop clipglyph && brew uninstall clipglyph
# or, if installed from source:
make uninstall
```

## Troubleshooting

Logs are local only:

```sh
log stream --predicate 'subsystem == "io.github.levyashvin.clipglyph"' --info
```

If the shortcut does nothing, check the log for `Failed to register hotkey`. That means another app already uses ⌃⌥⌘O.

## License

MIT
