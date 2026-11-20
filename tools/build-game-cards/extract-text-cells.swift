// Reads the text layer of a Cards Against Humanity print-and-play PDF, one grid cell per card.
// Usage: swift extract-text-cells.swift <pdf> <black-pages> <white-pages> > raw.json
// Pages are 0-based and written as ranges, e.g. 2-6 and 7-32. Output: {"black": [[line, ...]], "white": [[line, ...]]}
import Foundation
import PDFKit

let arguments = CommandLine.arguments
guard arguments.count == 4, let document = PDFDocument(url: URL(fileURLWithPath: arguments[1])) else {
    FileHandle.standardError.write(Data("usage: extract-text-cells.swift <pdf> <black-pages> <white-pages>\n".utf8))
    exit(2)
}

func pages(_ range: String) -> [Int] {
    let ends = range.split(separator: "-").compactMap { Int($0) }
    return Array(ends[0]...ends[ends.count - 1])
}

// The cards sit on a 4 x 5 grid of a US Letter page.
let originX = 18.3, originY = 18.3, cellWidth = 143.9, cellHeight = 145.5, pageHeight = 792.0

func cards(on pageNumbers: [Int]) -> [[String]] {
    var result: [[String]] = []
    for number in pageNumbers {
        guard let page = document.page(at: number) else { continue }
        for row in 0..<5 {
            for column in 0..<4 {
                let top = pageHeight - (originY + Double(row) * cellHeight)
                let area = CGRect(x: originX + Double(column) * cellWidth + 1, y: top - cellHeight + 1,
                                  width: cellWidth - 2, height: cellHeight - 2)
                let lines = (page.selection(for: area)?.string ?? "")
                    .split(separator: "\n", omittingEmptySubsequences: true)
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                if !lines.isEmpty { result.append(lines) }
            }
        }
    }
    return result
}

let output = ["black": cards(on: pages(arguments[2])), "white": cards(on: pages(arguments[3]))]
let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
