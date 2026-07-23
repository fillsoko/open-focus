import Foundation
import Combine
import AppKit
import SwiftUI

enum Priority: Int, CaseIterable, Identifiable, Comparable, Codable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int { rawValue }

    var symbol: String {
        switch self {
        case .low: return "circle"
        case .medium: return "circle.lefthalf.filled"
        case .high: return "circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .low: return .secondary
        case .medium: return .yellow
        case .high: return .red
        }
    }

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    static func < (lhs: Priority, rhs: Priority) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct TaskItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var minutes: Int
    var priority: Priority = .medium
    var minutesConfirmed: Bool = false
}

final class FocusSession: ObservableObject {
    @Published var queue: [TaskItem] = []
    @Published var current: TaskItem?
    @Published var remaining: TimeInterval = 0
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentIndex: Int = 0
    @Published var totalPlanned: Int = 0

    private var endDate: Date?
    private var timer: Timer?
    private var tickCount: UInt = 0
    var onFinish: (() -> Void)?
    var onAdvance: (() -> Void)?

    private static let snapshotKey = "openfocus.session.snapshot.v1"
    // Sessions older than this (since last checkpoint) are treated as stale and
    // discarded on launch — a day-old session shouldn't silently resurrect.
    private static let staleThreshold: TimeInterval = 12 * 3600

    func start(with tasks: [TaskItem]) {
        let sorted = tasks.sorted { $0.priority > $1.priority }
        queue = sorted
        totalPlanned = sorted.count
        currentIndex = 0
        advance()
    }

    func advance() {
        timer?.invalidate()
        guard !queue.isEmpty else {
            current = nil
            isRunning = false
            isPaused = false
            remaining = 0
            currentIndex = 0
            totalPlanned = 0
            persist()
            onFinish?()
            return
        }
        let next = queue.removeFirst()
        current = next
        currentIndex += 1
        remaining = TimeInterval(next.minutes * 60)
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        isPaused = false
        onAdvance?()
        tick()
        startTimer()
        persist()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard let end = endDate else { return }
        let r = end.timeIntervalSinceNow
        remaining = max(0, r)
        // Periodically checkpoint so a hard crash / power loss loses at most a
        // few seconds of progress (transitions persist immediately anyway).
        tickCount &+= 1
        if tickCount % 10 == 0 { persist() }
        if r <= 0 {
            NSSound(named: .init("Glass"))?.play()
            advance()
        }
    }

    func done() { advance() }
    func skip() { advance() }

    func togglePause() {
        isPaused ? resume() : pause()
    }

    /// Freeze the countdown (bio break, phone call, lunch, …). The remaining
    /// time is captured and the timer stopped; the current task is preserved.
    func pause() {
        guard isRunning, !isPaused, let end = endDate else { return }
        timer?.invalidate()
        timer = nil
        remaining = max(0, end.timeIntervalSinceNow)
        endDate = nil
        isPaused = true
        persist()
    }

    /// Resume counting down from where we paused.
    func resume() {
        guard isRunning, isPaused else { return }
        endDate = Date().addingTimeInterval(remaining)
        isPaused = false
        tick()
        startTimer()
        persist()
    }

    func extend(minutes: Int) {
        guard isRunning else { return }
        remaining += TimeInterval(minutes * 60)
        if !isPaused {
            endDate = Date().addingTimeInterval(remaining)
        }
        persist()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        current = nil
        queue.removeAll()
        isRunning = false
        isPaused = false
        remaining = 0
        currentIndex = 0
        totalPlanned = 0
        persist()
        onFinish?()
    }

    // MARK: - Sleep / wake (freeze semantics)

    /// System is going to sleep: freeze the countdown so time asleep is not
    /// counted against the current task. A user-paused session is already
    /// frozen, so this is a no-op for it.
    func suspendForSleep() {
        guard isRunning, !isPaused, let end = endDate else { return }
        timer?.invalidate()
        timer = nil
        remaining = max(0, end.timeIntervalSinceNow)
        endDate = nil
        persist()
    }

    /// Woke from sleep: if we were running (not user-paused) and got frozen by
    /// `suspendForSleep()`, resume counting down from the frozen remaining.
    func resumeFromSleep() {
        guard isRunning, !isPaused, timer == nil, endDate == nil else { return }
        if remaining <= 0 { return }
        endDate = Date().addingTimeInterval(remaining)
        startTimer()
        tick()
        persist()
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var queue: [TaskItem]
        var current: TaskItem?
        var remaining: TimeInterval
        var isPaused: Bool
        var currentIndex: Int
        var totalPlanned: Int
        var savedAt: Date
    }

    /// Save (or clear) the running session so it survives quit / restart.
    /// Uses freeze semantics: we store the frozen `remaining`, never a
    /// wall-clock deadline, so closing the app never drains the timer.
    func persist() {
        guard isRunning, let current else {
            UserDefaults.standard.removeObject(forKey: Self.snapshotKey)
            return
        }
        // Capture the up-to-the-moment remaining for an actively running task.
        let liveRemaining: TimeInterval
        if !isPaused, let end = endDate {
            liveRemaining = max(0, end.timeIntervalSinceNow)
        } else {
            liveRemaining = remaining
        }
        let snap = Snapshot(
            queue: queue,
            current: current,
            remaining: liveRemaining,
            isPaused: isPaused,
            currentIndex: currentIndex,
            totalPlanned: totalPlanned,
            savedAt: Date()
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
        }
    }

    /// Restore a session saved by `persist()`. Returns true if a live session
    /// was restored (so the caller can show the notch). Frozen `remaining` is
    /// resumed as-is — time spent quit / asleep does not count down.
    @discardableResult
    func restore() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.snapshotKey),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data),
              let current = snap.current else {
            UserDefaults.standard.removeObject(forKey: Self.snapshotKey)
            return false
        }
        // Too old to meaningfully resume.
        if Date().timeIntervalSince(snap.savedAt) > Self.staleThreshold {
            UserDefaults.standard.removeObject(forKey: Self.snapshotKey)
            return false
        }

        queue = snap.queue
        self.current = current
        currentIndex = snap.currentIndex
        totalPlanned = snap.totalPlanned
        remaining = max(0, snap.remaining)
        isRunning = true

        if snap.isPaused || remaining <= 0 {
            // Keep a user-paused (or already-elapsed) session frozen so nothing
            // auto-advances or plays a sound on launch — the user resumes or
            // completes it deliberately.
            isPaused = true
            endDate = nil
        } else {
            isPaused = false
            endDate = Date().addingTimeInterval(remaining)
            startTimer()
        }
        persist()
        return true
    }

    static func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

final class DraftStore: ObservableObject {
    static let maxTasks = 5
    static let defaultMinutes = 5
    private static let draftKey = "openfocus.draft.v1"

    @Published var tasks: [TaskItem] = DraftStore.emptySlots() {
        didSet { persist() }
    }

    init() {
        // Restore a half-entered draft from a previous launch, if any.
        if let data = UserDefaults.standard.data(forKey: Self.draftKey),
           let saved = try? JSONDecoder().decode([TaskItem].self, from: data),
           !saved.isEmpty {
            tasks = saved
        }
    }

    static func emptySlots() -> [TaskItem] {
        // minutes = 0 = "unset" (no chip highlighted). Snapped to defaultMinutes
        // when user reaches the time chip.
        (0..<maxTasks).map { _ in TaskItem(title: "", minutes: 0) }
    }

    func reset() {
        tasks = DraftStore.emptySlots()
    }

    private func persist() {
        let hasContent = tasks.contains {
            !$0.title.trimmingCharacters(in: .whitespaces).isEmpty
        }
        if hasContent, let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: Self.draftKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.draftKey)
        }
    }
}
