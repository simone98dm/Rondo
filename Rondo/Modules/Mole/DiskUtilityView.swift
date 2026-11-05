import AppKit
import SwiftUI

/// Popover Disk tab: free space, and a donut of what fills the home folder (`mo analyze --json ~`).
struct DiskUtilityView: View {
    @Environment(MoleService.self) private var mole
    @Environment(SystemMonitorService.self) private var monitor
    @Environment(PopoverState.self) private var popover

    private static let listLimit = 6
    private var home: String { MoleService.homePath }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TabHeader(title: "Disk Usage", symbol: "internaldrive", subtitle: subtitle) { headerAccessory }
                        .padding(.horizontal, -16)
                    if monitor.snapshot.diskTotal > 0 {
                        CapacityBar(used: monitor.snapshot.diskUsed, total: monitor.snapshot.diskTotal)
                    }
                    content
                }
                .padding(16)
            }
            // pinned so the way into Disk Clean is always visible
            cleanUpButton.padding(.horizontal, 16).padding(.vertical, 10)
        }
        .task {
            if mole.isInstalled { await mole.loadFolder(home) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !mole.isInstalled {
            EmptyStateView(symbol: "shippingbox", message: "Disk analysis and cleanup use Mole, a free command-line tool. Install it to turn this tab on.",
                           actionTitle: "Set Up Mole…") { popover.open(.diskClean) }
        } else if let analysis = mole.folders[home], !analysis.measured.isEmpty {
            Text("Home folder").font(.subheadline.weight(.semibold))
            SizeDonut(slices: slices(analysis), diameter: 128, legendLimit: 8, showsPercent: false)
            Divider()
            largest(analysis.measured.prefix(Self.listLimit))
        } else if mole.loadingFolders.contains(home) {
            EmptyStateView(symbol: "magnifyingglass", message: "Analyzing your home folder…")
        } else if let error = mole.folderErrors[home] {
            EmptyStateView(symbol: "exclamationmark.triangle", message: error, actionTitle: "Try Again") {
                Task { await mole.loadFolder(home, force: true) }
            }
        } else {
            EmptyStateView(symbol: "chart.pie", message: "See which folders take the most space.",
                           actionTitle: "Analyze Disk") { Task { await mole.loadFolder(home, force: true) } }
        }
    }

    private func slices(_ analysis: MoleAnalysis) -> [SizeSlice] {
        SizeSlice.top(analysis.measured.map { ($0.path, $0.name, $0.size) })
    }

    private var cleanUpButton: some View {
        Button { popover.open(.diskClean) } label: {
            Label("Open Disk Clean…", systemImage: "sparkles").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .pointerStyle(.link)
        .accessibilityHint("Opens the disk overview, cleanup and maintenance, powered by Mole")
    }

    private var subtitle: String? {
        guard let date = mole.analyzedAt else { return mole.isInstalled ? nil : "Mole not installed" }
        return "Analyzed at \(date.formatted(date: .omitted, time: .shortened))"
    }

    @ViewBuilder
    private var headerAccessory: some View {
        if mole.loadingFolders.contains(home) {
            ProgressView().controlSize(.small).accessibilityLabel("Analyzing")
        } else if mole.folders[home] != nil {
            Button { Task { await mole.loadFolder(home, force: true) } } label: { Label("Rescan", systemImage: "arrow.clockwise") }
                .buttonStyle(.rondo)
                .accessibilityHint("Measures the folders again")
        }
    }

    private func largest(_ entries: ArraySlice<MoleAnalysis.Entry>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entries) { entry in
                Button { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: entry.isDir ? "folder" : "doc").foregroundStyle(.secondary).accessibilityHidden(true)
                        Text(entry.name).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(entry.sizeLabel).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                .buttonStyle(.rondoRow)
                .accessibilityLabel("\(entry.name), \(entry.sizeLabel)")
                .accessibilityHint("Shows it in Finder")
                .help(entry.path)
            }
        }
        .padding(.horizontal, -8)
    }
}
