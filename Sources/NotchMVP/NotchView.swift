import SwiftUI

struct NotchView: View {
    @ObservedObject var session: FocusSession
    @ObservedObject var draft: DraftStore
    var notchWidth: CGFloat
    var notchHeight: CGFloat
    var onDone: () -> Void
    var onStop: () -> Void

    @State private var blink: Bool = false
    @FocusState private var focused: RowField?

    enum RowField: Hashable {
        case text(UUID)
        case time(UUID)
    }

    private let minutePresets = [5, 10, 15, 30, 60]

    private var isRunning: Bool { session.isRunning }
    private var containerWidthValue: CGFloat { max(notchWidth + 160, 380) }
    private let titleCharLimit = 32

    private var cornerRadii: RectangleCornerRadii {
        .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()
                container.frame(width: containerWidthValue)
                Spacer()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { blink = true }
    }

    private var container: some View {
        VStack(spacing: 0) {
            if isRunning {
                activeStrip
            } else {
                Color.clear.frame(height: notchHeight)
                inputPanel
            }
        }
        .background(
            UnevenRoundedRectangle(cornerRadii: cornerRadii, style: .continuous)
                .fill(Color.black)
        )
        .clipShape(
            UnevenRoundedRectangle(cornerRadii: cornerRadii, style: .continuous)
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: isRunning)
    }

    // MARK: - Active strip

    private var dotColor: Color {
        session.remaining < 60 ? .red : .green
    }

    private var activeStrip: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 9, height: 9)
                .opacity(blink ? 1.0 : 0.25)
                .animation(
                    .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                    value: blink
                )
            Text(session.current?.title ?? "")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if session.totalPlanned > 0 {
                Text("\(session.currentIndex)/\(session.totalPlanned)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(FocusSession.format(session.remaining))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.top, notchHeight)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onTapGesture { onDone() }
    }

    // MARK: - Input mode

    private var inputPanel: some View {
        VStack(spacing: 0) {
            wordmark
            divider.padding(.top, 6)
            VStack(spacing: 0) {
                ForEach(Array($draft.tasks.enumerated()), id: \.element.id) { index, $task in
                    inputRow(index: index + 1, task: $task)
                }
            }
            divider
            startBar
        }
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
            .font(.system(size: 4, weight: .regular, design: .monospaced))
            .foregroundStyle(.white)
            .lineSpacing(0)
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func inputRow(index: Int, task: Binding<TaskItem>) -> some View {
        HStack(spacing: 10) {
            Text("\(index)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.32))
                .frame(width: 10, alignment: .leading)

            Menu {
                ForEach(Priority.allCases.reversed()) { p in
                    Button {
                        task.wrappedValue.priority = p
                    } label: {
                        Label(p.label, systemImage: p.symbol)
                    }
                }
            } label: {
                Image(systemName: task.wrappedValue.priority.symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(task.wrappedValue.priority.color)
                    .frame(width: 14)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            TextField(
                "",
                text: task.title,
                prompt: Text("Task #\(String(format: "%02d", index))")
                    .italic()
                    .foregroundColor(.white.opacity(0.3))
            )
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .tint(.white)
                .focused($focused, equals: .text(task.wrappedValue.id))
                .onSubmit { goToNextText(after: task.wrappedValue.id) }
                .onChange(of: task.wrappedValue.title) { newValue in
                    if newValue.count > titleCharLimit {
                        task.wrappedValue.title = String(newValue.prefix(titleCharLimit))
                    }
                }

            let taskID = task.wrappedValue.id
            HStack(spacing: 6) {
                ForEach(minutePresets, id: \.self) { m in
                    Button {
                        task.wrappedValue.minutes = m
                    } label: {
                        let selected = task.wrappedValue.minutes == m
                        Text("\(m)")
                            .font(.system(size: 12,
                                          weight: selected ? .bold : .regular,
                                          design: .monospaced))
                            .foregroundStyle(selected ? .white : .white.opacity(0.32))
                            .frame(minWidth: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(
                    focused == .time(taskID)
                        ? Color.white.opacity(0.08)
                        : Color.clear
                )
            )
            .focusable()
            .focused($focused, equals: .time(taskID))
            .onMoveCommand { direction in
                cycleMinutes(for: taskID, direction: direction)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture { focused = .text(task.wrappedValue.id) }
    }

    private func cycleMinutes(for id: UUID, direction: MoveCommandDirection) {
        guard let idx = draft.tasks.firstIndex(where: { $0.id == id }) else { return }
        let current = draft.tasks[idx].minutes
        let baseIdx = minutePresets.firstIndex(of: current) ?? 0
        switch direction {
        case .left:
            let newIdx = max(0, baseIdx - 1)
            draft.tasks[idx].minutes = minutePresets[newIdx]
        case .right:
            let newIdx = min(minutePresets.count - 1, baseIdx + 1)
            draft.tasks[idx].minutes = minutePresets[newIdx]
        default:
            break
        }
    }

    private func goToNextText(after id: UUID) {
        guard let idx = draft.tasks.firstIndex(where: { $0.id == id }) else { return }
        if idx + 1 < draft.tasks.count {
            focused = .text(draft.tasks[idx + 1].id)
        } else {
            focused = nil
        }
    }

private var startBar: some View {
        HStack {
            Text("\(filledCount)/\(DraftStore.maxTasks)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            Button {
                startSession()
            } label: {
                Text("Start")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(startEnabled ? Color.white.opacity(0.18) : Color.white.opacity(0.05),
                                in: Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!startEnabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private var filledCount: Int {
        draft.tasks.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    private var startEnabled: Bool { filledCount > 0 }

    private func startSession() {
        let cleaned = draft.tasks
            .map { TaskItem(title: $0.title.trimmingCharacters(in: .whitespaces),
                            minutes: $0.minutes,
                            priority: $0.priority) }
            .filter { !$0.title.isEmpty }
        guard !cleaned.isEmpty else { return }
        session.start(with: cleaned)
        draft.reset()
        focused = nil
    }

    // MARK: - Building blocks

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }

}
