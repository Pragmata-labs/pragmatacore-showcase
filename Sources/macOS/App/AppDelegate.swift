import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupMainMenu()

        let content = MacConfiguratorView().splashScreen()
        let controller = NSHostingController(rootView: content)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "PragmataCore Configurator"
        win.minSize = NSSize(width: 900, height: 600)
        win.contentViewController = controller
        win.center()
        win.makeKeyAndOrderFront(nil)
        self.window = win
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // Ensures Cmd+Q reaches NSApp even when the Metal (Filament) view holds keyboard focus.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(
            title: "Quit PragmataCore",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        NSApp.mainMenu = mainMenu
    }
}
