import AppKit
import SwiftUI
import CoreGraphics
import ServiceManagement

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let session = FocusSession()
    private let draft = DraftStore()
    private let confetti = ConfettiPresenter()

    private var notchPanel: NotchPanel?
    private var aboutWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var launchAtLoginItem: NSMenuItem?

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

        menu.addItem(.separator())

        let launch = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        menu.addItem(launch)
        launchAtLoginItem = launch

        let update = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        menu.addItem(update)

        let about = NSMenuItem(title: "About OpenFocus", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item

        refreshLaunchAtLoginState()
    }

    @objc private func checkForUpdates() {
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let apiURL = URL(string: "https://api.github.com/repos/fillsoko/open-focus/releases/latest")!
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.showAlert(title: "Update check failed",
                                   message: "Couldn't reach GitHub: \(error.localizedDescription)")
                }
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                DispatchQueue.main.async {
                    self.showAlert(title: "Update check failed",
                                   message: "Unexpected response from GitHub.")
                }
                return
            }
            if let msg = json["message"] as? String, json["tag_name"] == nil {
                DispatchQueue.main.async {
                    self.showAlert(title: "No release yet",
                                   message: "GitHub says: \(msg). Come back when the first release is published.")
                }
                return
            }
            guard let latestTag = json["tag_name"] as? String,
                  let htmlURLString = json["html_url"] as? String,
                  let htmlURL = URL(string: htmlURLString)
            else {
                DispatchQueue.main.async {
                    self.showAlert(title: "Update check failed",
                                   message: "Couldn't parse GitHub response.")
                }
                return
            }
            let latest = latestTag.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            DispatchQueue.main.async {
                if self.versionIsNewer(latest, than: bundleVersion) {
                    self.showUpdatePrompt(latest: latest, current: bundleVersion, releaseURL: htmlURL)
                } else {
                    self.showAlert(title: "You're up to date",
                                   message: "OpenFocus \(bundleVersion) is the latest version.")
                }
            }
        }.resume()
    }

    private func versionIsNewer(_ latest: String, than current: String) -> Bool {
        let a = latest.split(separator: ".").compactMap { Int($0) }
        let b = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(a.count, b.count) {
            let ai = i < a.count ? a[i] : 0
            let bi = i < b.count ? b[i] : 0
            if ai > bi { return true }
            if ai < bi { return false }
        }
        return false
    }

    private func showUpdatePrompt(latest: String, current: String, releaseURL: URL) {
        let alert = NSAlert()
        alert.messageText = "OpenFocus \(latest) available"
        alert.informativeText = "You're on \(current). Download the latest DMG from GitHub?"
        alert.addButton(withTitle: "Open Release Page")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(releaseURL)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func toggleLaunchAtLogin() {
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled {
                try svc.unregister()
            } else {
                try svc.register()
            }
        } catch {
            NSLog("OpenFocus: SMAppService toggle failed: \(error)")
        }
        refreshLaunchAtLoginState()
    }

    private func refreshLaunchAtLoginState() {
        launchAtLoginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
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
        panel.level = .statusBar
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
