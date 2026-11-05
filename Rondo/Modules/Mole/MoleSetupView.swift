import SwiftUI

/// Shown until Mole is installed: what it is, the install command, and a re-check.
/// Rondo never installs it itself (same as the File Converter's ffmpeg/cwebp helpers).
struct MoleSetupView: View {
    @Environment(MoleService.self) private var mole
    @State private var checkID = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox").font(.system(size: 40)).foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text("Disk Clean uses Mole").font(.title2.weight(.bold))
                    Text("Mole is a free, open-source command-line tool that finds what uses your disk and cleans caches, logs and leftovers. Rondo shows its previews and runs it for you.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            step("1", "Install Mole", "Copy the command below and run it in Terminal (needs Homebrew).")
            DependencyRow(name: "mo", purpose: "Mole", install: MoleService.installCommand)
                .id(checkID) // re-runs the lookup on Check Again
            step("2", "Come back and check", "Disk analysis and cleanup turn on as soon as Rondo finds `mo`.")
            Divider()
            HStack {
                Link("About Mole", destination: MoleService.homepage)
                Spacer()
                Button("Check Again") {
                    mole.refreshInstallation()
                    checkID += 1
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { mole.hasOnboarded = true }
    }

    private func step(_ n: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(n).font(.headline).frame(width: 26, height: 26).background(Circle().fill(Color.accentColor.opacity(0.2)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.headline); Text(detail).foregroundStyle(.secondary) }
        }
        .accessibilityElement(children: .combine)
    }
}
