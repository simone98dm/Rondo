import AppKit
import Charts
import SwiftUI

/// Categorical palette for size charts: eight hues validated for colour-blind separation, each with
/// its own light and dark step. Assigned in fixed order; anything past eight folds into a neutral "Others".
enum ChartPalette {
    static let slots: [Color] = [
        ("2a78d6", "3987e5"), ("eb6834", "d95926"), ("1baf7a", "199e70"), ("eda100", "c98500"),
        ("e87ba4", "d55181"), ("008300", "008300"), ("6250d6", "9085e9"), ("e34948", "e66767"),
    ].map { dynamic(light: $0.0, dark: $0.1) }

    static let other = dynamic(light: "a3a29d", dark: "5f5e5a")

    static func color(at index: Int) -> Color { index < slots.count ? slots[index] : other }

    private static func dynamic(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            hex(appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)
        })
    }

    private static func hex(_ value: String) -> NSColor {
        let rgb = Int(value, radix: 16) ?? 0
        return NSColor(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                       blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

/// One slice of a donut.
nonisolated struct SizeSlice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let bytes: Int64
    /// Palette slot, nil for "Others".
    let slot: Int?

    static let othersID = "__others__"

    /// The largest `maxSlices` items get a colour each; the rest are summed into "Others".
    static func top(_ items: [(id: String, name: String, bytes: Int64)], maxSlices: Int = 7) -> [SizeSlice] {
        let sorted = items.filter { $0.bytes > 0 }.sorted { $0.bytes > $1.bytes }
        var slices = sorted.prefix(maxSlices).enumerated().map { index, item in
            SizeSlice(id: item.id, name: item.name, bytes: item.bytes, slot: index)
        }
        let rest = sorted.dropFirst(maxSlices).reduce(Int64(0)) { $0 + $1.bytes }
        if rest > 0 { slices.append(SizeSlice(id: othersID, name: "Others", bytes: rest, slot: nil)) }
        return slices
    }

    /// The slice under a fraction (0…1) of the way round the ring, clockwise from 12 o'clock.
    static func slice(at fraction: Double, in slices: [SizeSlice]) -> SizeSlice? {
        let total = Double(slices.reduce(Int64(0)) { $0 + $1.bytes })
        guard total > 0 else { return nil }
        var start = 0.0
        for slice in slices {
            start += Double(slice.bytes) / total
            if fraction <= start { return slice }
        }
        return slices.last
    }
}

extension SizeSlice {
    var color: Color { slot.map(ChartPalette.color(at:)) ?? ChartPalette.other }
}

/// Donut with a hover read-out in the hole and an optional legend that highlights its slice.
struct SizeDonut: View {
    let slices: [SizeSlice]
    var diameter: CGFloat = 140
    var showsLegend = true
    var legendLimit = 8
    var showsPercent = true
    @State private var highlighted: String?

    private var total: Int64 { slices.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ring.frame(width: diameter, height: diameter)
            if showsLegend { legend }
        }
    }

    private var ring: some View {
        Chart(slices) { slice in
            SectorMark(angle: .value("Size", slice.bytes), innerRadius: .ratio(0.64), angularInset: 1)
                .cornerRadius(3)
                .foregroundStyle(slice.color)
                .opacity(highlighted == nil || highlighted == slice.id ? 1 : 0.3)
                .accessibilityLabel(slice.name)
                .accessibilityValue(formatBytes(slice.bytes, style: .file))
        }
        .chartLegend(.hidden)
        .chartOverlay { _ in
            GeometryReader { geo in
                Color.clear.contentShape(Circle())
                    .onContinuousHover { phase in
                        guard case .active(let point) = phase else { highlighted = nil; return }
                        highlighted = sliceID(at: point, in: geo.size)
                    }
            }
        }
        .overlay { centerLabel.allowsHitTesting(false) }
        .animation(.easeOut(duration: 0.15), value: highlighted)
    }

    private var centerLabel: some View {
        let slice = slices.first { $0.id == highlighted }
        return VStack(spacing: 1) {
            Text(formatBytes(slice?.bytes ?? total, style: .file))
                .font(.system(size: diameter * 0.12, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(slice?.name ?? "Total")
                .font(.system(size: max(9, diameter * 0.075)))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let slice, total > 0 {
                Text(percent(slice.bytes)).font(.system(size: max(9, diameter * 0.07))).foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter * 0.56)
        .accessibilityHidden(true)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(slices.prefix(legendLimit)) { slice in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(slice.color).frame(width: 9, height: 9)
                    Text(slice.name).lineLimit(1).truncationMode(.middle).layoutPriority(1)
                    Spacer(minLength: 6)
                    Text(formatBytes(slice.bytes, style: .file)).monospacedDigit().foregroundStyle(showsPercent ? .primary : .secondary)
                    if showsPercent {
                        Text(percent(slice.bytes)).monospacedDigit().foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
                    }
                }
                .font(.caption)
                .padding(.vertical, 1)
                .contentShape(Rectangle())
                .opacity(highlighted == nil || highlighted == slice.id ? 1 : 0.5)
                .onHover { highlighted = $0 ? slice.id : nil }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: 380)
    }

    private func percent(_ bytes: Int64) -> String {
        total > 0 ? (Double(bytes) / Double(total)).formatted(.percent.precision(.fractionLength(0))) : ""
    }

    /// Angle of the pointer → slice, only over the ring itself.
    private func sliceID(at point: CGPoint, in size: CGSize) -> String? {
        let dx = point.x - size.width / 2, dy = point.y - size.height / 2
        let radius = min(size.width, size.height) / 2
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance <= radius, distance >= radius * 0.5 else { return nil }
        var angle = atan2(dx, -dy) // 0 at 12 o'clock, clockwise (y grows downwards)
        if angle < 0 { angle += 2 * .pi }
        return SizeSlice.slice(at: angle / (2 * .pi), in: slices)?.id
    }
}

/// Used/free bar for a volume.
struct CapacityBar: View {
    let used: Int64
    let total: Int64

    var body: some View {
        let fraction = total > 0 ? min(1, Double(used) / Double(total)) : 0
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(Theme.color(for: UsageLevel(fraction: fraction))).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 10)
            HStack {
                Text("\(formatBytes(used, style: .file)) used")
                Spacer()
                Text("\(formatBytes(max(0, total - used), style: .file)) free").fontWeight(.semibold)
            }
            .font(.caption.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Disk space")
        .accessibilityValue("\(formatBytes(max(0, total - used), style: .file)) free of \(formatBytes(total, style: .file))")
    }
}
