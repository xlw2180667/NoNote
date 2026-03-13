import Foundation
import UIKit

enum ExportService {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M-d-yyyy"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()

    static func exportAsText(entries: [(dateString: String, text: String, mood: String?)]) -> URL? {
        var content = "NoDiary Export\n"
        content += String(repeating: "=", count: 40) + "\n\n"

        let sorted = entries.sorted { $0.dateString < $1.dateString }
        for entry in sorted {
            let displayDate: String
            if let date = dateFormatter.date(from: entry.dateString) {
                displayDate = displayFormatter.string(from: date)
            } else {
                displayDate = entry.dateString
            }

            content += displayDate
            if let mood = entry.mood {
                content += " \(mood)"
            }
            content += "\n"
            content += String(repeating: "-", count: 30) + "\n"
            content += entry.text + "\n\n"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("NoDiary_Export.txt")
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }

    static func exportAsPDF(entries: [(dateString: String, text: String, mood: String?)]) -> URL? {
        let sorted = entries.sorted { $0.dateString < $1.dateString }
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let titleFont = UIFont(name: "Roboto-Bold", size: 20) ?? UIFont.boldSystemFont(ofSize: 20)
        let dateFont = UIFont(name: "Roboto-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        let bodyFont = UIFont(name: "Roboto-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)

        let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont]
        let dateAttributes: [NSAttributedString.Key: Any] = [.font: dateFont]
        let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = renderer.pdfData { context in
            context.beginPage()
            var yPos: CGFloat = margin

            // Title
            let title = "NoDiary Export"
            title.draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttributes)
            yPos += 30

            for entry in sorted {
                let displayDate: String
                if let date = dateFormatter.date(from: entry.dateString) {
                    displayDate = displayFormatter.string(from: date)
                } else {
                    displayDate = entry.dateString
                }

                let dateText = entry.mood != nil ? "\(displayDate) \(entry.mood!)" : displayDate
                let bodyRect = (entry.text as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    attributes: bodyAttributes,
                    context: nil
                )

                let neededHeight = 25 + bodyRect.height + 20

                if yPos + neededHeight > pageHeight - margin {
                    context.beginPage()
                    yPos = margin
                }

                dateText.draw(at: CGPoint(x: margin, y: yPos), withAttributes: dateAttributes)
                yPos += 20

                (entry.text as NSString).draw(
                    in: CGRect(x: margin, y: yPos, width: contentWidth, height: bodyRect.height),
                    withAttributes: bodyAttributes
                )
                yPos += bodyRect.height + 20
            }
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("NoDiary_Export.pdf")
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }
}
