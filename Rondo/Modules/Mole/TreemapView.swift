import AppKit
import SwiftUI

/// Squarified treemap layout (Bruls, Huizing, van Wijk): tiles in size order, rows chosen to keep
/// tiles as close to square as possible.
nonisolated enum Treemap {
    struct Tile: Equatable {
        let index: Int
        let rect: CGRect
    }

    /// Lays out `values` (any order; zero/negative are skipped) inside `rect`. `index` points back into `values`.
    static func layout(_ values: [Double], in rect: CGRect) -> [Tile] {
        let items = values.enumerated().filter { $0.element > 0 }.sorted { $0.element > $1.element }
        let total = items.reduce(0) { $0 + $1.element }
        guard total > 0, rect.width > 0, rect.height > 0 else { return [] }
        let scale = Double(rect.width * rect.height) / total
        var remaining = items.map { (index: $0.offset, area: $0.element * scale) }[...]
        var free = rect
        var row: [(index: Int, area: Double)] = []
        var tiles: [Tile] = []

        while let next = remaining.first {
            let side = Double(min(free.width, free.height))
            if row.isEmpty || worst(row + [next], side: side) <= worst(row, side: side) {
                row.append(next)
                remaining.removeFirst()
            } else {
                place(row, in: &free, into: &tiles)
                row = []
            }
        }
        if !row.isEmpty { place(row, in: &free, into: &tiles) }
        return tiles
    }

    /// Worst aspect ratio of a row laid along a side of length `side`.
    private static func worst(_ row: [(index: Int, area: Double)], side: Double) -> Double {
        let sum = row.reduce(0) { $0 + $1.area }
        guard sum > 0, side > 0 else { return .infinity }
        return row.map { max(side * side * $0.area / (sum * sum), sum * sum / (side * side * $0.area)) }.max() ?? .infinity
    }

    /// Places a row along the shorter side of `free` and shrinks `free` by it.
    private static func place(_ row: [(index: Int, area: Double)], in free: inout CGRect, into tiles: inout [Tile]) {
        let sum = row.reduce(0) { $0 + $1.area }
        if free.width >= free.height {
            let width = CGFloat(sum) / free.height
            var y = free.minY
            for item in row {
                let height = CGFloat(item.area) / width
                tiles.append(Tile(index: item.index, rect: CGRect(x: free.minX, y: y, width: width, height: height)))
                y += height
            }
            free = CGRect(x: free.minX + width, y: free.minY, width: max(0, free.width - width), height: free.height)
        } else {
            let height = CGFloat(sum) / free.width
            var x = free.minX
            for item in row {
                let width = CGFloat(item.area) / height
                tiles.append(Tile(index: item.index, rect: CGRect(x: x, y: free.minY, width: width, height: height)))
                x += width
            }
            free = CGRect(x: free.minX, y: free.minY + height, width: free.width, height: max(0, free.height - height))
        }
    }
}

/// DirStat-style map of a folder: one shaded tile per item, area = size. Hover shows a label,
/// clicking a folder opens it.
struct TreemapView: View {
    let entries: [MoleAnalysis.Entry]
    let onOpen: (MoleAnalysis.Entry) -> Void
    @State private var hovered: Int?
    @State private var pointer: CGPoint = .zero

    private static let gap: CGFloat = 2
    private var total: Int64 { entries.reduce(0) { $0 + $1.size } }

    var body: some View {
        GeometryReader { geo in
            let tiles = Treemap.layout(entries.map { Double($0.size) }, in: CGRect(origin: .zero, size: geo.size))
            ZStack(alignment: .topLeading) {
                ForEach(tiles, id: \.index) { tile in
                    tileView(entries[tile.index], index: tile.index, rect: tile.rect)
                }
                if let hovered, entries.indices.contains(hovered) {
                    tooltip(entries[hovered], in: geo.size)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard case .active(let point) = phase else { hovered = nil; return }
                pointer = point
                hovered = tiles.first { $0.rect.contains(point) }?.index
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Folder map")
    }

    private func tileView(_ entry: MoleAnalysis.Entry, index: Int, rect: CGRect) -> some View {
        let color = ChartPalette.color(at: index)
        let inset = rect.insetBy(dx: Self.gap / 2, dy: Self.gap / 2)
        return RoundedRectangle(cornerRadius: min(4, inset.width / 4, inset.height / 4))
            .fill(color.gradient) // cushion shading, like DirStat's
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(hovered == index ? 0.9 : 0), lineWidth: 2))
            .overlay(alignment: .topLeading) { tileLabel(entry, size: inset.size) }
            .brightness(hovered == index ? 0.08 : 0)
            .frame(width: max(0, inset.width), height: max(0, inset.height))
            .position(x: inset.midX, y: inset.midY)
            .onTapGesture { if entry.isDir { onOpen(entry) } }
            .contextMenu {
                if entry.isDir { Button("Open") { onOpen(entry) } }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
            }
            .accessibilityElement()
            .accessibilityLabel("\(entry.name), \(entry.sizeLabel)")
            .accessibilityAddTraits(entry.isDir ? .isButton : [])
            .accessibilityAction { if entry.isDir { onOpen(entry) } }
    }

    @ViewBuilder
    private func tileLabel(_ entry: MoleAnalysis.Entry, size: CGSize) -> some View {
        if size.width > 48, size.height > 32 {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name).font(.caption.weight(.semibold)).lineLimit(1).truncationMode(.tail)
                Text(formatBytes(entry.size, style: .file)).font(.caption2.monospacedDigit()).opacity(0.85)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
            .padding(6)
            .frame(maxWidth: size.width, alignment: .leading)
            .allowsHitTesting(false)
        }
    }

    private func tooltip(_ entry: MoleAnalysis.Entry, in size: CGSize) -> some View {
        let width: CGFloat = 230
        let x = min(max(pointer.x + 14, 4), size.width - width - 4)
        let y = pointer.y + 70 > size.height ? pointer.y - 66 : pointer.y + 16
        let share = total > 0 ? (Double(entry.size) / Double(total)).formatted(.percent.precision(.fractionLength(1))) : ""
        return VStack(alignment: .leading, spacing: 2) {
            Label(entry.name, systemImage: entry.isDir ? "folder.fill" : "doc.fill").font(.callout.weight(.semibold)).lineLimit(1)
            Text("\(entry.sizeLabel) · \(share)").font(.caption.monospacedDigit())
            Text(entry.isDir ? "Click to open · right-click for Finder" : entry.path)
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
        }
        .padding(8)
        .frame(width: width, alignment: .leading)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .offset(x: x, y: y)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
