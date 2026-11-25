# ClipGlyph

Clipboard OCR for macOS. **No Screen Recording permission, no admin password.** Built for managed Macs.

Take a screenshot to the clipboard, press **⌃⌥⌘O**, paste text.

## Install

```sh
brew install levyashvin/tap/clipglyph
brew services start clipglyph
```

## Use

1. Copy a screenshot to the clipboard: **⌃⌘⇧4** (or any copied image)
2. Press **⌃⌥⌘O**
3. Paste

Settings are in the menu bar icon: shortcut, line breaks, QR codes, languages, notifications.

## Why

Most OCR tools capture the screen themselves, which needs Screen Recording permission, often blocked on managed Macs. ClipGlyph uses the screenshot macOS already took, so it needs no special permissions. OCR runs on-device with Apple Vision. Nothing leaves your Mac.

## Stop / uninstall

```sh
brew services stop clipglyph
brew uninstall clipglyph
```

## License

MIT
