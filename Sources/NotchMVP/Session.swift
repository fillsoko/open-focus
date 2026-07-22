import Foundation
import Combine
import AppKit
import SwiftUI

enum Priority: Int, CaseIterable, Identifiable, Comparable {
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

struct TaskItem: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var minutes: Int
    var priority: Priority = .medium
}

final class FocusSession: ObservableObject {
    @Published var queue: [TaskItem] = []
    @Published var current: TaskItem?
    @Published var remaining: TimeInterval = 0
    @Published var isRunning: Bool = false
    @Published var currentIndex: Int = 0
    @Published var totalPlanned: Int = 0

    private var endDate: Date?
    private var timer: Timer?
    var onFinish: (() -> Void)?
    var onAdvance: (() -> Void)?

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
            remaining = 0
            currentIndex = 0
            totalPlanned = 0
            onFinish?()
            return
        }
        let next = queue.removeFirst()
        current = next
        currentIndex += 1
        remaining = TimeInterval(next.minutes * 60)
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        onAdvance?()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard let end = endDate else { return }
        let r = end.timeIntervalSinceNow
        remaining = max(0, r)
        if r <= 0 {
            NSSound(named: .init("Glass"))?.play()
            advance()
        }
    }

    func done() { advance() }
    func skip() { advance() }

    func extend(minutes: Int) {
        guard let end = endDate else { return }
        endDate = end.addingTimeInterval(TimeInterval(minutes * 60))
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        current = nil
        queue.removeAll()
        isRunning = false
        remaining = 0
        currentIndex = 0
        totalPlanned = 0
        onFinish?()
    }

    static func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

final class DraftStore: ObservableObject {
    static let maxTasks = 5
    @Published var tasks: [TaskItem] = DraftStore.emptySlots()

    static func emptySlots() -> [TaskItem] {
        (0..<maxTasks).map { _ in TaskItem(title: "", minutes: 25) }
    }

    func reset() {
        tasks = DraftStore.emptySlots()
    }
}
