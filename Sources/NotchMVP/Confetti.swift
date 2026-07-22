import AppKit
import SwiftUI

private struct ActiveParticle: Identifiable {
    let id = UUID()
    let origin: CGPoint        // screen coords (bottom-up)
    let birthTime: Date
    let vx: CGFloat
    let vy: CGFloat            // positive = downward
    let rotation: CGFloat
    let color: Color
    let lifetime: TimeInterval
    let size: CGFloat
}

private final class ConfettiState: ObservableObject {
    @Published var particles: [ActiveParticle] = []

    func spawn(at origin: CGPoint, count: Int) {
        let now = Date()
        for _ in 0..<count {
            particles.append(ActiveParticle(
                origin: origin,
                birthTime: now,
                vx: .random(in: -280...280),
                // Negative = upward in canvas coords (y-down). Cannon launches
                // particles up, gravity pulls them back through the origin.
                vy: .random(in: -560 ... -320),
                rotation: .random(in: -12...12),
                color: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink].randomElement()!,
                lifetime: .random(in: 1.4...2.0),
                size: .random(in: 5...10)
            ))
        }
    }

    func prune(before cutoff: Date) {
        particles.removeAll { cutoff.timeIntervalSince($0.birthTime) > $0.lifetime }
    }
}

private struct ConfettiCanvas: View {
    @ObservedObject var state: ConfettiState
    let panelOrigin: CGPoint     // screen coords of panel bottom-left
    let panelHeight: CGFloat

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, _ in
                for p in state.particles {
                    let localT = context.date.timeIntervalSince(p.birthTime)
                    guard localT >= 0 && localT <= p.lifetime else { continue }
                    let dt = CGFloat(localT)
                    // Convert particle origin from screen (bottom-up) to canvas (top-down)
                    let baseX = p.origin.x - panelOrigin.x
                    let baseY = panelHeight - (p.origin.y - panelOrigin.y)
                    let x = baseX + p.vx * dt
                    let y = baseY + p.vy * dt + 900 * dt * dt
                    let progress = localT / p.lifetime
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
    private var state: ConfettiState?
    private var emissionTimer: Timer?
    private var pruneTimer: Timer?

    func present() {
        panel?.orderOut(nil)
        emissionTimer?.invalidate()
        pruneTimer?.invalidate()

        guard let screen = NSScreen.main else { return }
        let rect = screen.frame

        let panelState = ConfettiState()
        state = panelState

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

        let host = NSHostingView(rootView: ConfettiCanvas(
            state: panelState,
            panelOrigin: rect.origin,
            panelHeight: rect.height
        ))
        host.frame = p.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        p.contentView = host

        p.orderFrontRegardless()
        panel = p

        let emissionDuration: TimeInterval = 2.5
        let maxParticleLifetime: TimeInterval = 1.8
        let totalDuration = emissionDuration + maxParticleLifetime + 0.2
        let startTime = Date()

        emissionTimer = Timer.scheduledTimer(withTimeInterval: 0.045, repeats: true) { [weak self] timer in
            guard let self, let s = self.state else {
                timer.invalidate()
                return
            }
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > emissionDuration {
                timer.invalidate()
                return
            }
            let mouse = NSEvent.mouseLocation
            // Cannon-taper: emit more particles early, tapering off
            let progress = elapsed / emissionDuration
            let count = max(2, Int(9 * (1 - progress * 0.6)))
            s.spawn(at: mouse, count: count)
        }

        pruneTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.state?.prune(before: Date())
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) { [weak self] in
            self?.emissionTimer?.invalidate()
            self?.pruneTimer?.invalidate()
            self?.panel?.orderOut(nil)
            self?.panel = nil
            self?.state = nil
        }
    }
}
