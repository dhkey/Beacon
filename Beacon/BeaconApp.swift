//
//  BeaconApp.swift
//  Beacon
//
//  Created by Denys Yazan on 22.08.2026.
//

import AppKit
import SwiftUI

@main
struct BeaconApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Beacon", systemImage: "sparkle.magnifyingglass") {
            Button("Open Beacon") {
                appDelegate.showLauncher()
            }
            .keyboardShortcut(" ", modifiers: [.command])

            SettingsLink {
                Text("Settings…")
            }
        }

        Settings {
            SettingsView(model: appDelegate.model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = LauncherModel()

    private var panelController: LauncherPanelController?
    private let hotKeyManager = GlobalHotKeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        panelController = LauncherPanelController(model: model)
        model.onDismiss = { [weak self] in
            self?.panelController?.hide()
        }
        hotKeyManager.onPressed = { [weak self] in
            self?.showLauncher()
        }
        applyShortcut(model.shortcut)
        model.onShortcutChanged = { [weak self] shortcut in
            self?.applyShortcut(shortcut)
        }

        model.loadApplications()
        showLauncher()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showLauncher() {
        panelController?.toggle()
    }

    private func applyShortcut(_ shortcut: KeyboardShortcut) {
        model.shortcutRegistrationError = hotKeyManager.register(shortcut: shortcut)
    }
}
