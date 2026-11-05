import SwiftUI

/// `mo optimize`: preview the maintenance tasks, confirm, run.
struct MoleOptimizeView: View {
    @Environment(MoleService.self) private var mole
    @State private var isConfirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let run = mole.lastRun, run.action == .optimize {
                Label("Last optimized at \(run.date.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.seal")
                    .font(.subheadline.weight(.semibold))
                MoleSummaryView(lines: run.report.summary)
            }
            if let preview = mole.optimizePreview {
                MoleSummaryView(lines: preview.summary)
                MoleReportView(report: preview)
                HStack {
                    Button { Task { await mole.previewOptimize() } } label: { Label("Preview Again", systemImage: "arrow.clockwise") }
                        .disabled(mole.isBusy)
                    Spacer()
                    Button { isConfirming = true } label: { Label("Optimize…", systemImage: "wand.and.stars") }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(mole.isBusy)
                }
            } else {
                Text("Check system maintenance").font(.title3.weight(.semibold))
                Text("Mole checks databases, launch agents, login items and caches that macOS keeps, and lists what it would rebuild or tidy before doing anything.")
                    .foregroundStyle(.secondary)
                Button { Task { await mole.previewOptimize() } } label: { Label("Preview Optimize", systemImage: "magnifyingglass") }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(mole.isBusy)
            }
        }
        .confirmationDialog("Optimize with Mole?", isPresented: $isConfirming) {
            Button("Optimize") { Task { await mole.optimize() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mole applies the tasks from the preview. Tasks that need an administrator password are skipped.")
        }
    }
}
