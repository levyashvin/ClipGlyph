import CoreGraphics
import Vision

/// Local OCR and barcode reading with Apple's Vision framework. Nothing leaves the Mac.
enum OCR {
    struct Options {
        var keepLineBreaks: Bool
        var languages: [String]   // empty = automatic detection
        var detectCodes: Bool

        static var current: Options {
            Options(keepLineBreaks: Settings.keepLineBreaks,
                    languages: Settings.automaticLanguage ? [] : Settings.languages,
                    detectCodes: Settings.detectCodes)
        }
    }

    enum Result {
        case text(String)
        case codes(String)
        case empty
        case failed(String)
    }

    static func recognize(_ image: CGImage, options: Options) -> Result {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        if options.languages.isEmpty {
            textRequest.automaticallyDetectsLanguage = true
        } else {
            textRequest.recognitionLanguages = options.languages
        }

        let codeRequest = VNDetectBarcodesRequest()
        let requests: [VNRequest] = options.detectCodes ? [codeRequest, textRequest] : [textRequest]

        do {
            try handler.perform(requests)
        } catch {
            return .failed(error.localizedDescription)
        }

        // A QR code / barcode wins: its payload is almost always what you want.
        if options.detectCodes {
            let payloads = (codeRequest.results ?? []).compactMap(\.payloadStringValue)
            var seen = Set<String>()
            let unique = payloads.filter { seen.insert($0).inserted }
            if !unique.isEmpty { return .codes(unique.joined(separator: "\n")) }
        }

        let lines = (textRequest.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let text = lines.joined(separator: options.keepLineBreaks ? "\n" : " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? .empty : .text(text)
    }

    /// Languages supported by the built-in, on-device model (no downloads).
    static var supportedLanguages: [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return (try? request.supportedRecognitionLanguages()) ?? ["en-US"]
    }
}
