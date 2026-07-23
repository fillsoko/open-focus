#!/usr/bin/env swift
import CoreGraphics
import ImageIO
import CoreText
import AppKit
import Foundation

let width: CGFloat = 640
let height: CGFloat = 400

func makeBackground() -> CGImage? {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: Int(width),
        height: Int(height),
        bitsPerComponent: 8,
        bytesPerRow: Int(width) * 4,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.setShouldAntialias(true)
    ctx.setAllowsAntialiasing(true)

    // Solid dark background matching the app's aesthetic.
    ctx.setFillColor(CGColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Subtle top gradient for depth.
    if let grad = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1),
            CGColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1)
        ] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: 0, y: height),
                               end: CGPoint(x: 0, y: 0),
                               options: [])
    }

    // The Y coordinate system here is bottom-up (CoreGraphics).
    // Coordinates below are described from the top of the window for clarity,
    // and converted to CG coords via (height - y).

    func draw(_ string: String,
              atCenter cx: CGFloat,
              topY: CGFloat,
              size: CGFloat,
              weight: NSFont.Weight = .regular,
              color: NSColor = .white,
              tracking: CGFloat = 0) {
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        let attr = NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: color.cgColor,
            .kern: tracking
        ])
        let line = CTLineCreateWithAttributedString(attr)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        let x = cx - bounds.width / 2 - bounds.minX
        let y = height - topY - size
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
    }

    // Title
    draw("OpenFocus",
         atCenter: width / 2,
         topY: 34,
         size: 30,
         weight: .semibold,
         color: NSColor.white)

    draw("Focus on the Big 5 things that matter today.",
         atCenter: width / 2,
         topY: 72,
         size: 13,
         weight: .regular,
         color: NSColor(white: 1, alpha: 0.55))

    // Arrow between the two icon positions.
    // Icons live at Finder coords x ≈ 160 and x ≈ 480 (both at y ≈ 200 from top).
    // In our image, we'll draw an arrow slightly ABOVE the icons so it doesn't
    // sit under them, and put instructions BELOW.
    let arrowY = height - 205  // CG coords; matches ~y=195 from top
    let arrowStart = CGPoint(x: 235, y: arrowY)
    let arrowEnd = CGPoint(x: 405, y: arrowY)
    ctx.setStrokeColor(NSColor(white: 1, alpha: 0.35).cgColor)
    ctx.setLineWidth(2)
    ctx.setLineCap(.round)
    ctx.move(to: arrowStart)
    ctx.addLine(to: arrowEnd)
    ctx.strokePath()
    // Arrow head
    let headLen: CGFloat = 12
    ctx.move(to: arrowEnd)
    ctx.addLine(to: CGPoint(x: arrowEnd.x - headLen, y: arrowEnd.y + headLen * 0.6))
    ctx.move(to: arrowEnd)
    ctx.addLine(to: CGPoint(x: arrowEnd.x - headLen, y: arrowEnd.y - headLen * 0.6))
    ctx.strokePath()

    // Drag instruction below the icons
    draw("Drag OpenFocus to your Applications folder",
         atCenter: width / 2,
         topY: 300,
         size: 13,
         weight: .medium,
         color: NSColor(white: 1, alpha: 0.85))

    // Gatekeeper note
    draw("First launch: macOS will block this app because it isn't from the App Store.",
         atCenter: width / 2,
         topY: 335,
         size: 11,
         weight: .regular,
         color: NSColor(white: 1, alpha: 0.55))
    draw("Open System Settings → Privacy & Security → click \"Open Anyway\".",
         atCenter: width / 2,
         topY: 355,
         size: 11,
         weight: .regular,
         color: NSColor(white: 1, alpha: 0.55))

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        throw NSError(domain: "bg", code: 1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        throw NSError(domain: "bg", code: 2)
    }
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outDir = projectRoot.appendingPathComponent("assets")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let outURL = outDir.appendingPathComponent("dmg-background.png")

guard let img = makeBackground() else {
    fputs("failed to render background\n", stderr)
    exit(1)
}
try writePNG(img, to: outURL)
print("wrote \(outURL.path)")
