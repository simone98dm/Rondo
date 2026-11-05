import SwiftUI

/// Mole's text report as grouped rows: section headings with their items, notes first.
struct MoleReportView: View {
    let report: MoleReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(report.notes, id: \.self) { MoleItemRow(item: $0) }
            ForEach(report.sections) { section in
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.title).font(.subheadline.weight(.semibold))
                    ForEach(section.items, id: \.self) { MoleItemRow(item: $0) }
                }
            }
        }
    }
}

struct MoleItemRow: View {
    let item: MoleReport.Item

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(color).accessibilityHidden(true)
            Text(item.text).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch item.kind {
        case .done: "checkmark.circle"
        case .pending: "circle"
        case .skipped: "exclamationmark.circle"
        case .hint: "info.circle"
        case .other: "smallcircle.filled.circle"
        }
    }

    private var color: Color {
        switch item.kind {
        case .done: .green
        case .skipped: Theme.warning
        default: .secondary
        }
    }
}

/// Mole's summary lines ("Potential space: 3.07GB · 147 items") as a callout.
struct MoleSummaryView: View {
    let lines: [String]

    var body: some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines, id: \.self) { Text($0).font(.callout.monospacedDigit()) }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.cornerRadius).fill(.quaternary))
            .accessibilityElement(children: .combine)
        }
    }
}
