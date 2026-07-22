import AppKit

if CommandLine.arguments.contains("--render-screenshots") {
    if #available(macOS 13.0, *) {
        _ = NSApplication.shared
        MainActor.assumeIsolated {
            ScreenshotGenerator.run()
        }
        exit(0)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
