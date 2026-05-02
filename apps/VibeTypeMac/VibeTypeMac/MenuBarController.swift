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
        applyIcon(symbolName: "mic", template: true)

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

    func updateDictationState(_ state: DictationCoordinator.State) {
        switch state {
        case .idle:
            applyIcon(symbolName: "mic", template: true, accentColor: nil)
        case .recording:
            applyIcon(symbolName: "mic.fill", template: false, accentColor: .systemRed)
        case .transcribing(_):
            applyIcon(symbolName: "waveform", template: true, accentColor: nil)
        case .postProcessing:
            applyIcon(symbolName: "wand.and.stars", template: true, accentColor: nil)
        case .typing:
            applyIcon(symbolName: "keyboard", template: true, accentColor: nil)
        case .failed:
            applyIcon(symbolName: "exclamationmark.triangle", template: false, accentColor: .systemOrange)
        }
    }

    private func applyIcon(symbolName: String, template: Bool, accentColor: NSColor? = nil) {
        guard let button = statusItem.button else { return }
        let config: NSImage.SymbolConfiguration = {
            if let color = accentColor {
                return NSImage.SymbolConfiguration(paletteColors: [color])
            }
            return NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        }()
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "VibeType")?
            .withSymbolConfiguration(config)
        button.image = image
        button.image?.isTemplate = template
    }
}
