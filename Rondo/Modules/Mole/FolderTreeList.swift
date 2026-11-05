import AppKit
import SwiftUI

/// Expandable tree of a folder: each level is analyzed by Mole when it's first opened.
struct FolderTreeList: View {
    let analysis: MoleAnalysis
    let onOpen: (MoleAnalysis.Entry) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let entries = analysis.measured
                let total = entries.reduce(Int64(0)) { $0 + $1.size }
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    FolderTreeRow(entry: entry, depth: 0, parentSize: total, color: ChartPalette.color(at: index), onOpen: onOpen)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct FolderTreeRow: View {
    @Environment(MoleService.self) private var mole
    let entry: MoleAnalysis.Entry
    let depth: Int
    let parentSize: Int64
    let color: Color
    let onOpen: (MoleAnalysis.Entry) -> Void
    @State private var isExpanded = false

    private static let childLimit = 60
    private static let indent: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row
            if isExpanded { children }
        }
    }

    private var row: some View {
        HStack(spacing: 8) {
            Button { toggle() } label: {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 14)
                    .opacity(entry.isDir ? 1 : 0)
            }
            .buttonStyle(.plain)
            .disabled(!entry.isDir)
            .accessibilityLabel(isExpanded ? "Collapse \(entry.name)" : "Expand \(entry.name)")
            .accessibilityHidden(!entry.isDir)
            Image(systemName: entry.isDir ? "folder.fill" : "doc.fill").foregroundStyle(color).accessibilityHidden(true)
            Text(entry.name).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 12)
            shareBar
            Text(entry.sizeLabel).monospacedDigit().frame(width: 90, alignment: .trailing)
            Text(share.formatted(.percent.precision(.fractionLength(1)))).monospacedDigit().foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
        .font(.callout)
        .padding(.leading, CGFloat(depth) * Self.indent + 6)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if entry.isDir { onOpen(entry) } }
        .contextMenu {
            if entry.isDir { Button("Open in Map") { onOpen(entry) } }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
        }
        .help(entry.path)
    }

    private var share: Double { parentSize > 0 ? Double(entry.size) / Double(parentSize) : 0 }

    private var shareBar: some View {
        Capsule().fill(.quaternary)
            .overlay(alignment: .leading) {
                GeometryReader { geo in Capsule().fill(color).frame(width: max(2, geo.size.width * share)) }
            }
            .frame(width: 110, height: 6)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var children: some View {
        if let analysis = mole.folders[entry.path] {
            let entries = analysis.measured
            let total = entries.reduce(Int64(0)) { $0 + $1.size }
            ForEach(entries.prefix(Self.childLimit)) { child in
                FolderTreeRow(entry: child, depth: depth + 1, parentSize: total, color: color, onOpen: onOpen)
            }
            if entries.isEmpty { note("Empty or not readable") }
        } else if let error = mole.folderErrors[entry.path] {
            note(error)
        } else {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Analyzing…").foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.leading, CGFloat(depth + 1) * Self.indent + 28)
            .padding(.vertical, 4)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
            .padding(.leading, CGFloat(depth + 1) * Self.indent + 28)
            .padding(.vertical, 4)
    }

    private func toggle() {
        guard entry.isDir else { return }
        isExpanded.toggle()
        if isExpanded { Task { await mole.loadFolder(entry.path) } }
    }
}
