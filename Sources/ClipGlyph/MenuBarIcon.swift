import AppKit

/// The menu bar glyph: an SF Symbol drawn at a fixed weight and size, centered on its
/// visible pixels rather than its padded bounding box, so it sits optically centered
/// and matches the stroke weight of system menu bar icons.
enum MenuBarIcon {
    static let image: NSImage = make(symbol: "text.viewfinder") ?? NSImage()

    private static let canvas = NSSize(width: 18, height: 18)
    private static let inkHeight: CGFloat = 15

    private static func make(symbol name: String) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: "ClipGlyph")?
                .withSymbolConfiguration(.init(pointSize: 15, weight: .semibold)),
              let ink = visibleBounds(of: symbol), ink.height > 0, ink.width > 0 else { return nil }

        let scale = min(inkHeight / ink.height, canvas.width / ink.width)
        let image = NSImage(size: canvas, flipped: false) { rect in
            let size = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
            let origin = NSPoint(x: rect.midX - (ink.midX * scale), y: rect.midY - (ink.midY * scale))
            symbol.draw(in: NSRect(origin: origin, size: size))
            return true
        }
        image.isTemplate = true   // follows light/dark menu bar and highlight state
        image.accessibilityDescription = "ClipGlyph"
        return image
    }

    /// Bounding box of non-transparent pixels, in the image's point space (origin bottom-left).
    private static func visibleBounds(of image: NSImage) -> NSRect? {
        let scale = 4
        let w = Int(ceil(image.size.width)) * scale, h = Int(ceil(image.size.height)) * scale
        guard w > 0, h > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: w * 4, bitsPerPixel: 32),
              let gc = NSGraphicsContext(bitmapImageRep: rep)
        else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gc
        image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.bitmapData else { return nil }

        var minX = w, minY = h, maxX = -1, maxY = -1
        for row in 0..<h {
            for col in 0..<w where data[(row * w + col) * 4 + 3] > 8 {   // alpha
                minX = min(minX, col); maxX = max(maxX, col)
                // Bitmap rows run top-down.
                let y = h - 1 - row
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let s = CGFloat(scale)
        return NSRect(x: CGFloat(minX) / s, y: CGFloat(minY) / s,
                      width: CGFloat(maxX - minX + 1) / s, height: CGFloat(maxY - minY + 1) / s)
    }
}
