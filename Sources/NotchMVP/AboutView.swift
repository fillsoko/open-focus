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

            VStack(alignment: .leading, spacing: 12) {
                explanation("Start Focus",
                            "In the menu bar. Opens the input drop-down under your notch.")
                explanation("Add up to 5 tasks",
                            "Priority · title · minutes. Tab into times, ← → to pick 5/10/15/30/60.")
                explanation("Notch takes over",
                            "Your current task and countdown live under the notch. Nothing else in the way.")
                explanation("Click to complete",
                            "Tap the strip to mark the current task done. Confetti says hi.")
                explanation("Stop Focus",
                            "In the menu bar. Ends the session and hides the notch.")
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
        .frame(width: 520, height: 440)
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
