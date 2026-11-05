import Foundation

// Parsers for the Mole CLI surfaces Rondo reads (see Mole's skills/mole/references/macos.md).
// Pure and nonisolated so they can be tested without running `mo`.

/// `mo analyze --json [path]`.
nonisolated struct MoleAnalysis: Decodable, Equatable, Sendable {
    enum ScanStatus: String, Decodable, Sendable { case complete, partial, unavailable }

    struct Entry: Decodable, Equatable, Identifiable, Sendable {
        let name: String
        let path: String
        let size: Int64
        let scanStatus: ScanStatus
        var isDir = true
        var insight = false
        var cleanable = false

        var id: String { path }
        var url: URL { URL(fileURLWithPath: path) }

        enum CodingKeys: String, CodingKey {
            case name, path, size, insight, cleanable
            case scanStatus = "scan_status", isDir = "is_dir"
        }

        init(name: String, path: String, size: Int64, scanStatus: ScanStatus = .complete,
             insight: Bool = false, cleanable: Bool = false) {
            self.name = name
            self.path = path
            self.size = size
            self.scanStatus = scanStatus
            self.insight = insight
            self.cleanable = cleanable
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            path = try c.decode(String.self, forKey: .path)
            size = try c.decodeIfPresent(Int64.self, forKey: .size) ?? 0
            scanStatus = (try? c.decode(ScanStatus.self, forKey: .scanStatus)) ?? .unavailable
            isDir = try c.decodeIfPresent(Bool.self, forKey: .isDir) ?? true
            insight = try c.decodeIfPresent(Bool.self, forKey: .insight) ?? false
            cleanable = try c.decodeIfPresent(Bool.self, forKey: .cleanable) ?? false
        }

        /// What the size means: a partial scan is a lower bound, an unavailable one is unknown (not zero).
        var sizeLabel: String {
            switch scanStatus {
            case .complete: formatBytes(size, style: .file)
            case .partial: "≥ " + formatBytes(size, style: .file)
            case .unavailable: "Unavailable"
            }
        }
    }

    let path: String
    let scanStatus: ScanStatus
    let entries: [Entry]

    enum CodingKeys: String, CodingKey {
        case path, entries
        case scanStatus = "scan_status"
    }

    /// Entries with a known size, largest first.
    var measured: [Entry] {
        entries.filter { $0.scanStatus != .unavailable && $0.size > 0 }.sorted { $0.size > $1.size }
    }

    static func decode(_ json: String) throws -> MoleAnalysis {
        try JSONDecoder().decode(MoleAnalysis.self, from: Data(json.utf8))
    }
}

/// The human-readable report `mo clean`/`mo optimize` (and their `--dry-run`) print without a terminal.
nonisolated struct MoleReport: Equatable, Sendable {
    struct Item: Equatable, Hashable, Sendable {
        enum Kind: Sendable { case done, pending, skipped, hint, other }
        let kind: Kind
        let text: String
    }

    struct Section: Equatable, Identifiable, Sendable {
        let title: String
        var items: [Item]
        var id: String { title }
    }

    /// Lines printed before the first section (e.g. "System caches need sudo…").
    var notes: [Item] = []
    var sections: [Section] = []
    /// The framed summary at the end ("Dry run complete…", "Potential space: …").
    var summary: [String] = []

    static func parse(_ raw: String) -> MoleReport {
        var report = MoleReport()
        var frameCount = 0
        for line in stripANSI(raw).components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("====") { frameCount += 1; continue }
            guard !trimmed.isEmpty else { continue }
            if frameCount == 1 { report.summary.append(trimmed); continue }
            if trimmed.hasPrefix("➤") {
                report.sections.append(Section(title: String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces), items: []))
                continue
            }
            guard let item = item(from: trimmed) else { continue }
            if report.sections.isEmpty { report.notes.append(item) } else { report.sections[report.sections.count - 1].items.append(item) }
        }
        return report
    }

    /// Only symbol-led lines are items; banners and headings are dropped.
    private static func item(from line: String) -> Item? {
        let kinds: [Character: Item.Kind] = ["✓": .done, "○": .pending, "◎": .skipped, "⊙": .hint, "•": .other, "✗": .skipped]
        guard let first = line.first, let kind = kinds[first] else { return nil }
        return Item(kind: kind, text: String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
    }

    static func stripANSI(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[A-Za-z]", with: "", options: .regularExpression)
    }
}

/// `~/.config/mole/clean-list.txt`, written by `mo clean --dry-run`: every candidate path grouped by category.
nonisolated struct MoleCleanList: Equatable, Sendable {
    struct Candidate: Equatable, Hashable, Sendable {
        let path: String
        let bytes: Int64
    }

    struct Group: Equatable, Identifiable, Sendable {
        let title: String
        var candidates: [Candidate]
        var id: String { title }
        var bytes: Int64 { candidates.reduce(0) { $0 + $1.bytes } }
    }

    var groups: [Group] = []

    static func parse(_ text: String) -> MoleCleanList {
        var list = MoleCleanList()
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("==="), trimmed.hasSuffix("===") {
                list.groups.append(Group(title: trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "= ")), candidates: []))
                continue
            }
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !list.groups.isEmpty else { continue }
            // "path  # size" — split on the last marker, paths may contain " # "
            let parts = trimmed.components(separatedBy: "  # ")
            let path = parts.count > 1 ? parts.dropLast().joined(separator: "  # ") : trimmed
            let bytes = parts.count > 1 ? MoleSize.bytes(parts.last!) ?? 0 : 0
            list.groups[list.groups.count - 1].candidates.append(Candidate(path: path, bytes: bytes))
        }
        list.groups.removeAll { $0.candidates.isEmpty }
        return list
    }
}

/// Mole prints decimal units ("1.65GB", "41KB", "0B").
nonisolated enum MoleSize {
    private static let units: [(String, Double)] = [("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("KB", 1e3), ("B", 1)]

    static func bytes(_ text: String) -> Int64? {
        let value = text.trimmingCharacters(in: .whitespaces).uppercased()
        for (suffix, scale) in units where value.hasSuffix(suffix) {
            guard let number = Double(value.dropLast(suffix.count)) else { return nil }
            return Int64((number * scale).rounded())
        }
        return nil
    }
}
