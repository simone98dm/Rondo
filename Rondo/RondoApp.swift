// Rondo/RondoApp.swift
import SwiftUI

@main
struct RondoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        // placeholder scene for a menu bar app; Rondo's real Settings is its own window (AppDelegate)
        Settings { }
            .commands {
                // the built-in "Settings… ⌘," would open the empty scene above
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { delegate.showSettings() }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}
