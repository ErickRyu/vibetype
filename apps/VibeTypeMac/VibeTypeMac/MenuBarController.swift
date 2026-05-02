import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private var menu: NSMenu
    private let settingsWindow = SettingsWindowController()

    override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menu = NSMenu()
        super.init()
        configure()
    }

    private func configure() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "wand.and.stars",
                accessibilityDescription: "VibeType"
            )
            button.image?.isTemplate = true
        }

        menu.delegate = self

        let title = NSMenuItem(title: "VibeType", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        menu.addItem(.separator())

        let invoke = NSMenuItem(
            title: "AI 액션 실행…",
            action: #selector(invokePalette),
            keyEquivalent: " "
        )
        invoke.keyEquivalentModifierMask = [.option]
        invoke.target = self
        menu.addItem(invoke)

        menu.addItem(.separator())

        let preferences = NSMenuItem(
            title: "설정…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        preferences.keyEquivalentModifierMask = [.command]
        preferences.target = self
        menu.addItem(preferences)

        let quit = NSMenuItem(
            title: "VibeType 종료",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.keyEquivalentModifierMask = [.command]
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func invokePalette() {
        // Phase 4에서 ActionPaletteWindow 호출.
        NSSound.beep()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
