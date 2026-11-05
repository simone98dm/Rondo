import AppKit
import SwiftUI

/// `mo clean`: preview what would go (by category, with a chart), confirm, run.
struct MoleCleanView: View {
    @Environment(MoleService.self) private var mole
    @State private var isConfirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let run = mole.lastRun, run.action == .clean { lastRun(run.report, date: run.date) }
            if let preview = mole.cleanPreview {
                previewSection(preview)
            } else {
                intro
            }
        }
        .confirmationDialog("Clean with Mole?", isPresented: $isConfirming) {
            Button("Clean", role: .destructive) { Task { await mole.clean() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mole rescans and deletes what the preview found, permanently (not to the Trash). It also empties the Trash unless you protected it with `mo clean --whitelist`. System caches that need an administrator password are skipped.")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Find caches, logs and app leftovers").font(.title3.weight(.semibold))
            Text("Mole lists everything it would remove first. Nothing is deleted until you review the preview and confirm.")
                .foregroundStyle(.secondary)
            Button { Task { await mole.previewClean() } } label: { Label("Preview Clean", systemImage: "magnifyingglass") }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(mole.isBusy)
        }
    }

    @ViewBuilder
    private func previewSection(_ preview: MoleService.CleanPreview) -> some View {
        MoleSummaryView(lines: preview.report.summary)
        if !preview.list.groups.isEmpty {
            let slices = SizeSlice.top(preview.list.groups.map { ($0.title, $0.title, $0.bytes) })
            SizeDonut(slices: slices, diameter: 170, legendLimit: 8)
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                ForEach(preview.list.groups.sorted { $0.bytes > $1.bytes }) { group in
                    CleanGroupRow(group: group, color: slices.first { $0.id == group.title }?.color ?? ChartPalette.other)
                }
            }
        }
        if !skippedItems(preview.report).isEmpty {
            Text("Skipped or needs review").font(.subheadline.weight(.semibold))
            ForEach(skippedItems(preview.report), id: \.self) { MoleItemRow(item: $0) }
        }
        HStack {
            Button { Task { await mole.previewClean() } } label: { Label("Preview Again", systemImage: "arrow.clockwise") }
                .disabled(mole.isBusy)
            Spacer()
            Button(role: .destructive) { isConfirming = true } label: { Label("Clean…", systemImage: "sparkles") }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(mole.isBusy || preview.list.groups.isEmpty)
        }
        Text("Want to keep something? Add it to `~/.config/mole/whitelist` (one path per line), then preview again.")
            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
    }

    /// Notes and hints Mole won't act on (sudo needed, Full Disk Access, manual review).
    private func skippedItems(_ report: MoleReport) -> [MoleReport.Item] {
        (report.notes + report.sections.flatMap(\.items)).filter { $0.kind == .skipped || $0.kind == .hint }
    }

    private func lastRun(_ report: MoleReport, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Last clean at \(date.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.seal")
                .font(.subheadline.weight(.semibold))
            MoleSummaryView(lines: report.summary)
        }
    }
}

/// One category, expandable to its paths.
struct CleanGroupRow: View {
    let group: MoleCleanList.Group
    let color: Color
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(group.candidates.sorted { $0.bytes > $1.bytes }, id: \.self) { candidate in
                HStack {
                    Text(candidate.path).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    Spacer()
                    Text(formatBytes(candidate.bytes, style: .file)).monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.caption)
                .contextMenu {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: candidate.path)])
                    }
                }
            }
        } label: {
            HStack {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9).accessibilityHidden(true)
                Text(group.title)
                Text("\(group.candidates.count) items").foregroundStyle(.secondary)
                Spacer()
                Text(formatBytes(group.bytes, style: .file)).monospacedDigit()
            }
            .font(.callout)
        }
    }
}
