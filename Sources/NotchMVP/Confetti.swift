import AppKit
import SwiftUI

private struct Particle: Identifiable {
    let id = UUID()
    let vx: CGFloat
    let vy: CGFloat
    let rotation: CGFloat
    let color: Color
    let lifetime: TimeInterval
    let size: CGFloat

    init() {
        vx = .random(in: -220...220)
        vy = .random(in: 60...220)
        rotation = .random(in: -10...10)
        color = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink].randomElement()!
        lifetime = .random(in: 0.9...1.4)
        size = .random(in: 5...9)
    }
}

private struct ConfettiView: View {
    private let particles: [Particle] = (0..<60).map { _ in Particle() }
    private let start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            Canvas { ctx, size in
                let origin = CGPoint(x: size.width / 2, y: 4)
                for p in particles {
                    let progress = t / p.lifetime
                    guard progress >= 0 && progress <= 1 else { continue }
                    let dt = CGFloat(t)
                    let x = origin.x + p.vx * dt
                    let y = origin.y + p.vy * dt + 900 * dt * dt
                    let alpha = 1.0 - progress

                    ctx.drawLayer { sub in
                        sub.translateBy(x: x, y: y)
                        sub.rotate(by: .radians(p.rotation * dt))
                        sub.opacity = alpha
                        let rect = CGRect(
                            x: -p.size / 2,
                            y: -p.size / 3,
                            width: p.size,
                            height: p.size * 0.6
                        )
                        sub.fill(Path(rect), with: .color(p.color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private final class ConfettiPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class ConfettiPresenter {
    private var panel: ConfettiPanel?

    func present() {
        panel?.orderOut(nil)

        let mouse = NSEvent.mouseLocation
        let panelWidth: CGFloat = 360
        let panelHeight: CGFloat = 420
        let rect = NSRect(
            x: mouse.x - panelWidth / 2,
            y: mouse.y - panelHeight,
            width: panelWidth,
            height: panelHeight
        )

        let p = ConfettiPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        p.hasShadow = false
        p.backgroundColor = .clear
        p.isOpaque = false
        p.ignoresMouseEvents = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let host = NSHostingView(rootView: ConfettiView())
        host.frame = p.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        p.contentView = host

        p.orderFrontRegardless()
        panel = p

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel = nil
        }
    }
}
