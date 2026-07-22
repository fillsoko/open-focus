import SwiftUI
import AppKit

@available(macOS 13.0, *)
@MainActor
enum ScreenshotGenerator {
    // 16:9 canvas
    private static let canvasWidth: CGFloat = 1920
    private static let canvasHeight: CGFloat = 1080

    // Physical notch dimensions (scaled up for hero screenshots)
    // Realistic notch dimensions; final image scaled up via uiScale for hero visibility
    private static let physicalNotchWidth: CGFloat = 200
    private static let physicalNotchHeight: CGFloat = 32
    private static let uiScale: CGFloat = 3.0

    static func run() {
        let out = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("assets/screenshots")
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let wallpaperURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("assets/wallpaper.jpg")
        guard let wallpaper = NSImage(contentsOf: wallpaperURL) else {
            print("wallpaper missing at \(wallpaperURL.path)")
            return
        }

        render(state: .inputEmpty, wallpaper: wallpaper,
               filename: "input-empty.png", to: out)
        render(state: .inputFilled, wallpaper: wallpaper,
               filename: "input-filled.png", to: out)
        render(state: .active, wallpaper: wallpaper,
               filename: "active.png", to: out)
        render(state: .confetti, wallpaper: wallpaper,
               filename: "confetti.png", to: out)
    }

    private enum State { case inputEmpty, inputFilled, active, confetti }

    private static func render(state: State,
                                wallpaper: NSImage,
                                filename: String,
                                to dir: URL) {
        let session = FocusSession()
        let draft = DraftStore()

        switch state {
        case .inputEmpty:
            break
        case .inputFilled:
            draft.tasks[0] = TaskItem(title: "Ship investor update", minutes: 30, priority: .high)
            draft.tasks[1] = TaskItem(title: "Review PR #142",       minutes: 15, priority: .medium)
            draft.tasks[2] = TaskItem(title: "Draft board deck",     minutes: 60, priority: .high)
            draft.tasks[3] = TaskItem(title: "Design review",        minutes: 10, priority: .medium)
            draft.tasks[4] = TaskItem(title: "Inbox zero",           minutes: 5,  priority: .low)
        case .active, .confetti:
            let tasks = [
                TaskItem(title: "Ship investor update", minutes: 45, priority: .high),
                TaskItem(title: "Review PR #142",       minutes: 25, priority: .medium),
                TaskItem(title: "Draft board deck",     minutes: 60, priority: .high)
            ]
            session.start(with: tasks)
            session.remaining = 24 * 60 + 47
        }

        let uiView = NotchView(
            session: session,
            draft: draft,
            notchWidth: physicalNotchWidth,
            notchHeight: physicalNotchHeight,
            onDone: {},
            onStop: {}
        )

        let uiWidth: CGFloat = 380
        let uiHeight: CGFloat = (state == .active || state == .confetti) ? 90 : 320
        let drawConfetti = (state == .confetti)

        let composed = compose(wallpaper: wallpaper,
                                uiViewBase: uiView,
                                uiBaseWidth: uiWidth,
                                uiBaseHeight: uiHeight,
                                uiWidth: uiWidth * uiScale,
                                uiHeight: uiHeight * uiScale,
                                drawConfetti: drawConfetti)
        guard let cg = composed else {
            print("compose failed for \(filename)")
            return
        }
        savePNG(cg, to: dir.appendingPathComponent(filename))
    }

    private static func compose<V: View>(wallpaper: NSImage,
                                          uiViewBase: V,
                                          uiBaseWidth: CGFloat,
                                          uiBaseHeight: CGFloat,
                                          uiWidth: CGFloat,
                                          uiHeight: CGFloat,
                                          drawConfetti: Bool = false) -> CGImage? {
        let scale: CGFloat = 1
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(canvasWidth * scale),
            height: Int(canvasHeight * scale),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setShouldAntialias(true)
        ctx.scaleBy(x: scale, y: scale)

        // Draw wallpaper filling the 16:9 canvas (aspect-fill)
        if let wpCG = wallpaper.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let wpW = CGFloat(wpCG.width)
            let wpH = CGFloat(wpCG.height)
            let canvasAspect = canvasWidth / canvasHeight
            let wpAspect = wpW / wpH
            var drawRect: CGRect
            if wpAspect > canvasAspect {
                let h = canvasHeight
                let w = h * wpAspect
                drawRect = CGRect(x: (canvasWidth - w) / 2, y: 0, width: w, height: h)
            } else {
                let w = canvasWidth
                let h = w / wpAspect
                drawRect = CGRect(x: 0, y: (canvasHeight - h) / 2, width: w, height: h)
            }
            ctx.draw(wpCG, in: drawRect)
        }

        // Render via NSHostingView + cacheDisplay so SF Symbols and TextField
        // prompts render via native AppKit (ImageRenderer garbles them in a
        // headless context).
        let host = NSHostingView(
            rootView: uiViewBase.frame(width: uiBaseWidth, height: uiBaseHeight)
        )
        host.frame = CGRect(x: 0, y: 0, width: uiBaseWidth, height: uiBaseHeight)
        host.needsLayout = true
        host.layoutSubtreeIfNeeded()

        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            return nil
        }
        bitmap.size = host.bounds.size
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let uiCG = bitmap.cgImage else { return nil }

        // Composite the UI at top center of canvas, top edge at y = canvasHeight (top)
        // In CG bitmap context, y=0 is bottom, so top = canvasHeight
        let uiX = (canvasWidth - uiWidth) / 2
        let uiY = canvasHeight - uiHeight
        ctx.draw(uiCG, in: CGRect(x: uiX, y: uiY, width: uiWidth, height: uiHeight))

        // Draw physical notch representation over the top of the UI
        // Scaled to match visual size of the UI in the composite
        let displayNotchW = physicalNotchWidth * uiScale
        let displayNotchH = physicalNotchHeight * uiScale
        let notchX = (canvasWidth - displayNotchW) / 2
        let notchY = canvasHeight - displayNotchH
        let notchRect = CGRect(x: notchX, y: notchY, width: displayNotchW, height: displayNotchH)
        let notchPath = CGMutablePath()
        let r = displayNotchH * 0.35
        // Rounded bottom corners, square top
        notchPath.move(to: CGPoint(x: notchRect.minX, y: notchRect.maxY))
        notchPath.addLine(to: CGPoint(x: notchRect.maxX, y: notchRect.maxY))
        notchPath.addLine(to: CGPoint(x: notchRect.maxX, y: notchRect.minY + r))
        notchPath.addQuadCurve(
            to: CGPoint(x: notchRect.maxX - r, y: notchRect.minY),
            control: CGPoint(x: notchRect.maxX, y: notchRect.minY)
        )
        notchPath.addLine(to: CGPoint(x: notchRect.minX + r, y: notchRect.minY))
        notchPath.addQuadCurve(
            to: CGPoint(x: notchRect.minX, y: notchRect.minY + r),
            control: CGPoint(x: notchRect.minX, y: notchRect.minY)
        )
        notchPath.closeSubpath()
        ctx.addPath(notchPath)
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fillPath()

        if drawConfetti {
            drawConfettiSnapshot(ctx: ctx)
        }

        return ctx.makeImage()
    }

    private static func drawConfettiSnapshot(ctx: CGContext) {
        // Fake cursor position in the lower-right third of the screen
        let cursor = CGPoint(x: canvasWidth * 0.62, y: canvasHeight * 0.42)

        // Draw a subtle cursor arrow at the origin
        let cursorPath = CGMutablePath()
        cursorPath.move(to: cursor)
        cursorPath.addLine(to: CGPoint(x: cursor.x + 26, y: cursor.y - 34))
        cursorPath.addLine(to: CGPoint(x: cursor.x + 10, y: cursor.y - 34))
        cursorPath.addLine(to: CGPoint(x: cursor.x + 18, y: cursor.y - 52))
        cursorPath.addLine(to: CGPoint(x: cursor.x + 10, y: cursor.y - 56))
        cursorPath.addLine(to: CGPoint(x: cursor.x + 2, y: cursor.y - 38))
        cursorPath.addLine(to: CGPoint(x: cursor.x - 12, y: cursor.y - 24))
        cursorPath.closeSubpath()
        ctx.addPath(cursorPath)
        ctx.setFillColor(CGColor(gray: 1, alpha: 0.95))
        ctx.fillPath()
        ctx.addPath(cursorPath)
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
        ctx.setLineWidth(3)
        ctx.strokePath()

        // Palette matching the app confetti
        let colors: [CGColor] = [
            CGColor(red: 0.93, green: 0.24, blue: 0.28, alpha: 1),
            CGColor(red: 0.98, green: 0.60, blue: 0.20, alpha: 1),
            CGColor(red: 0.98, green: 0.85, blue: 0.20, alpha: 1),
            CGColor(red: 0.30, green: 0.78, blue: 0.42, alpha: 1),
            CGColor(red: 0.30, green: 0.75, blue: 0.90, alpha: 1),
            CGColor(red: 0.30, green: 0.45, blue: 0.98, alpha: 1),
            CGColor(red: 0.60, green: 0.35, blue: 0.90, alpha: 1),
            CGColor(red: 0.95, green: 0.45, blue: 0.72, alpha: 1)
        ]

        // Snapshot the physics at elapsed ~= 0.55s
        let elapsed: Double = 0.55
        var rng = SystemRandomNumberGenerator()

        for _ in 0..<180 {
            let birth = Double.random(in: 0...(elapsed - 0.02), using: &rng)
            let localT = elapsed - birth
            if localT <= 0 { continue }
            let lifetime = Double.random(in: 1.4...2.0, using: &rng)
            if localT >= lifetime { continue }

            let vx = CGFloat.random(in: -280...280, using: &rng)
            let vy = CGFloat.random(in: -560 ... -320, using: &rng)
            let rotation = CGFloat.random(in: -12...12, using: &rng)
            let size = CGFloat.random(in: 8...16, using: &rng) * 1.6
            let color = colors.randomElement(using: &rng)!

            let dt = CGFloat(localT)
            let x = cursor.x + vx * dt
            let y = cursor.y - (vy * dt + 900 * dt * dt)  // canvas y-up
            let alpha = CGFloat(1.0 - localT / lifetime)

            ctx.saveGState()
            ctx.translateBy(x: x, y: y)
            ctx.rotate(by: CGFloat(rotation * dt))
            ctx.setAlpha(alpha)
            let rect = CGRect(x: -size / 2, y: -size / 3, width: size, height: size * 0.6)
            ctx.setFillColor(color)
            ctx.fill(rect)
            ctx.restoreGState()
        }
    }

    private static func savePNG(_ image: CGImage, to url: URL) {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
        print("wrote \(url.lastPathComponent)")
    }
}
