import AppKit
import SpriteKit

final class GameView: SKView {
    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        let initialSize = NSSize(width: 1120, height: 740)
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        window.title = "Pixel Blaster"
        window.minSize = NSSize(width: 900, height: 600)
        window.center()
        window.acceptsMouseMovedEvents = true
        window.delegate = self

        let skView = GameView(frame: NSRect(origin: .zero, size: initialSize))
        skView.autoresizingMask = [.width, .height]
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60

        let scene = GameScene(size: initialSize)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)

        window.contentView = skView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(skView)

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Quit Pixel Blaster",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
