#!/usr/bin/env swift
import CoreGraphics
import ImageIO
import CoreText
import AppKit
import Foundation

let openLines = [
    "█▀█ █▀█ █▀▀ █▄░█",
    "█▄█ █▀▀ ██▄ █░▀█"
]

let focusLines = [
    "█▀▀ █▀█ █▀▀ █░█ █▀",
    "█▀░ █▄█ █▄▄ █▄█ ▄█"
]

func makeIconImage(size: CGFloat) -> CGImage? {
    let cs = CGColorSpaceCreateDeviceRGB()
    let bpr = Int(size) * 4
    guard let ctx = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: bpr,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.setShouldAntialias(true)
    ctx.setAllowsAntialiasing(true)

    let inset = size * 0.06
    let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let radius = rect.width * 0.225
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(CGColor(gray: 0, alpha: 1))
    ctx.fillPath()

    let notchWidthChars: CGFloat = CGFloat(focusLines[0].count)
    let usableWidth = rect.width * 0.80
    let charWidth = usableWidth / notchWidthChars
    let fontSize = charWidth / 0.55
    let lineHeight = fontSize * 1.0

    let font = CTFontCreateWithName("Menlo-Bold" as CFString, fontSize, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: CGColor(gray: 1, alpha: 1)
    ]

    ctx.textMatrix = .identity

    let openBlockH = CGFloat(openLines.count) * lineHeight
    let notchBlockH = CGFloat(focusLines.count) * lineHeight
    let gap = lineHeight * 1.3
    let totalH = openBlockH + gap + notchBlockH

    let blockBottom = rect.midY - totalH / 2
    let notchTop = blockBottom
    let openTop = blockBottom + notchBlockH + gap

    func draw(lines: [String], topY: CGFloat) {
        for (i, line) in lines.enumerated() {
            let attr = NSAttributedString(string: line, attributes: attrs)
            let ctLine = CTLineCreateWithAttributedString(attr)
            let bounds = CTLineGetBoundsWithOptions(ctLine, .useOpticalBounds)
            let y = topY + CGFloat(lines.count - 1 - i) * lineHeight
            let x = rect.midX - bounds.width / 2 - bounds.minX
            ctx.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(ctLine, ctx)
        }
    }

    draw(lines: openLines, topY: openTop)
    draw(lines: focusLines, topY: notchTop)

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        throw NSError(domain: "icon", code: 1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        throw NSError(domain: "icon", code: 2)
    }
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let iconsetDir = projectRoot.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for (name, px) in sizes {
    guard let img = makeIconImage(size: CGFloat(px)) else { continue }
    let url = iconsetDir.appendingPathComponent("\(name).png")
    try writePNG(img, to: url)
    print("wrote \(url.lastPathComponent)")
}

let icnsURL = projectRoot.appendingPathComponent("AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()
print("wrote AppIcon.icns")

let heroURL = projectRoot.appendingPathComponent("assets/icon-hero.png")
try? FileManager.default.createDirectory(at: heroURL.deletingLastPathComponent(),
                                          withIntermediateDirectories: true)
if let img = makeIconImage(size: 1024) {
    try writePNG(img, to: heroURL)
    print("wrote assets/icon-hero.png")
}
