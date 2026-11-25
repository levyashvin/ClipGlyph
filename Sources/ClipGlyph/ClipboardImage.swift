import AppKit
import ImageIO

enum ClipboardImage {
    /// Reads the clipboard image at full pixel resolution.
    /// (NSImage.cgImage(forProposedRect: nil, …) can return a downscaled 1x image of a Retina screenshot.)
    static func read(from pb: NSPasteboard) -> CGImage? {
        // Copied image files (Finder). Checked first: Finder also puts the file's icon on the clipboard as TIFF.
        if let url = (pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL])?.first,
           let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return image
        }
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pb.data(forType: type), let image = decode(data) { return image }
        }
        if let image = NSImage(pasteboard: pb) {
            var rect = CGRect(origin: .zero, size: largestPixelSize(of: image))
            return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        return nil
    }

    private static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func largestPixelSize(of image: NSImage) -> CGSize {
        let best = image.representations.max { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }
        guard let best, best.pixelsWide > 0 else { return image.size }
        return CGSize(width: best.pixelsWide, height: best.pixelsHigh)
    }
}
