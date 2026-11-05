import AppKit
import SwiftUI

/// Disk Clean → Overview: free space, what fills the home folder, Mole's heavy locations,
/// and an explorer to drill into any folder as a map (treemap) or a tree list.
struct MoleOverviewView: View {
    @Environment(MoleService.self) private var mole
    @Environment(SystemMonitorService.self) private var monitor
    @State private var path = MoleService.homePath
    @State private var style: ExplorerStyle = .map

    enum ExplorerStyle: String, CaseIterable, Identifiable {
        case map = "UI", list = "List"
        var id: Self { self }
        var symbol: String { self == .map ? "square.grid.2x2" : "list.bullet.indent" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            summary.frame(height: 160)
            Divider()
            explorerHeader
            explorer.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .task {
            await mole.loadFolder(MoleService.homePath)
            if mole.analysis == nil, !mole.isBusy { await mole.analyze() }
        }
        .task(id: path) { await mole.loadFolder(path) }
    }

    // MARK: Summary row

    private var summary: some View {
        HStack(alignment: .top, spacing: 24) {
            card("Macintosh HD") {
                let snap = monitor.snapshot
                if snap.diskTotal > 0 {
                    Text(formatBytes(max(0, snap.diskTotal - snap.diskUsed), style: .file))
                        .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    Text("free of \(formatBytes(snap.diskTotal, style: .file))").foregroundStyle(.secondary)
                    CapacityBar(used: snap.diskUsed, total: snap.diskTotal).padding(.top, 6)
                } else {
                    Text("Measuring…").foregroundStyle(.secondary)
                }
            }
            .frame(width: 210)
            card("Home folder") {
                if let home = mole.folders[MoleService.homePath] {
                    SizeDonut(slices: SizeSlice.top(home.measured.map { ($0.path, $0.name, $0.size) }, maxSlices: 5),
                              diameter: 124, legendLimit: 6)
                } else {
                    loading("Analyzing home folder…")
                }
            }
            .frame(minWidth: 340)
            card("Heavy locations") { heavyLocations }
        }
    }

    @ViewBuilder
    private var heavyLocations: some View {
        let insights = (mole.analysis?.measured ?? []).filter { $0.insight }.prefix(6)
        if insights.isEmpty {
            if mole.running == .analyze { loading("Looking for heavy locations…") } else {
                Text("Nothing unusual found").foregroundStyle(.secondary).font(.callout)
            }
        } else {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(insights) { entry in
                    Button { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: entry.cleanable ? "sparkles" : "exclamationmark.circle")
                                .foregroundStyle(entry.cleanable ? Color.green : Theme.warning)
                                .accessibilityHidden(true)
                            Text(entry.name).lineLimit(1)
                            Spacer()
                            Text(entry.sizeLabel).monospacedDigit().foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(entry.name), \(entry.sizeLabel)\(entry.cleanable ? ", cleanable" : "")")
                    .help(entry.path)
                }
            }
        }
    }

    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func loading(_ text: String) -> some View {
        HStack(spacing: 6) { ProgressView().controlSize(.small); Text(text).foregroundStyle(.secondary) }.font(.callout)
    }

    // MARK: Explorer

    private var explorerHeader: some View {
        HStack(spacing: 8) {
            Button { path = (path as NSString).deletingLastPathComponent } label: { Image(systemName: "chevron.left") }
                .disabled(path == "/")
                .accessibilityLabel("Up one folder")
                .help("Up one folder")
            breadcrumbs
            Spacer()
            if mole.loadingFolders.contains(path) {
                ProgressView().controlSize(.small).accessibilityLabel("Analyzing")
            } else {
                Button { Task { await mole.loadFolder(path, force: true) } } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Rescan folder")
                    .help("Rescan this folder")
            }
            Picker("View", selection: $style) {
                ForEach(ExplorerStyle.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var breadcrumbs: some View {
        let components = URL(fileURLWithPath: path).pathComponents
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(components.indices, id: \.self) { index in
                    if index > 0 { Image(systemName: "chevron.compact.right").foregroundStyle(.tertiary).accessibilityHidden(true) }
                    let target = NSString.path(withComponents: Array(components[...index]))
                    Button(index == 0 ? "Macintosh HD" : components[index]) { path = target }
                        .buttonStyle(.rondo)
                        .fontWeight(target == path ? .semibold : .regular)
                }
            }
        }
    }

    @ViewBuilder
    private var explorer: some View {
        if let analysis = mole.folders[path] {
            if analysis.measured.isEmpty {
                EmptyStateView(symbol: "folder", message: "Nothing to show here: the folder is empty or Rondo can't read it.")
            } else {
                switch style {
                case .map: TreemapView(entries: analysis.measured) { path = $0.path }
                case .list: FolderTreeList(analysis: analysis) { path = $0.path; style = .map }
                }
            }
        } else if let error = mole.folderErrors[path] {
            EmptyStateView(symbol: "exclamationmark.triangle", message: error, actionTitle: "Try Again") {
                Task { await mole.loadFolder(path, force: true) }
            }
        } else {
            VStack { Spacer(); loading("Analyzing \((path as NSString).lastPathComponent)…"); Spacer() }
                .frame(maxWidth: .infinity)
        }
    }
}
