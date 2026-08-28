import Foundation

/// One day's worth of imported text, already merged and normalised.
struct ImportedEntry: Identifiable, Equatable {
    let date: Date
    /// `M-d-yyyy`, the app's diary key.
    let dateKey: String
    var text: String
    var mood: String?

    var id: String { dateKey }
}

/// What a parse produced, before anything is written.
struct ImportPreview {
    var entries: [ImportedEntry] = []
    /// Source records that were merged into an existing day (one entry per day is the app's rule).
    var mergedCount = 0
    /// Records the parser understood but had to drop (no date, or empty text).
    var skippedCount = 0
    var source: DiaryImportService.Source

    var earliest: Date? { entries.map(\.date).min() }
    var latest: Date? { entries.map(\.date).max() }
}

enum ImportError: LocalizedError {
    case unreadable
    case unrecognisedFormat
    case nothingFound

    var errorDescription: String? {
        switch self {
        case .unreadable: return String(localized: "#importErrorUnreadable")
        case .unrecognisedFormat: return String(localized: "#importErrorFormat")
        case .nothingFound: return String(localized: "#importErrorEmpty")
        }
    }
}

/// Parses diary exports from other apps into `ImportedEntry` values.
///
/// Nothing here touches CloudKit or the cache — parsing is pure, so the UI can show an honest
/// preview ("412 entries, 2019–2026") and let the user back out before anything is written.
///
/// The app's one-entry-per-day rule is enforced here: sources that allow several entries a day
/// get merged into one, in chronological order, separated by a blank line.
enum DiaryImportService {
    enum Source: String, CaseIterable, Identifiable {
        case dayOne
        case textFolder
        case csv
        case noDiary

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dayOne: return String(localized: "#importSourceDayOne")
            case .textFolder: return String(localized: "#importSourceTextFolder")
            case .csv: return String(localized: "#importSourceCSV")
            case .noDiary: return String(localized: "#importSourceNoDiary")
            }
        }

        var detail: String {
            switch self {
            case .dayOne: return String(localized: "#importSourceDayOneDetail")
            case .textFolder: return String(localized: "#importSourceTextFolderDetail")
            case .csv: return String(localized: "#importSourceCSVDetail")
            case .noDiary: return String(localized: "#importSourceNoDiaryDetail")
            }
        }

        /// Whether the picker should ask for a folder rather than a file.
        var picksFolder: Bool { self == .textFolder }
    }

    static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M-d-yyyy"
        return f
    }()

    // MARK: - Entry point

    static func parse(url: URL, as source: Source) throws -> ImportPreview {
        // Files handed over by the document picker live outside the sandbox.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        var records: [(date: Date, text: String, mood: String?)]
        var skipped = 0
        switch source {
        case .dayOne:
            (records, skipped) = try parseDayOne(url)
        case .textFolder:
            (records, skipped) = try parseTextFolder(url)
        case .csv:
            (records, skipped) = try parseCSV(url)
        case .noDiary:
            (records, skipped) = try parseNoDiaryExport(url)
        }

        let (entries, merged) = collapseToOnePerDay(records)
        guard !entries.isEmpty else { throw ImportError.nothingFound }
        return ImportPreview(entries: entries, mergedCount: merged,
                             skippedCount: skipped, source: source)
    }

    // MARK: - One entry per day

    static func collapseToOnePerDay(
        _ records: [(date: Date, text: String, mood: String?)]
    ) -> (entries: [ImportedEntry], merged: Int) {
        var byDay: [String: (date: Date, parts: [(Date, String)], mood: String?)] = [:]
        for record in records {
            let key = dateKeyFormatter.string(from: record.date)
            if var existing = byDay[key] {
                existing.parts.append((record.date, record.text))
                existing.mood = existing.mood ?? record.mood
                byDay[key] = existing
            } else {
                byDay[key] = (record.date, [(record.date, record.text)], record.mood)
            }
        }

        var merged = 0
        var entries: [ImportedEntry] = []
        for (key, day) in byDay {
            if day.parts.count > 1 { merged += day.parts.count - 1 }
            let text = day.parts
                .sorted { $0.0 < $1.0 }
                .map(\.1)
                .joined(separator: "\n\n")
            entries.append(ImportedEntry(date: day.date, dateKey: key, text: text, mood: day.mood))
        }
        entries.sort { $0.date < $1.date }
        return (entries, merged)
    }

    // MARK: - Day One

    /// Day One exports a zip; inside it is `Journal.json`. Point this at that JSON.
    private static func parseDayOne(_ url: URL) throws -> ([(Date, String, String?)], Int) {
        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["entries"] as? [[String: Any]] else {
            throw ImportError.unrecognisedFormat
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var out: [(Date, String, String?)] = []
        var skipped = 0
        for item in raw {
            guard let stamp = item["creationDate"] as? String,
                  let instant = iso.date(from: stamp) ?? isoFractional.date(from: stamp) else {
                skipped += 1
                continue
            }
            // Day One stamps UTC and records the zone separately. Read the calendar day in the
            // zone the entry was written in, then rebuild that day in the device's zone — the
            // diary key is formatted device-local, so carrying the foreign zone's midnight
            // across would file a trip entry under the wrong day.
            var sourceCalendar = Calendar(identifier: .gregorian)
            if let zoneName = item["timeZone"] as? String, let zone = TimeZone(identifier: zoneName) {
                sourceCalendar.timeZone = zone
            }
            let parts = sourceCalendar.dateComponents([.year, .month, .day], from: instant)
            var local = DateComponents()
            local.year = parts.year
            local.month = parts.month
            local.day = parts.day
            guard let localDay = Calendar.current.date(from: local) else { skipped += 1; continue }

            let body = (item["text"] as? String) ?? (item["richText"] as? String) ?? ""
            let cleaned = stripDayOneMarkup(body)
            if cleaned.isEmpty { skipped += 1; continue }
            out.append((localDay, cleaned, nil))
        }
        return (out, skipped)
    }

    /// Day One embeds photos as `![](dayone-moment://UUID)` and escapes a lot of punctuation.
    private static func stripDayOneMarkup(_ text: String) -> String {
        var s = text.replacingOccurrences(
            of: #"!\[[^\]]*\]\(dayone-moment:[^)]*\)"#, with: "", options: .regularExpression)
        for escaped in ["\\-", "\\.", "\\#", "\\*", "\\_", "\\[", "\\]", "\\!"] {
            s = s.replacingOccurrences(of: escaped, with: String(escaped.dropFirst()))
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Folder of .txt / .md

    private static func parseTextFolder(_ url: URL) throws -> ([(Date, String, String?)], Int) {
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey],
                                         options: [.skipsHiddenFiles]) else {
            throw ImportError.unreadable
        }
        var out: [(Date, String, String?)] = []
        var skipped = 0
        for case let file as URL in walker {
            guard ["txt", "md", "markdown"].contains(file.pathExtension.lowercased()) else { continue }
            guard let date = dateFromFilename(file.deletingPathExtension().lastPathComponent) else {
                skipped += 1
                continue
            }
            guard let body = try? String(contentsOf: file, encoding: .utf8) else { skipped += 1; continue }
            let cleaned = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty { skipped += 1; continue }
            out.append((date, cleaned, nil))
        }
        if out.isEmpty && skipped == 0 { throw ImportError.nothingFound }
        return (out, skipped)
    }

    /// `2024-03-15`, `2024_03_15`, `20240315`, and the same with a title after it.
    static func dateFromFilename(_ name: String) -> Date? {
        let patterns = [
            (#"(\d{4})[-_./](\d{1,2})[-_./](\d{1,2})"#, true),
            (#"(\d{4})(\d{2})(\d{2})"#, true),
        ]
        for (pattern, _) in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
                  m.numberOfRanges == 4 else { continue }
            func part(_ i: Int) -> Int? {
                guard let r = Range(m.range(at: i), in: name) else { return nil }
                return Int(name[r])
            }
            guard let y = part(1), let mo = part(2), let d = part(3),
                  (1...12).contains(mo), (1...31).contains(d) else { continue }
            var c = DateComponents()
            c.year = y; c.month = mo; c.day = d
            if let date = Calendar.current.date(from: c) { return date }
        }
        return nil
    }

    // MARK: - CSV

    private static func parseCSV(_ url: URL) throws -> ([(Date, String, String?)], Int) {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { throw ImportError.unreadable }
        let rows = parseCSVRows(raw)
        guard !rows.isEmpty else { throw ImportError.nothingFound }

        // Header is optional: treat row 0 as a header only if its first cell isn't a date.
        var start = 0
        var dateColumn = 0, textColumn = 1, moodColumn: Int? = nil
        if flexibleDate(rows[0].first ?? "") == nil {
            let header = rows[0].map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            dateColumn = header.firstIndex { $0.contains("date") || $0.contains("日期") } ?? 0
            textColumn = header.firstIndex {
                $0.contains("text") || $0.contains("entry") || $0.contains("content")
                    || $0.contains("diary") || $0.contains("内容") || $0.contains("日记")
            } ?? 1
            moodColumn = header.firstIndex { $0.contains("mood") || $0.contains("心情") }
            start = 1
        }

        var out: [(Date, String, String?)] = []
        var skipped = 0
        for row in rows.dropFirst(start) {
            guard row.count > max(dateColumn, textColumn),
                  let date = flexibleDate(row[dateColumn]) else { skipped += 1; continue }
            let text = row[textColumn].trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { skipped += 1; continue }
            let mood = moodColumn.flatMap { $0 < row.count ? row[$0] : nil }
                .flatMap { $0.isEmpty ? nil : $0 }
            out.append((date, text, mood))
        }
        return (out, skipped)
    }

    /// Minimal RFC-4180 reader: handles quoted fields, embedded commas and newlines, and "" escapes.
    static func parseCSVRows(_ input: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = input.makeIterator()
        var pending: Character? = nil

        func nextChar() -> Character? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }

        while let ch = nextChar() {
            if inQuotes {
                if ch == "\"" {
                    if let peek = nextChar() {
                        if peek == "\"" { field.append("\"") } else { inQuotes = false; pending = peek }
                    } else { inQuotes = false }
                } else {
                    field.append(ch)
                }
            } else {
                switch ch {
                case "\"": inQuotes = true
                case ",": row.append(field); field = ""
                case "\n", "\r":
                    if ch == "\r", let peek = nextChar() {
                        if peek != "\n" { pending = peek }
                    }
                    row.append(field); field = ""
                    if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
                    row = []
                default: field.append(ch)
                }
            }
        }
        row.append(field)
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        return rows
    }

    /// Parses the date spellings that show up in exported CSVs.
    static func flexibleDate(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if let d = dateFromFilename(s) { return d }

        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy", "dd/MM/yyyy",
                       "M-d-yyyy", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss"]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            f.dateFormat = format
            if let d = f.date(from: s) { return Calendar.current.startOfDay(for: d) }
        }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return Calendar.current.startOfDay(for: d) }
        return nil
    }

    // MARK: - NoDiary's own .txt export

    /// Round-trips `ExportService.exportAsText`: a display date line, a dashed rule, then the body.
    private static func parseNoDiaryExport(_ url: URL) throws -> ([(Date, String, String?)], Int) {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { throw ImportError.unreadable }

        // The export writes month names in whatever locale ran it, so try the device locale first.
        let formatters: [DateFormatter] = [Locale.current, Locale(identifier: "en_US_POSIX")].map {
            let f = DateFormatter()
            f.locale = $0
            f.dateFormat = "EEEE, MMMM d, yyyy"
            return f
        }
        func parseHeader(_ line: String) -> (Date, String?)? {
            // A trailing mood emoji may follow the date.
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for f in formatters {
                if let d = f.date(from: trimmed) { return (d, nil) }
                if let cut = trimmed.range(of: " ", options: .backwards) {
                    let head = String(trimmed[..<cut.lowerBound])
                    let tail = String(trimmed[cut.upperBound...])
                    if let d = f.date(from: head) { return (d, tail.isEmpty ? nil : tail) }
                }
            }
            return nil
        }

        var out: [(Date, String, String?)] = []
        var skipped = 0
        let lines = raw.components(separatedBy: .newlines)
        var index = 0
        while index < lines.count {
            guard let (date, mood) = parseHeader(lines[index]),
                  index + 1 < lines.count,
                  lines[index + 1].hasPrefix("---") else {
                index += 1
                continue
            }
            var body: [String] = []
            var cursor = index + 2
            while cursor < lines.count, parseHeader(lines[cursor]) == nil {
                body.append(lines[cursor])
                cursor += 1
            }
            let text = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { skipped += 1 } else { out.append((date, text, mood)) }
            index = cursor
        }
        if out.isEmpty { throw ImportError.unrecognisedFormat }
        return (out, skipped)
    }
}
