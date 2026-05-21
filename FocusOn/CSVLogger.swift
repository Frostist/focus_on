import Foundation

struct TaskRow {
    let task: String
    let from: Date
    let to: Date?
    let completed: Bool?
}

struct CSVLogger {
    static var fileURL: URL {
        if let stored = UserDefaults.standard.string(forKey: "focuson.logFilePath"),
           !stored.isEmpty {
            return URL(fileURLWithPath: stored)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("task_log.csv")
    }

    static var displayPath: String {
        let path = fileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    static func setFilePath(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: "focuson.logFilePath")
    }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func createFileIfNeeded() {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let header = "task,from,to,completed\n"
        try? header.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    static func appendRow(task: String, from: Date, to: Date?, completed: Bool?) {
        createFileIfNeeded()
        let escapedTask = task.replacingOccurrences(of: "\"", with: "\"\"")
        let fromStr = iso8601.string(from: from)
        let toStr = to.map { iso8601.string(from: $0) } ?? ""
        let completedStr: String
        if let c = completed {
            completedStr = c ? "true" : "false"
        } else {
            completedStr = ""
        }
        let line = "\"\(escapedTask)\",\(fromStr),\(toStr),\(completedStr)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: fileURL)
        }
    }

    static func readAllRows() -> [TaskRow] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        var lines = content.components(separatedBy: "\n")
        guard lines.count > 1 else { return [] }
        lines.removeFirst() // header
        var rows: [TaskRow] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if let row = parseRow(trimmed) {
                rows.append(row)
            }
        }
        return rows
    }

    private static func parseRow(_ line: String) -> TaskRow? {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if inQuotes {
                if c == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex && line[next] == "\"" {
                        current.append("\"")
                        i = line.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(c)
                }
            }
            i = line.index(after: i)
        }
        fields.append(current)
        guard fields.count >= 4 else { return nil }
        let taskName = fields[0]
        guard let fromDate = iso8601.date(from: fields[1]) else { return nil }
        let toDate = fields[2].isEmpty ? nil : iso8601.date(from: fields[2])
        let completed: Bool? = fields[3].isEmpty ? nil : (fields[3] == "true")
        return TaskRow(task: taskName, from: fromDate, to: toDate, completed: completed)
    }
}
