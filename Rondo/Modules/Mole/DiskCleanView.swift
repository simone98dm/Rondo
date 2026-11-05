import SwiftUI

/// Disk Clean window: an overview of the disk, then Mole's clean and optimize (each preview → confirm → run).
/// Until Mole is installed it shows the setup steps instead.
struct DiskCleanView: View {
    @Environment(MoleService.self) private var mole
    /// `--open-disk-clean=clean` (or `optimize`) opens on that mode, for screenshots.
    @State private var mode = Mode(rawValue: AppEnvironment.value(for: "--open-disk-clean")?.capitalized ?? "") ?? .overview

    enum Mode: String, CaseIterable, Identifiable {
        case overview = "Overview", clean = "Clean", optimize = "Optimize"
        var id: Self { self }
    }

    var body: some View {
        content.frame(minWidth: 820, minHeight: 640)
    }

    @ViewBuilder
    private var content: some View {
        if mole.isInstalled {
            VStack(spacing: 0) {
                header
                if let error = mole.errorMessage { errorBanner(error) }
                Divider()
                if mode == .overview {
                    MoleOverviewView() // fills the window: the map follows its size
                } else {
                    ScrollView {
                        Group {
                            if mode == .clean { MoleCleanView() } else { MoleOptimizeView() }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        } else {
            MoleSetupView()
        }
    }

    private var header: some View {
        HStack {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Spacer()
            if let running = mole.running {
                ProgressView().controlSize(.small).accessibilityHidden(true)
                Text(running.progressTitle).font(.callout).foregroundStyle(.secondary)
            }
            Link("Powered by Mole", destination: MoleService.homepage).font(.caption)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warning).accessibilityHidden(true)
            Text(message).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Dismiss") { mole.dismissError() }.buttonStyle(.rondo)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Theme.warning.opacity(0.12))
    }
}
