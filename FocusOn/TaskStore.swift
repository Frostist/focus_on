import Foundation
import Combine

@MainActor
final class TaskStore: ObservableObject {
    @Published var currentTaskName: String? = nil
    @Published var recentTasks: [RecentTask] = []

    private var currentTaskStartedAt: Date? = nil

    struct RecentTask: Identifiable {
        let id = UUID()
        let name: String
        let startedAt: Date
    }

    func loadState() {
        let defaults = UserDefaults.standard
        currentTaskName = defaults.string(forKey: "focuson.currentTaskName")
        if let interval = defaults.object(forKey: "focuson.currentTaskStartedAt") as? Double {
            currentTaskStartedAt = Date(timeIntervalSince1970: interval)
        }
        CSVLogger.createFileIfNeeded()
        refreshRecentTasks()
    }

    func startTask(_ name: String, completingPrevious: Bool) {
        let now = Date()
        if let prev = currentTaskName, let prevStart = currentTaskStartedAt {
            _ = prevStart
            CSVLogger.appendRow(task: prev, from: prevStart, to: now, completed: completingPrevious ? true : false)
        }
        currentTaskName = name
        currentTaskStartedAt = now
        persistState()
        CSVLogger.appendRow(task: name, from: now, to: nil, completed: nil)
        refreshRecentTasks()
    }

    func completeCurrentTask() {
        guard let name = currentTaskName, let start = currentTaskStartedAt else { return }
        let now = Date()
        CSVLogger.appendRow(task: name, from: start, to: now, completed: true)
        currentTaskName = nil
        currentTaskStartedAt = nil
        persistState()
        refreshRecentTasks()
    }

    func writeClosingRowOnTerminate() {
        guard let name = currentTaskName, let start = currentTaskStartedAt else { return }
        CSVLogger.appendRow(task: name, from: start, to: Date(), completed: false)
    }

    func refreshRecentTasks() {
        let rows = CSVLogger.readAllRows()
        let open = rows.filter { $0.to == nil }
        var seen: [String: Date] = [:]
        for row in open.reversed() {
            if seen[row.task] == nil {
                seen[row.task] = row.from
            }
        }
        let sorted = seen
            .map { RecentTask(name: $0.key, startedAt: $0.value) }
            .sorted { $0.startedAt > $1.startedAt }
            .prefix(10)
        recentTasks = Array(sorted)
    }

    private func persistState() {
        let defaults = UserDefaults.standard
        defaults.set(currentTaskName, forKey: "focuson.currentTaskName")
        if let date = currentTaskStartedAt {
            defaults.set(date.timeIntervalSince1970, forKey: "focuson.currentTaskStartedAt")
        } else {
            defaults.removeObject(forKey: "focuson.currentTaskStartedAt")
        }
    }
}
