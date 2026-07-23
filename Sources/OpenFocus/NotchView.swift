import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    // Private in-process drag type for reordering task rows. Using a custom
    // type (rather than .text) prevents the dragged payload from being
    // interpreted as text if released over a TextField.
    static let openFocusTaskRow = UTType(exportedAs: "com.openfocus.taskrow")
}

struct NotchView: View {
    @ObservedObject var session: FocusSession
    @ObservedObject var draft: DraftStore
    var notchWidth: CGFloat
    var notchHeight: CGFloat
    var onDone: () -> Void
    var onStop: () -> Void

    @State private var blink: Bool = false
    @State private var keyMonitor: Any?
    @State private var timeBuffer: String = ""
    @State private var timeBufferAt: Date = .distantPast
    @State private var draggingID: UUID?
    @FocusState private var focused: RowField?

    enum RowField: Hashable {
        case text(UUID)
        case time(UUID)
    }

    struct NoFocusRing: ViewModifier {
        func body(content: Content) -> some View {
            if #available(macOS 14.0, *) {
                content.focusEffectDisabled()
            } else {
                content
            }
        }
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
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                blink = true
            }
            installKeyMonitor()
            if !isRunning, let first = draft.tasks.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    focused = .text(first.id)
                }
            }
        }
        .onDisappear { removeKeyMonitor() }
    }

    // MARK: - Keyboard shortcuts (arrow row-nav + typed minute selection)

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyDown(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let f = focused else { return false }
        switch f {
        case .text(let id):
            if event.keyCode == 48 { // tab: jump to time chips of same row
                snapToNearestPreset(for: id)
                focused = .time(id)
                return true
            }
            if event.keyCode == 124 { // right: at end of text → jump to time chips
                if isCursorAtTextEnd() {
                    snapToNearestPreset(for: id)
                    focused = .time(id)
                    return true
                }
                return false
            }
            if event.keyCode == 126 { focusPrevText(before: id); return true } // up
            if event.keyCode == 125 { focusNextText(after: id); return true }  // down
            return false

        case .time(let id):
            if event.keyCode == 123 { // left
                guard let idx = draft.tasks.firstIndex(where: { $0.id == id }) else { return true }
                if draft.tasks[idx].minutes == minutePresets.first {
                    focused = .text(id)
                } else {
                    cycleMinutes(for: id, direction: .left)
                }
                return true
            }
            if event.keyCode == 124 { // right: cycle up
                cycleMinutes(for: id, direction: .right)
                return true
            }
            if event.keyCode == 126 { // up: prev row's time (wrap)
                confirmMinutes(for: id)
                focused = .time(prevOrLastTaskID(from: id))
                return true
            }
            if event.keyCode == 36 { // return: last row starts session, else next text
                confirmMinutes(for: id)
                if isLastRow(id) {
                    startSession()
                } else if let next = nextTaskID(after: id) {
                    focused = .text(next)
                } else {
                    focused = nil
                }
                return true
            }
            if event.keyCode == 125 { // down: next row's time (wrap)
                confirmMinutes(for: id)
                focused = .time(nextOrFirstTaskID(from: id))
                return true
            }
            if event.keyCode == 48 { // tab: cycle to next row's text (wrap)
                confirmMinutes(for: id)
                if let next = nextTaskID(after: id) {
                    focused = .text(next)
                } else if let first = draft.tasks.first?.id {
                    focused = .text(first)
                }
                return true
            }
            if let chars = event.characters, chars.count == 1,
               let digit = chars.first, digit.isNumber {
                handleTypedDigit(String(digit), for: id)
                return true
            }
            return false
        }
    }

    private func isCursorAtTextEnd() -> Bool {
        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else { return false }
        let ns = editor.string as NSString
        return editor.selectedRange.location == ns.length && editor.selectedRange.length == 0
    }

    private func prevOrLastTaskID(from id: UUID) -> UUID {
        guard let idx = draft.tasks.firstIndex(where: { $0.id == id }) else { return id }
        if idx > 0 { return draft.tasks[idx - 1].id }
        return draft.tasks.last?.id ?? id
    }

    private func nextOrFirstTaskID(from id: UUID) -> UUID {
        guard let idx = draft.tasks.firstIndex(where: { $0.id == id }) else { return id }
        if idx + 1 < draft.tasks.count { return draft.tasks[idx + 1].id }
        return draft.tasks.first?.id ?? id
    }

    private func snapToNearestPreset(for id: UUID) {
        guard let idx = draft.tasks.firstIndex(where: { $0.id == id }) else { return }
        if !minutePresets.contains(draft.tasks[idx].minutes),
           let first = minutePresets.first {
            draft.tasks[idx].minutes = first
        }
    }

    private func confirmMinutes(for id: UUID) {
        guard let idx = draft.tasks.firstIndex(where: { $0.id == id }) else { return }
        draft.tasks[idx].minutesConfirmed = true
    }

    @ViewBuilder
    private func chipLabel(minute: Int, selected: Bool, blinking: Bool) -> some View {
        let baseText = Text("\(minute)")
            .font(.system(size: 12,
                          weight: selected ? .bold : .regular,
                          design: .monospaced))
            .foregroundStyle(selected ? .white : .white.opacity(0.32))
            .frame(minWidth: 14)
            .contentShape(Rectangle())

        if blinking {
            TimelineView(.animation(minimumInterval: 0.05)) { context in
                let t = context.date.timeIntervalSince1970
                let opacity = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * .pi / 0.5))
                baseText.opacity(opacity)
            }
        } else {
            baseText
        }
    }

    private func handleTypedDigit(_ digit: String, for id: UUID) {
        let now = Date()
        if now.timeIntervalSince(timeBufferAt) > 0.9 { timeBuffer = "" }
        timeBuffer += digit
        timeBufferAt = now

        var matches = minutePresets.filter { String($0).hasPrefix(timeBuffer) }
        if matches.isEmpty {
            timeBuffer = digit
            matches = minutePresets.filter { String($0).hasPrefix(timeBuffer) }
        }
        if let m = matches.first {
            setMinutes(for: id, to: m)
        } else {
            timeBuffer = ""
        }
    }

    private func setMinutes(for id: UUID, to m: Int) {
        guard let idx = draft.tasks.firstIndex(where: { $0.id == id }) else { return }
        draft.tasks[idx].minutes = m
    }

    private func cyclePriority(for id: UUID) {
        guard let idx = draft.tasks.firstIndex(where: { $0.id == id }) else { return }
        let current = draft.tasks[idx].priority
        let all = Priority.allCases
        let currentPos = all.firstIndex(of: current) ?? 0
        let next = all[(currentPos + 1) % all.count]
        draft.tasks[idx].priority = next
    }

    private func focusPrevText(before id: UUID) {
        guard let idx = draft.tasks.firstIndex(where: { $0.id == id }), idx > 0 else { return }
        focused = .text(draft.tasks[idx - 1].id)
    }

    private func focusNextText(after id: UUID) {
        guard let idx = draft.tasks.firstIndex(where: { $0.id == id }),
              idx + 1 < draft.tasks.count else { return }
        focused = .text(draft.tasks[idx + 1].id)
    }

    private func isLastRow(_ id: UUID) -> Bool {
        draft.tasks.last?.id == id
    }

    private func nextTaskID(after id: UUID) -> UUID? {
        guard let idx = draft.tasks.firstIndex(where: { $0.id == id }),
              idx + 1 < draft.tasks.count else { return nil }
        return draft.tasks[idx + 1].id
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
        // Uniform row height for every element -> .center actually centers.
        let rowH: CGFloat = 22
        return HStack(alignment: .center, spacing: 10) {
            TimelineView(.animation(minimumInterval: 0.05)) { context in
                let t = context.date.timeIntervalSince1970
                let opacity = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * .pi / 0.65))
                Circle()
                    .fill(dotColor)
                    .frame(width: 9, height: 9)
                    .opacity(opacity)
            }
            .frame(width: 12, height: rowH)

            Text(session.current?.title ?? "")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: rowH)

            if session.totalPlanned > 0 {
                Text("\(session.currentIndex)/\(session.totalPlanned)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(height: rowH)
            }

            Text(FocusSession.format(session.remaining))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(height: rowH)

            Button(action: onDone) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color.green.opacity(0.85)))
            }
            .buttonStyle(.plain)
            .frame(height: rowH)
            .help("Complete task")
        }
        .padding(.top, notchHeight)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
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
        let rowID = task.wrappedValue.id
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    .frame(width: 18, height: 18)
                Text("\(index)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .contentShape(Rectangle())
            .help("Drag to reorder")
            .onDrag {
                draggingID = rowID
                let provider = NSItemProvider()
                provider.registerDataRepresentation(
                    forTypeIdentifier: UTType.openFocusTaskRow.identifier,
                    visibility: .ownProcess
                ) { completion in
                    completion(rowID.uuidString.data(using: .utf8), nil)
                    return nil
                }
                return provider
            }

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
                .onSubmit {
                    // Enter in text field → jump to time chip of same row.
                    // Confirming time (Enter on time chip) is what advances rows / starts.
                    snapToNearestPreset(for: task.wrappedValue.id)
                    focused = .time(task.wrappedValue.id)
                }
                .onChange(of: task.wrappedValue.title) { newValue in
                    if newValue.count > titleCharLimit {
                        task.wrappedValue.title = String(newValue.prefix(titleCharLimit))
                    }
                }

            let taskID = task.wrappedValue.id
            let isTimeFocused = focused == .time(taskID)
            HStack(spacing: 6) {
                ForEach(minutePresets, id: \.self) { m in
                    Button {
                        task.wrappedValue.minutes = m
                        task.wrappedValue.minutesConfirmed = true
                    } label: {
                        let selected = task.wrappedValue.minutes == m
                        let shouldBlink = selected && isTimeFocused
                        chipLabel(minute: m, selected: selected, blinking: shouldBlink)
                    }
                    .buttonStyle(.plain)
                }
            }
            .focusable()
            .modifier(NoFocusRing())
            .focused($focused, equals: .time(taskID))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .opacity(draggingID == rowID ? 0.5 : 1)
        .contentShape(Rectangle())
        .onTapGesture { focused = .text(rowID) }
        .onDrop(
            of: [.openFocusTaskRow],
            delegate: TaskDropDelegate(
                targetID: rowID,
                tasks: $draft.tasks,
                draggingID: $draggingID
            )
        )
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
            .map {
                TaskItem(
                    title: $0.title.trimmingCharacters(in: .whitespaces),
                    minutes: $0.minutes > 0 ? $0.minutes : DraftStore.defaultMinutes,
                    priority: $0.priority
                )
            }
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

// MARK: - Drag-to-reorder

private struct TaskDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var tasks: [TaskItem]
    @Binding var draggingID: UUID?

    func validateDrop(info: DropInfo) -> Bool { draggingID != nil }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    // Live reorder: as the dragged row hovers over another row, move it into
    // that slot so the list shuffles under the cursor.
    func dropEntered(info: DropInfo) {
        guard let dragging = draggingID,
              dragging != targetID,
              let from = tasks.firstIndex(where: { $0.id == dragging }),
              let to = tasks.firstIndex(where: { $0.id == targetID })
        else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            tasks.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
