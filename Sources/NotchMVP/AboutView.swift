import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            wordmark
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Focus on the Big 5 things that matter today.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)

            Divider().overlay(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 10) {
                explanation("Start Focus",
                            "Menu bar → Start Focus. The input drops down from your notch. Row 1 is focused, ready to type.")
                explanation("Add up to 5 tasks",
                            "Type task, Tab to time chips, ← → to pick 5/10/15/30/60, or type a number (1 → 10, 15).")
                explanation("Enter flow",
                            "Enter in text jumps to time chips. Enter on a time chip confirms and moves to next row. Enter on row 5 time chip starts.")
                explanation("Arrow keys",
                            "↑ ↓ move between rows. → at end of text jumps to time. ← on 5 jumps back to text. ↑ ↓ in time cycle time chips across rows.")
                explanation("Notch takes over",
                            "Your current task, blinking dot and countdown live in the notch. Click ✓ to complete — confetti cannon from your cursor.")
                explanation("Stop Focus",
                            "Menu bar → Stop Focus. Ends the session, hides the notch.")
                explanation("Launch at Login · Check for Updates",
                            "In the menu bar. Auto-update via GitHub Releases.")
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Text("OPENFOCUS · v0.1")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(28)
        .frame(width: 560, height: 500)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private var wordmark: some View {
        let lines = [
            " ██████╗ ██████╗ ███████╗███╗   ██╗███████╗ ██████╗  ██████╗██╗   ██╗███████╗",
            "██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██╔═══██╗██╔════╝██║   ██║██╔════╝",
            "██║   ██║██████╔╝█████╗  ██╔██╗ ██║█████╗  ██║   ██║██║     ██║   ██║███████╗",
            "██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██╔══╝  ██║   ██║██║     ██║   ██║╚════██║",
            "╚██████╔╝██║     ███████╗██║ ╚████║██║     ╚██████╔╝╚██████╗╚██████╔╝███████║",
            " ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝╚═╝      ╚═════╝  ╚═════╝ ╚═════╝ ╚══════╝"
        ].joined(separator: "\n")
        return Text(lines)
            .font(.system(size: 5, weight: .regular, design: .monospaced))
            .foregroundStyle(.white)
            .lineSpacing(0)
            .fixedSize()
    }

    private func explanation(_ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("→")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 12, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
