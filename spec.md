# FocusOn Task Tracker — macOS App Spec

## Overview

A lightweight native macOS utility that keeps the current task visible at all times and logs work sessions to a CSV file. No accounts, no cloud, no friction.

---

## Platform & Tech Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI with AppKit interop where needed
- **Xcode project template**: macOS App, **AppKit App Delegate lifecycle** (not SwiftUI lifecycle). `NSPanel` and `NSStatusItem` require `AppDelegate` control; SwiftUI `WindowGroup` is suppressed.
- **Minimum macOS**: 13.0 (Ventura)
- **Distribution**: Local build only (no App Store, no notarisation required)
- **Persistence**: Flat CSV file at `~/task_log.csv`
- **No third-party dependencies**

---

## Application Structure

The app runs as a **dual-presence** application:

1. A floating widget window (always visible)
2. A menu bar status item

There is no Dock icon. Set `LSUIElement = YES` in `Info.plist` to suppress the Dock entry.

---

## Floating Widget

### Window Behaviour

- Implemented as an `NSPanel` (not `NSWindow`)
- Window level: `.floating` (sits above normal windows, below system UI)
- Collection behaviour: `[.canJoinAllSpaces, .fullScreenAuxiliary]` so it persists across Spaces and over full-screen apps
- Non-activating: `NSPanel` with `nonactivatingPanel` style so clicking it doesn't steal focus from the frontmost app
- No title bar, no traffic lights. Fully custom chrome.
- Borderless, with a corner radius of ~12pt and a subtle translucent background (`NSVisualEffectView` with `.hudWindow` or `.underWindowBackground` material)
- Minimum and fixed size: approximately 220×44pt (wide enough for a task name, short enough to stay unobtrusive). Allow horizontal resize if the task name is long; clamp minimum width at 160pt.
- Shadow: standard system shadow is fine

### Dragging

- The widget must be freely draggable by clicking and dragging anywhere on its surface
- Implement via `mouseDragged` / `mouseDown` on the hosting view, or use a standard `NSWindow` drag region
- Persist the last window position to `UserDefaults` and restore it on next launch
- **Off-screen clamping**: on restore, clamp the saved position to the visible frame of the nearest `NSScreen`. If the saved position is entirely off-screen (e.g. external monitor disconnected), fall back to the default position.
- **Default position**: bottom-right corner of the main screen, 20pt margin from screen edges.

### Widget Content

Left to right layout, vertically centred:

1. **Animation indicator** — a small pulsing dot (8×8pt circle). Pulse: smoothly oscillates opacity between 0.4 and 1.0 on a ~2 second cycle using a SwiftUI `withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true))`. Colour: system accent colour.
2. **Task label** — single line, truncated with ellipsis if too long. Font: `.system(.footnote, design: .rounded)` or similar small but legible size (~12pt). Foreground: primary label colour. Shows the current task name, or _"No active task"_ in a muted colour if none is set.
3. A small **chevron down** SF Symbol on the right edge (6pt, tertiary foreground) to hint interactivity.

### Widget Interaction

Clicking anywhere on the widget (not dragging) opens an action popover anchored to the widget.

The popover contains:

- **"✓ Complete task"** button — marks the current task done and immediately prompts task selection (see Task Selection below)
- **"↩ Change task"** button — prompts task selection without marking the current task complete
- A subtle separator
- **"Quit"** button — smaller and very secondary
- A subtle separator
- **"✓ Launch at login"** / **"  Launch at login"** toggle — checkmark prefix reflects current state

If there is no active task, the popover shows only the task selection UI directly (no complete/change options).

**Popover sizing**: `ActionPopoverView` preferred content size ~240×140pt. `TaskSelectionView` preferred content size ~280×320pt.

---

## Menu Bar Item

- Uses `NSStatusItem` with a fixed-width icon
- Icon: an SF Symbol — `checklist` or `circle.fill` — at menu bar size. Use template rendering so it adapts to light/dark menu bar.
- Clicking the status item opens the same action popover. Anchor using `statusItem.button?.window` as positioning window and `statusItem.button?.bounds` as positioning rect.
- Popover behavior: `.transient` (dismissed by clicking outside).
- Menu bar item is always present while the app is running

---

## Task Selection UI

Presented as a popover or sheet (anchored to wherever the action was triggered). Preferred content size ~280×320pt.

Contains:
### Cancel button

Dismiss the task selection UI with no change. If there is no active task and this is the first-launch auto-prompt, Cancel leaves the app running with no active task (widget shows "No active task").

### Recent incomplete tasks

- A scrollable list of up to **10** most recent tasks from `~/task_log.csv` that have no `completed_at` timestamp (i.e. were started but never completed)
- **Deduplicate by task name**: if the same name appears in multiple open rows, show it once (using the most recent `from` timestamp for the relative time display). Rationale: showing the same task name five times is noise.
- Each row shows the task name and how long ago it was started (e.g. "2h ago", "yesterday") using `RelativeDateTimeFormatter`
- Tapping a row selects that task as the new current task

### New task input

- A text field at the bottom of the popover: _"New task…"_ placeholder
- Pressing Enter or clicking a **"Start"** button creates and activates the new task
- Auto-focus this field when the popover opens so the user can type immediately

### Behaviour on selection

When a task is selected (either from recent list or new):

1. Write a **closing row** to the CSV for the previously active task (if any): set `to` = now. Set `completed` = `true` only if the user chose "Complete task"; otherwise `false`.
2. Write an **opening row** for the newly selected task: set `from` = now, leave `to` and `completed` blank/empty.
3. Update the widget label to the new task name.
4. Dismiss the popover.

---

## CSV Logging

### File location

`~/task_log.csv` (i.e. `FileManager.default.homeDirectoryForCurrentUser` + `task_log.csv`)

Create the file with a header row if it does not exist.

### Schema

```
task,from,to,completed
```

|Column|Type|Notes|
|---|---|---|
|`task`|String|Free text. Quote if it contains commas.|
|`from`|ISO 8601 datetime|e.g. `2025-05-21T08:32:00+02:00`|
|`to`|ISO 8601 datetime|Empty string if task is still active|
|`completed`|Boolean string|`true` or `false`. Empty string if task is still active.|

### Write rules

- Append-only. Never modify or delete existing rows.
- One row per task session segment. If the user switches task → task → task, each generates its own row.
- If the app quits while a task is active, write a closing row on `applicationWillTerminate` with `to` = now and `completed` = `false`.
- Use `ISO8601DateFormatter` and include timezone offset.
- **Crash / orphaned rows**: if the app crashes (no graceful quit), the last open row will have no `to` value. This is a known limitation — the append-only rule means we do not retroactively close orphaned rows. Document with a code comment. On next launch, `UserDefaults` may still show an active task; do not write a new opening row (reuse existing state).

### CSV quoting

- Wrap the `task` field in double quotes always (simplest approach, always safe).
- Escape any `"` inside the task name as `""` (standard CSV escaping).

---

## State Persistence

Use `UserDefaults` to persist:

- `focuson.currentTaskName: String?` — the active task name
- `focuson.currentTaskStartedAt: Date?` — when the current task was started
- `focuson.windowPosition: CGPoint` — last widget position

On launch, restore the widget to the last position (with off-screen clamping — see Dragging) and resume displaying the active task if one exists. Do **not** write a new CSV row on launch for a pre-existing active task.

---

## App Launch & Lifecycle

- Launch at login: `SMAppService.mainApp.register()` / `.unregister()` (macOS 13+). Toggle exposed in the action popover (see Widget Interaction).
- On first launch, if no task is active, open the task selection UI automatically. Anchor it to the floating widget. Fire after a short delay (≥0.3s) so the widget is visible before the popover appears.
- `applicationShouldTerminateAfterLastWindowClosed` → return `false`

---

## Error Handling

- If the CSV file cannot be written (permissions, disk full), show a brief non-intrusive error: update the widget label temporarily to "⚠ Could not write log" and log to `stderr`. Do not crash.
- If `UserDefaults` state is corrupt on launch, start fresh (no active task).

---

## Project Structure

```
FocusOn/
├── TaskTrackerApp.swift          # @main, NSApplicationDelegateAdaptor only
├── AppDelegate.swift             # NSStatusItem, NSPanel setup, lifecycle
├── FloatingPanel.swift           # NSPanel subclass + drag handling
├── WidgetView.swift              # SwiftUI widget content (dot + label + chevron)
├── ActionPopoverView.swift       # Complete / Change / Quit / Launch-at-login popover
├── TaskSelectionView.swift       # Recent tasks list + new task input
├── TaskStore.swift               # State: current task, recent tasks, CSV R/W
├── CSVLogger.swift               # File append, quoting, ISO8601 formatting
└── Info.plist                    # LSUIElement = YES
```

`TaskTrackerApp.swift` is minimal — SwiftUI lifecycle kept alive via a `Settings { EmptyView() }` scene; all real work is in `AppDelegate`.

---

## Implementation Plan

Build bottom-up: data layer first, then state, then panel, then views, then wire together.

### Phase 1 — Project scaffold
- Xcode: macOS App, AppKit lifecycle, Swift, SwiftUI enabled
- Bundle ID: `com.carl.focuson`
- Deployment target: macOS 13.0
- Delete auto-generated `ContentView.swift`
- `Info.plist`: add `LSUIElement` = `YES` (String)

### Phase 2 — `CSVLogger.swift`
Pure value layer, no UI imports.
- `createFileIfNeeded()` — writes header if absent
- `appendRow(task:from:to:completed:)` — builds and appends one CSV line
- `readAllRows() -> [TaskRow]` — parses entire file for recent-tasks query
- `TaskRow` struct: `task: String`, `from: Date`, `to: Date?`, `completed: Bool?`

### Phase 3 — `TaskStore.swift`
`@MainActor ObservableObject`, single source of truth.
- `startTask(_ name: String, completingPrevious: Bool)` — close old row, open new row, persist state, refresh recent list
- `completeCurrentTask()` — close row with `completed = true`, clear state
- `loadState()` — read UserDefaults on launch
- `refreshRecentTasks()` — read CSV, deduplicate by name, sort by recency, cap at 10

### Phase 4 — `FloatingPanel.swift`
- `styleMask = [.nonactivatingPanel, .borderless]`, `level = .floating`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, `isOpaque = false`, `backgroundColor = .clear`
- `canBecomeKey → true` (text field focus in popover)
- Drag via `mouseDown` / `mouseDragged` delta; save position to UserDefaults on `windowWillMove`
- Init: restore position with off-screen clamp, or apply default bottom-right

### Phase 5 — `AppDelegate.swift`
- Create `TaskStore`, `FloatingPanel`, `NSStatusItem`
- Wire both click targets → show `ActionPopoverView` in `NSPopover` (`.transient`)
- `applicationWillTerminate`: write closing row if task active
- `applicationDidFinishLaunching`: load state, show panel, auto-open task selection if no active task

### Phase 6 — `WidgetView.swift`
- `HStack`: pulsing dot + task label + chevron
- `NSVisualEffectView` background via `UIViewRepresentable`, material `.hudWindow`, corner radius 12pt
- Tap gesture → AppDelegate shows `ActionPopoverView`

### Phase 7 — `ActionPopoverView.swift`
- Complete / Change / Quit / Launch-at-login buttons
- Calls back to `TaskStore` and `AppDelegate` via closures or `@EnvironmentObject`

### Phase 8 — `TaskSelectionView.swift`
- Cancel button, recent tasks `List`, new task `TextField` with auto-focus
- `RelativeDateTimeFormatter` for row timestamps

### Phase 9 — End-to-end wiring
- Pass `TaskStore` as `@EnvironmentObject` through all views
- Connect all action callbacks
- Test full flow: start → change → complete → quit

---

## Out of Scope (explicit exclusions)

- No editing or deleting past log entries from the UI
- No time summaries or reporting
- No sync or cloud backup
- No notifications or reminders
- No tagging or categorisation
- No dark/light mode toggle (follow system automatically)
