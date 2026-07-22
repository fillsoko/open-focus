import AppKit
import SwiftUI
import CoreGraphics

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    private lazy var whiteCaretEditor: NSTextView = {
        let tv = NSTextView()
        tv.isFieldEditor = true
        tv.insertionPointColor = .white
        tv.drawsBackground = false
        return tv
    }()

    override func fieldEditor(_ createFlag: Bool, for object: Any?) -> NSText? {
        return whiteCaretEditor
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let session = FocusSession()
    private let draft = DraftStore()
    private let confetti = ConfettiPresenter()

    private var notchPanel: NotchPanel?
    private var aboutWindow: NSWindow?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        session.onFinish = { [weak self] in
            self?.updateStatusTitle()
            self?.hideNotchPanel()
        }
        session.onAdvance = { [weak self] in self?.updateStatusTitle() }

        setupStatusItem()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        guard notchPanel != nil else { return }
        showNotchPanel()
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "OpenFocus")
        }
        let menu = NSMenu()
        let start = NSMenuItem(title: "Start Focus", action: #selector(toggleFocus), keyEquivalent: "n")
        start.target = self
        menu.addItem(start)

        let about = NSMenuItem(title: "About OpenFocus", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleFocus) {
            menuItem.title = session.isRunning ? "Stop Focus" : "Start Focus"
        }
        return true
    }

    @objc private func toggleFocus() {
        if session.isRunning {
            session.stop()
        } else {
            showNotchPanel()
        }
    }

    private func updateStatusTitle() {
        guard let button = statusItem?.button else { return }
        if let t = session.current {
            button.title = " " + t.title.prefix(24)
        } else {
            button.title = ""
        }
    }

    // MARK: - About window

    @objc private func showAbout() {
        if let w = aboutWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: AboutView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "OpenFocus"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 440))
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow = window
    }

    // MARK: - Notch overlay

    private func builtInScreen() -> NSScreen? {
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let displayID = CGDirectDisplayID(number.uint32Value)
            if CGDisplayIsBuiltin(displayID) != 0 {
                return screen
            }
        }
        return NSScreen.main
    }

    private func notchMetrics(for screen: NSScreen) -> (width: CGFloat, height: CGFloat) {
        let h = screen.safeAreaInsets.top
        if h > 0 {
            let leftW = screen.auxiliaryTopLeftArea?.width ?? 0
            let rightW = screen.auxiliaryTopRightArea?.width ?? 0
            let w = max(180, screen.frame.width - leftW - rightW)
            return (w, h)
        }
        return (200, 28)
    }

    private func showNotchPanel() {
        notchPanel?.orderOut(nil)
        notchPanel = nil
        guard let screen = builtInScreen() else { return }
        let metrics = notchMetrics(for: screen)
        let panelWidth: CGFloat = 700
        let panelHeight: CGFloat = 500
        let frame = screen.frame
        let originX = frame.midX - panelWidth / 2
        let originY = frame.maxY - panelHeight

        let panel = NotchPanel(
            contentRect: NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false

        let view = NotchView(
            session: session,
            draft: draft,
            notchWidth: metrics.width,
            notchHeight: metrics.height,
            onDone: { [weak self] in
                self?.confetti.present()
                self?.session.done()
            },
            onStop: { [weak self] in self?.session.stop() }
        )
        let host = NSHostingView(rootView: view)
        host.frame = panel.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        panel.orderFrontRegardless()
        notchPanel = panel
    }

    private func hideNotchPanel() {
        notchPanel?.orderOut(nil)
        notchPanel = nil
    }
}
