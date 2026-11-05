import CoreGraphics
import Foundation
import Testing
@testable import Rondo

// Samples trimmed from real Mole 1.68 output.
private let analyzeJSON = """
{
  "scan_status": "partial", "path": "/", "overview": true, "total_size": 295427734160,
  "entries": [
    {"scan_status": "partial", "name": "Home", "path": "/Users/me", "size": 84167418695, "is_dir": true},
    {"scan_status": "complete", "name": "Gradle Cache", "path": "/Users/me/.gradle/caches", "size": 5303107584, "is_dir": true, "insight": true, "cleanable": true},
    {"scan_status": "complete", "name": "User Library", "path": "/Users/me/Library", "size": 119069413376, "is_dir": true},
    {"scan_status": "unavailable", "name": "iOS Backups", "path": "/Users/me/Library/Application Support/MobileSync/Backup", "size": 0, "is_dir": true, "insight": true}
  ],
  "large_files": []
}
"""

private let cleanDryRun = """
\u{1B}[1mClean Your Mac\u{1B}[0m

Dry Run Mode, Preview only, no deletions

◎ System caches need sudo, run sudo -v && mo clean --dry-run for full preview

➤ User essentials
  ○ User app cache · 10 items, 1.77GB dry
  ◎ Trash · skipped, grant Full Disk Access to your terminal

➤ Large files
  ⊙ Docker Desktop data · 49.06GB · ~/Library/Containers/com.docker.docker/Data

➤ Time Machine
  ✓ Nothing to clean

======================================================================
Dry run complete - no changes made
Potential space: 3.07GB · 147 items
Detailed file list: /Users/me/.config/mole/clean-list.txt
======================================================================
"""

private let cleanList = """
# Mole Cleanup Preview - 2026-11-05 09:45:16
#
# Example:
#   /Users/*/Library/Caches/com.example.app
#


=== User essentials ===
/Users/me/Library/Caches/Google  # 1.65GB
/Users/me/Library/Caches/Homebrew  # 39.5MB
/Users/me/Library/Logs/Assistant  # 0B

=== Browsers ===
/Users/me/Library/Caches/Odd  # name  # 41KB

=== Empty ===
"""

@MainActor
struct MoleOutputTests {
    @Test func decodesAnalysisAndSortsMeasuredEntries() throws {
        let analysis = try MoleAnalysis.decode(analyzeJSON)
        #expect(analysis.scanStatus == .partial)
        #expect(analysis.entries.count == 4)
        #expect(analysis.measured.map(\.name) == ["User Library", "Home", "Gradle Cache"])
        let gradle = try #require(analysis.entries.first { $0.name == "Gradle Cache" })
        #expect(gradle.cleanable && gradle.insight)
    }

    @Test func sizeLabelKeepsPartialAndUnavailableMarkers() throws {
        let analysis = try MoleAnalysis.decode(analyzeJSON)
        #expect(analysis.entries[0].sizeLabel.hasPrefix("≥ "))
        #expect(analysis.entries[3].sizeLabel == "Unavailable")
    }

    @Test func parsesReportSectionsNotesAndSummary() {
        let report = MoleReport.parse(cleanDryRun)
        #expect(report.notes == [.init(kind: .skipped, text: "System caches need sudo, run sudo -v && mo clean --dry-run for full preview")])
        #expect(report.sections.map(\.title) == ["User essentials", "Large files", "Time Machine"])
        #expect(report.sections[0].items.map(\.kind) == [.pending, .skipped])
        #expect(report.sections[1].items.first?.kind == .hint)
        #expect(report.summary == ["Dry run complete - no changes made", "Potential space: 3.07GB · 147 items",
                                   "Detailed file list: /Users/me/.config/mole/clean-list.txt"])
    }

    @Test func parsesCleanListGroupsAndDropsEmptyOnes() {
        let list = MoleCleanList.parse(cleanList)
        #expect(list.groups.map(\.title) == ["User essentials", "Browsers"])
        #expect(list.groups[0].candidates.count == 3)
        #expect(list.groups[0].bytes == 1_650_000_000 + 39_500_000)
        #expect(list.groups[1].candidates == [.init(path: "/Users/me/Library/Caches/Odd  # name", bytes: 41_000)])
    }

    @Test func parsesDecimalSizes() {
        #expect(MoleSize.bytes("1.65GB") == 1_650_000_000)
        #expect(MoleSize.bytes("41KB") == 41_000)
        #expect(MoleSize.bytes("0B") == 0)
        #expect(MoleSize.bytes("2TB") == 2_000_000_000_000)
        #expect(MoleSize.bytes("lots") == nil)
    }
}

/// Records every `mo` invocation and answers from a table.
nonisolated private final class FakeMole: @unchecked Sendable {
    var calls: [[String]] = []
    var outputs: [String: String] = [:]
    var failure: Error?

    var runner: MoleService.Runner {
        { [self] _, arguments in
            calls.append(arguments)
            if let failure { throw failure }
            return outputs[arguments.joined(separator: " ")] ?? ""
        }
    }
}

@MainActor
struct MoleServiceTests {
    private func makeService(_ fake: FakeMole, installed: Bool = true, cleanList: URL? = nil) -> MoleService {
        MoleService(defaults: makeDefaults(), locate: { installed ? "/opt/homebrew/bin/mo" : nil },
                    runner: fake.runner, cleanListURL: cleanList ?? URL(fileURLWithPath: "/nonexistent"))
    }

    @Test func missingMoleDisablesActionsAndExplainsInstall() async {
        let fake = FakeMole()
        let mole = makeService(fake, installed: false)
        #expect(!mole.isInstalled)
        await mole.analyze()
        #expect(fake.calls.isEmpty)
        #expect(mole.errorMessage?.contains(MoleService.installCommand) == true)
    }

    @Test func refreshFindsMoleInstalledLater() {
        var found: String?
        let mole = MoleService(defaults: makeDefaults(), locate: { found }, runner: FakeMole().runner)
        #expect(!mole.isInstalled)
        found = "/opt/homebrew/bin/mo"
        mole.refreshInstallation()
        #expect(mole.isInstalled)
    }

    @Test func analyzeRunsJSONModeAndPublishes() async {
        let fake = FakeMole()
        fake.outputs["analyze --json"] = analyzeJSON
        let mole = makeService(fake)
        await mole.analyze()
        #expect(fake.calls == [["analyze", "--json"]])
        #expect(mole.analysis?.entries.count == 4)
        #expect(mole.analyzedAt != nil)
        #expect(!mole.isBusy)
    }

    @Test func cleanRefusesWithoutAPreview() async {
        let fake = FakeMole()
        let mole = makeService(fake)
        await mole.clean()
        await mole.optimize()
        #expect(fake.calls.isEmpty)
    }

    @Test func previewThenCleanRunsRealCommandAndReanalyzes() async throws {
        let listURL = FileManager.default.temporaryDirectory.appendingPathComponent("mole-list-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: listURL) }
        try cleanList.write(to: listURL, atomically: true, encoding: .utf8)
        let fake = FakeMole()
        fake.outputs["clean --dry-run"] = cleanDryRun
        fake.outputs["clean"] = "==========\nCleanup complete\nSpace freed: 3.01GB\n=========="
        fake.outputs["analyze --json"] = analyzeJSON
        fake.outputs["analyze --json \(MoleService.homePath)"] = analyzeJSON
        let mole = makeService(fake, cleanList: listURL)

        await mole.previewClean()
        #expect(mole.cleanPreview?.list.groups.count == 2)
        #expect(mole.cleanPreview?.report.summary.contains("Potential space: 3.07GB · 147 items") == true)

        await mole.clean()
        #expect(fake.calls == [["clean", "--dry-run"], ["clean"], ["analyze", "--json"], ["analyze", "--json", MoleService.homePath]])
        #expect(mole.cleanPreview == nil)
        #expect(mole.lastRun?.action == .clean)
        #expect(mole.lastRun?.report.summary == ["Cleanup complete", "Space freed: 3.01GB"])
    }

    @Test func optimizeRunsAfterPreview() async {
        let fake = FakeMole()
        fake.outputs["optimize --dry-run"] = "➤ Login Items\n  ○ Login items all healthy (1 checked)"
        let mole = makeService(fake)
        await mole.previewOptimize()
        #expect(mole.optimizePreview?.sections.first?.title == "Login Items")
        await mole.optimize()
        #expect(fake.calls == [["optimize", "--dry-run"], ["optimize"]])
        #expect(mole.optimizePreview == nil)
    }

    @Test func failureSurfacesMessageAndKeepsState() async {
        struct Boom: LocalizedError { var errorDescription: String? { "mo failed (1): whitelist unreadable" } }
        let fake = FakeMole()
        fake.failure = Boom()
        let mole = makeService(fake)
        await mole.previewClean()
        #expect(mole.cleanPreview == nil)
        #expect(mole.errorMessage == "mo failed (1): whitelist unreadable")
        #expect(!mole.isBusy)
        mole.dismissError()
        #expect(mole.errorMessage == nil)
    }

    @Test func onboardingFlagPersists() {
        let defaults = makeDefaults()
        let mole = MoleService(defaults: defaults, locate: { nil }, runner: FakeMole().runner)
        #expect(!mole.hasOnboarded)
        mole.hasOnboarded = true
        #expect(MoleService(defaults: defaults, locate: { nil }, runner: FakeMole().runner).hasOnboarded)
    }
}

@MainActor
struct MoleFolderTests {
    @Test func loadFolderCachesPerPathAndForceReloads() async {
        let fake = FakeMole()
        fake.outputs["analyze --json /tmp/x"] = analyzeJSON
        let mole = MoleService(defaults: makeDefaults(), locate: { "/opt/homebrew/bin/mo" }, runner: fake.runner)
        await mole.loadFolder("/tmp/x")
        await mole.loadFolder("/tmp/x")
        #expect(fake.calls == [["analyze", "--json", "/tmp/x"]])
        #expect(mole.folders["/tmp/x"]?.entries.count == 4)
        #expect(mole.loadingFolders.isEmpty)
        await mole.loadFolder("/tmp/x", force: true)
        #expect(fake.calls.count == 2)
    }

    @Test func loadFolderRecordsErrorsPerPath() async {
        let fake = FakeMole()
        fake.outputs["analyze --json /tmp/bad"] = "not json"
        let mole = MoleService(defaults: makeDefaults(), locate: { "/opt/homebrew/bin/mo" }, runner: fake.runner)
        await mole.loadFolder("/tmp/bad")
        #expect(mole.folders["/tmp/bad"] == nil)
        #expect(mole.folderErrors["/tmp/bad"] != nil)
    }
}

@MainActor
struct DiskChartTests {
    @Test func topSlicesFoldTheRestIntoOthers() {
        let items = (1...10).map { (id: "f\($0)", name: "f\($0)", bytes: Int64($0 * 10)) }
        let slices = SizeSlice.top(items, maxSlices: 3)
        #expect(slices.map(\.name) == ["f10", "f9", "f8", "Others"])
        #expect(slices.last?.bytes == (1...7).reduce(0) { $0 + Int64($1 * 10) })
        #expect(slices.last?.slot == nil)
        #expect(slices.first?.slot == 0)
    }

    @Test func sliceAtFractionFollowsCumulativeShare() {
        let slices = SizeSlice.top([("a", "a", 75), ("b", "b", 25)])
        #expect(SizeSlice.slice(at: 0.1, in: slices)?.id == "a")
        #expect(SizeSlice.slice(at: 0.74, in: slices)?.id == "a")
        #expect(SizeSlice.slice(at: 0.9, in: slices)?.id == "b")
    }

    @Test func treemapFillsTheRectWithProportionalTiles() {
        let rect = CGRect(x: 0, y: 0, width: 600, height: 400)
        let values: [Double] = [6, 0, 6, 4, 3, 2, 2, 1]
        let tiles = Treemap.layout(values, in: rect)
        #expect(tiles.count == 7) // the zero is skipped
        let area = tiles.reduce(0) { $0 + $1.rect.width * $1.rect.height }
        #expect(abs(area - rect.width * rect.height) < 1)
        for tile in tiles {
            #expect(rect.insetBy(dx: -0.01, dy: -0.01).contains(tile.rect))
            let expected = values[tile.index] / 24 * 240_000
            #expect(abs(Double(tile.rect.width * tile.rect.height) - expected) < 1)
        }
        // no overlaps
        for (i, a) in tiles.enumerated() {
            for b in tiles[(i + 1)...] { #expect(a.rect.intersection(b.rect).width * a.rect.intersection(b.rect).height < 0.01) }
        }
    }

    @Test func treemapKeepsTilesReasonablySquare() {
        let tiles = Treemap.layout(Array(repeating: 1, count: 16), in: CGRect(x: 0, y: 0, width: 400, height: 400))
        let worst = tiles.map { max($0.rect.width, $0.rect.height) / min($0.rect.width, $0.rect.height) }.max() ?? 0
        #expect(worst < 2)
    }

    @Test func treemapHandlesEmptyInput() {
        #expect(Treemap.layout([], in: CGRect(x: 0, y: 0, width: 10, height: 10)).isEmpty)
        #expect(Treemap.layout([1], in: .zero).isEmpty)
    }
}
