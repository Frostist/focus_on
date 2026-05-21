# FocusOn

A lightweight macOS utility that keeps your current task visible at all times and logs work sessions to a CSV file.

No accounts. No cloud. No friction.

## Features

- Floating widget that stays above all windows, including full-screen apps
- Persists across Spaces
- Logs every task session (start time, end time, completed/abandoned) to a CSV file
- Draggable — position it wherever you want, position is remembered across restarts
- Menu bar icon for quick access
- Optional launch at login

## Requirements

- macOS 13.0 (Ventura) or later

## Install

```bash
./install.sh
```

This builds a Release binary and copies it to `/Applications/FocusOn.app`, relaunching if already running.

## Usage

Click the widget or the menu bar icon to:

- **Complete task** — marks the current task done and prompts for the next one
- **Change task** — switches task without marking the current one complete
- **Log file** — shows the current log path; click **Change…** to move it anywhere

On first launch with no active task, the task picker opens automatically.

## Log file

Sessions are appended to `~/task_log.csv` by default (configurable via the popover).

```
task,from,to,completed
"Write README",2025-05-21T09:00:00+02:00,2025-05-21T09:15:00+02:00,true
```

| Column | Description |
|---|---|
| `task` | Free-text task name |
| `from` | ISO 8601 start time with timezone offset |
| `to` | ISO 8601 end time, empty if still active |
| `completed` | `true` / `false`, empty if still active |

The file is append-only. Sessions are never edited or deleted.

## Project layout

```
FocusOn/
├── TaskTrackerApp.swift      # @main entry point
├── AppDelegate.swift         # Panel, status item, lifecycle
├── FloatingPanel.swift       # NSPanel subclass + drag-handling container view
├── WidgetView.swift          # SwiftUI widget (dot + label + chevron)
├── ActionPopoverView.swift   # Complete / Change / Settings popover
├── TaskSelectionView.swift   # Recent tasks list + new task input
├── TaskStore.swift           # State management, CSV coordination
└── CSVLogger.swift           # File I/O, CSV formatting, ISO 8601 dates
```
