import SwiftUI

struct DiskCleanPane: View {
    @Environment(MoleService.self) private var mole
    @Environment(PopoverState.self) private var popover
    @State private var checkID = 0

    var body: some View {
        Form {
            Section {
                DependencyRow(name: "mo", purpose: "Mole", install: MoleService.installCommand)
                    .id(checkID)
                HStack {
                    Button("Check Again") {
                        mole.refreshInstallation()
                        checkID += 1
                    }
                    Link("About Mole", destination: MoleService.homepage)
                }
            } header: {
                Text("Mole")
            } footer: {
                Text("Disk analysis and Disk Clean are powered by Mole, a free command-line tool. They stay off until it's installed.")
            }
            Section {
                Button { popover.open(.diskClean) } label: { Label("Open Disk Clean…", systemImage: "trash") }
                    .pointerStyle(.link)
            }
            Section("Safety") {
                Label("Every cleanup starts with a preview you confirm", systemImage: "eye")
                Label("Mole deletes permanently and empties the Trash, unless protected in ~/.config/mole/whitelist",
                      systemImage: "exclamationmark.triangle")
                Label("Steps that need an administrator password are skipped", systemImage: "lock.shield")
            }
            Section("Permissions") {
                PermissionStatusRow(title: "Full Disk Access", detail: "Optional: lets Mole read the Trash and other protected folders",
                                    isGranted: Self.hasFullDiskAccess, pane: .fullDiskAccess)
            }
        }
        .formStyle(.grouped)
    }

    /// The Trash is only listable with Full Disk Access; Mole runs as Rondo's child, so it inherits Rondo's grant.
    private static var hasFullDiskAccess: Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: NSHomeDirectory() + "/.Trash")) != nil
    }
}
