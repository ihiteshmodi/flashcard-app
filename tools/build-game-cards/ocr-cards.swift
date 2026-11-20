// Reads card text out of a print-and-play PDF whose text was converted to shapes, using on-device OCR.
// Usage: swift ocr-cards.swift <pdf> > raw.json
//
// Every page is cut into the 4 x 5 grid of cards. A cell is a card when its footer names the game.
// Black cards (dark cells) are read with their drawn blanks put back as "_____": a blank is a long horizontal
// line of ink, found in the pixels, and placed between the OCR words by position.
// Output: {"black": [{"lines": [...], "pick": 2, "page": 3, "cell": 7, "flags": [...]}], "white": [...]}
import CoreGraphics
import Foundation
import PDFKit
import Vision

let arguments = CommandLine.arguments
guard arguments.count == 2, let document = PDFDocument(url: URL(fileURLWithPath: arguments[1])) else {
    FileHandle.standardError.write(Data("usage: ocr-cards.swift <pdf>\n".utf8))
    exit(2)
}

let scale = 4.0
let originX = 18.3, originY = 18.3, cellWidth = 143.9, cellHeight = 145.5
let footerStart = 0.82

struct Word { var text: String; var minX: Double; var maxX: Double; var minY: Double; var maxY: Double }
struct Blank { var minX: Double; var maxX: Double; var y: Double; var top: Int; var bottom: Int; var punctuation = "" }

func renderPage(_ page: PDFPage) -> (pixels: [UInt8], width: Int, height: Int) {
    let width = Int(612 * scale), height = Int(792 * scale)
    var pixels = [UInt8](repeating: 255, count: width * height)
    pixels.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
    }
    return (pixels, width, height)
}

func crop(_ pixels: [UInt8], pageWidth: Int, x: Int, y: Int, width: Int, height: Int, invert: Bool) -> [UInt8] {
    var cell = [UInt8](repeating: 0, count: width * height)
    for row in 0..<height {
        let source = (y + row) * pageWidth + x
        for column in 0..<width {
            let value = pixels[source + column]
            cell[row * width + column] = invert ? 255 - value : value
        }
    }
    return cell
}

func image(_ gray: [UInt8], width: Int, height: Int) -> CGImage {
    let provider = CGDataProvider(data: Data(gray) as CFData)!
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                   space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0), provider: provider,
                   decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}

/// Words with boxes in top-left pixel coordinates of the cell.
func recognise(_ gray: [UInt8], width: Int, height: Int, correction: Bool) -> [Word] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = correction
    request.recognitionLanguages = ["en-US"]
    let handler = VNImageRequestHandler(cgImage: image(gray, width: width, height: height))
    try? handler.perform([request])
    var words: [Word] = []
    for observation in request.results ?? [] {
        guard let candidate = observation.topCandidates(1).first else { continue }
        let text = candidate.string
        var start = text.startIndex
        while start < text.endIndex {
            while start < text.endIndex, text[start] == " " { start = text.index(after: start) }
            var end = start
            while end < text.endIndex, text[end] != " " { end = text.index(after: end) }
            if start < end, let box = try? candidate.boundingBox(for: start..<end)?.boundingBox {
                words.append(Word(text: String(text[start..<end]),
                                  minX: box.minX * Double(width), maxX: box.maxX * Double(width),
                                  minY: (1 - box.maxY) * Double(height), maxY: (1 - box.minY) * Double(height)))
            }
            start = end
        }
    }
    return words
}

/// Long horizontal runs of ink above the footer are blanks.
func findBlanks(_ gray: [UInt8], width: Int, height: Int) -> [Blank] {
    let minimumRun = Int(Double(width) * 0.13)
    let limit = Int(Double(height) * footerStart)
    var open: [(minX: Int, maxX: Int, firstRow: Int, lastRow: Int)] = []
    var done: [(minX: Int, maxX: Int, firstRow: Int, lastRow: Int)] = []
    for row in 6..<limit {
        var runs: [(Int, Int)] = []
        var start = -1
        for column in 6..<(width - 6) {
            let ink = gray[row * width + column] > 128
            if ink, start < 0 { start = column }
            if !ink, start >= 0 { if column - start >= minimumRun { runs.append((start, column)) }; start = -1 }
        }
        if start >= 0, width - 6 - start >= minimumRun { runs.append((start, width - 6)) }
        var stillOpen: [(minX: Int, maxX: Int, firstRow: Int, lastRow: Int)] = []
        for run in runs {
            if let index = open.firstIndex(where: { $0.lastRow == row - 1 && run.0 < $0.maxX && run.1 > $0.minX }) {
                var blank = open.remove(at: index)
                blank.lastRow = row
                blank.minX = min(blank.minX, run.0)
                blank.maxX = max(blank.maxX, run.1)
                stillOpen.append(blank)
            } else {
                stillOpen.append((run.0, run.1, row, row))
            }
        }
        done += open
        open = stillOpen
    }
    done += open
    // A line is thin; a thick run is part of a drawing.
    return done.filter { $0.lastRow - $0.firstRow < 12 }
        .map { Blank(minX: Double($0.minX), maxX: Double($0.maxX), y: Double($0.firstRow + $0.lastRow) / 2, top: $0.firstRow, bottom: $0.lastRow) }
}

/// OCR never sees a full stop or comma that touches the end of a blank, so look for the dot in the pixels.
func punctuationAfter(_ blank: Blank, in gray: [UInt8], width: Int, height: Int, lineHeight: Double) -> String {
    let start = Int(blank.maxX) + 1
    let end = min(width - 6, Int(blank.maxX + lineHeight * 0.9))
    let top = max(6, Int(blank.y - lineHeight * 0.75)), bottom = min(height - 1, Int(blank.y + lineHeight * 0.45))
    guard start < end, top < bottom else { return "" }
    func hasInk(column: Int) -> Bool { (top...bottom).contains { gray[$0 * width + column] > 128 } }
    guard let first = (start..<end).first(where: hasInk), Double(first - start) < lineHeight * 0.5 else { return "" }
    var last = first
    while last + 1 < end, hasInk(column: last + 1) { last += 1 }
    let rows = (top...bottom).filter { row in (first...last).contains { gray[row * width + $0] > 128 } }
    guard let low = rows.last, let high = rows.first else { return "" }
    let size = Double(low - high + 1)
    let narrow = Double(last - first + 1) <= lineHeight * 0.35
    // A dot sits on the line; a quote mark or apostrophe is up near the top of the text.
    guard narrow, size <= lineHeight * 0.6, Double(low) >= blank.y - lineHeight * 0.1 else { return "" }
    let hasGap = zip(rows, rows.dropFirst()).contains { $1 - $0 > 2 }
    let hasTail = low > blank.bottom + 2
    // Two parts with a gap are "!", "?" or ":"; OCR reads the first two itself.
    guard !hasGap else { return "" }
    return hasTail ? (size <= lineHeight * 0.4 ? "," : "") : (size <= lineHeight * 0.2 ? "." : "")
}

/// A word made only of closing punctuation belongs to the word before it, with no space.
func isTrailingPunctuation(_ word: String) -> Bool {
    !word.isEmpty && word.allSatisfy { ".,!?:;)”’\"".contains($0) }
}

func lines(words: [Word], blanks: [Blank], lineHeight: Double) -> [String] {
    enum Item { case word(Word), blank(Blank) }
    func centreY(_ item: Item) -> Double {
        switch item {
        case .word(let word): return (word.minY + word.maxY) / 2
        case .blank(let blank): return blank.y
        }
    }
    func minX(_ item: Item) -> Double {
        switch item {
        case .word(let word): return word.minX
        case .blank(let blank): return blank.minX
        }
    }
    func maxX(_ item: Item) -> Double {
        switch item {
        case .word(let word): return word.maxX
        case .blank(let blank): return blank.maxX
        }
    }

    // Rows are built from the words; a blank joins the nearest row if it sits on that row's baseline.
    var rows: [(y: Double, items: [Item])] = []
    for word in words.sorted(by: { ($0.minY + $0.maxY) < ($1.minY + $1.maxY) }) {
        let centre = (word.minY + word.maxY) / 2
        if let index = rows.firstIndex(where: { abs($0.y - centre) < lineHeight * 0.4 }) {
            rows[index].items.append(.word(word))
        } else {
            rows.append((centre, [.word(word)]))
        }
    }
    for blank in blanks.sorted(by: { $0.y < $1.y }) {
        // The line is drawn at the baseline, a little below the middle of the text.
        if let index = rows.indices.min(by: { abs(rows[$0].y + lineHeight * 0.3 - blank.y) < abs(rows[$1].y + lineHeight * 0.3 - blank.y) }),
           abs(rows[index].y + lineHeight * 0.3 - blank.y) < lineHeight * 0.45 {
            rows[index].items.append(.blank(blank))
        } else {
            rows.append((blank.y - lineHeight * 0.3, [.blank(blank)]))
        }
    }

    return rows.sorted { $0.y < $1.y }.map { row in
        var text = ""
        var previousEnd: Double?
        var previousWasBlank = false
        var punctuationAfterBlank = false
        for item in row.items.sorted(by: { minX($0) < minX($1) }) {
            // The detected dot is the same mark OCR may also report as "." or a bullet.
            if case .word(let word) = item, previousWasBlank, punctuationAfterBlank, ".,•".contains(word.text.first!) {
                previousWasBlank = false
                continue
            }
            let piece: String
            switch item {
            case .word(let word): piece = word.text
            case .blank(let blank): piece = "_____" + blank.punctuation
            }
            // Only a blank can touch its neighbour (as in "Mc_____ Burger"); word boxes are padded and always touch.
            var isBlank = false
            if case .blank = item { isBlank = true }
            var attach = (isBlank || previousWasBlank) && (previousEnd.map { minX(item) - $0 < lineHeight * 0.18 } ?? false)
            if case .word(let word) = item, isTrailingPunctuation(word.text) { attach = true }
            text += (text.isEmpty || attach) ? piece : " " + piece
            previousEnd = maxX(item)
            previousWasBlank = isBlank
            if case .blank(let blank) = item { punctuationAfterBlank = !blank.punctuation.isEmpty }
        }
        return text
    }
}

func pickCount(from footer: String) -> Int? {
    let upper = footer.uppercased()
    guard let range = upper.range(of: #"PICK\s*[(\[]?\s*([0-9])"#, options: .regularExpression),
          let digit = upper[range].last(where: \.isNumber) else { return nil }
    return Int(String(digit))
}

var black: [[String: Any]] = []
var white: [[String: Any]] = []

// A card page has at least this many cards whose footer names the game. A rules page can name the game in its text.
let minimumFootersOnACardPage = 5

for pageNumber in 0..<document.pageCount {
    guard let page = document.page(at: pageNumber) else { continue }
    let rendered = renderPage(page)
    var pageBlack: [[String: Any]] = [], pageWhite: [[String: Any]] = []
    var footersRead = 0
    let width = Int((cellWidth - 2) * scale), height = Int((cellHeight - 2) * scale)
    for cell in 0..<20 {
        let x = Int((originX + Double(cell % 4) * cellWidth + 1) * scale)
        let y = Int((originY + Double(cell / 4) * cellHeight + 1) * scale)
        let raw = crop(rendered.pixels, pageWidth: rendered.width, x: x, y: y, width: width, height: height, invert: false)
        let isBlack = raw.reduce(0) { $0 + Int($1) } / raw.count < 110
        let ink = isBlack ? raw : crop(rendered.pixels, pageWidth: rendered.width, x: x, y: y, width: width, height: height, invert: true)
        let readableOriginal = isBlack ? crop(rendered.pixels, pageWidth: rendered.width, x: x, y: y, width: width, height: height, invert: true) : raw

        var blanks = isBlack ? findBlanks(ink, width: width, height: height) : []
        var readable = readableOriginal
        for blank in blanks {
            for row in max(0, blank.top - 3)...min(height - 1, blank.bottom + 3) {
                for column in max(0, Int(blank.minX) - 2)...min(width - 1, Int(blank.maxX) + 2) { readable[row * width + column] = 255 }
            }
        }
        let all = recognise(readable, width: width, height: height, correction: true)
        let footerWords = all.filter { ($0.minY + $0.maxY) / 2 > Double(height) * footerStart }
        let footer = footerWords.map(\.text).joined(separator: " ")
        let footerRead = footer.range(of: "Humanity|Edition|Against", options: [.regularExpression, .caseInsensitive]) != nil

        let body = all.filter { ($0.minY + $0.maxY) / 2 <= Double(height) * footerStart }
        let heights = body.map { $0.maxY - $0.minY }.sorted()
        let lineHeight = heights.isEmpty ? 40 : max(30, heights[heights.count / 2] * 1.15)
        for index in blanks.indices {
            blanks[index].punctuation = punctuationAfter(blanks[index], in: ink, width: width, height: height, lineHeight: lineHeight)
        }
        let composed = lines(words: body, blanks: blanks, lineHeight: lineHeight)

        var flags: [String] = []
        let plain = recognise(readable, width: width, height: height, correction: false)
            .filter { ($0.minY + $0.maxY) / 2 <= Double(height) * footerStart }
        let withoutCorrection = plain.sorted { ($0.minY + $0.maxY, $0.minX) < ($1.minY + $1.maxY, $1.minX) }.map(\.text).joined(separator: " ")
        let withCorrection = body.sorted { ($0.minY + $0.maxY, $0.minX) < ($1.minY + $1.maxY, $1.minX) }.map(\.text).joined(separator: " ")
        if withoutCorrection != withCorrection { flags.append("ocr-differs: \(withoutCorrection)") }

        var entry: [String: Any] = ["lines": composed, "page": pageNumber, "cell": cell]
        if isBlack {
            if let pick = pickCount(from: footer) { entry["pick"] = pick }
            else if footer.uppercased().contains("PICK") { flags.append("pick-unreadable: \(footer)") }
            if footer.uppercased().contains("DRAW") { flags.append("draw: \(footer)") }
        }
        // The footer of a bottom-row card is sometimes not read; the card is kept when its text is, and flagged.
        if footerRead { footersRead += 1 } else {
            if composed.isEmpty { continue }
            flags.append("footer-unread")
        }
        if !flags.isEmpty { entry["flags"] = flags }
        if isBlack { pageBlack.append(entry) } else { pageWhite.append(entry) }
    }
    if footersRead >= minimumFootersOnACardPage { black += pageBlack; white += pageWhite }
    FileHandle.standardError.write(Data("page \(pageNumber): \(black.count) black, \(white.count) white so far\n".utf8))
}

let output = try JSONSerialization.data(withJSONObject: ["black": black, "white": white], options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(output)
