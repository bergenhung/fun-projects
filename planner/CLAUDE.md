# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native multiplatform (iPhone + Mac) daily planner: SwiftUI + SwiftData, hourly grid view, voice task entry, timed reminders, and automatic completion check-ins. Full requirements live in [weekday-daily-planner-spec-v2.md](weekday-daily-planner-spec-v2.md) — read it before making feature decisions, especially the "OUT of scope for v1" section and the milestone build order.

Note: this `planner/` directory is a subproject inside a larger personal monorepo (`fun project/`) containing unrelated Python projects. Nothing outside `planner/` is relevant to this app.

## Build system: XcodeGen, not a hand-edited .xcodeproj

The Xcode project is generated from [project.yml](project.yml) via `xcodegen`, not edited directly.

- **Never hand-edit `Planner.xcodeproj`** — it's regenerated and any manual changes are lost.
- After adding, removing, or renaming any file under `Planner/`, or changing target settings, regenerate:
  ```bash
  xcodegen generate
  ```
- `project.yml` defines one target block (`platform: [iOS, macOS]`) that XcodeGen expands into two real Xcode targets/schemes: `Planner_iOS` and `Planner_macOS`. Both share the same `Planner/` source tree.

## Commands

Build (no simulator needed for compile checks):
```bash
xcodebuild -project Planner.xcodeproj -scheme Planner_macOS -destination 'platform=macOS' build
xcodebuild -project Planner.xcodeproj -scheme Planner_iOS -destination 'platform=iOS Simulator,name=<device name>' build
```

Run in iOS Simulator headlessly (no Xcode GUI):
```bash
xcrun simctl list devices                                   # find/confirm a device id
xcrun simctl bootstatus <device-id> -b                      # boot + wait
xcrun simctl install <device-id> <path-to-.app>              # .app is under DerivedData/.../Build/Products/Debug-iphonesimulator/
xcrun simctl launch <device-id> com.wphuang.Planner
xcrun simctl io <device-id> screenshot out.png                # visual verification
```
`xcrun simctl launch`/`install` occasionally hang past a normal timeout on this machine for no clear reason — run them with `run_in_background` and pick the result up from the task notification rather than assuming failure.

There is no test target yet (no unit tests have been added as of Milestone 2).

## Debug-only sample data

`PlannerApp.swift` seeds three sample tasks (including an intentionally overlapping pair and one pre-completed task) when launched with `-seedSampleData`, e.g.:
```bash
xcrun simctl launch <device-id> com.wphuang.Planner -seedSampleData
```
This writes to the real on-disk SwiftData store (not in-memory), so after using it for visual verification, uninstall/reinstall the app (or delete the container) to leave a clean state:
```bash
xcrun simctl uninstall <device-id> com.wphuang.Planner
```

## Physical-device / signing notes

`project.yml` does not set a `DEVELOPMENT_TEAM`. Running on a real iPhone requires picking a signing team in Xcode's Signing & Capabilities UI, which XcodeGen will **wipe on the next `xcodegen generate`** unless the team ID is added to `project.yml`. CloudKit sync (Milestone 6) requires a paid Apple Developer account, not just a free personal-team signing identity.

## Architecture

**Data model** — single SwiftData `@Model`, [Planner/Models/PlannerTask.swift](Planner/Models/PlannerTask.swift). Named `PlannerTask`, not `Task` — the spec's data model calls it `Task`, but that collides with Swift's concurrency `Task` type, so every reference in code and views uses `PlannerTask`.

**Today-only querying** — [Planner/Views/ContentView.swift](Planner/Views/ContentView.swift) builds its `@Query` in a custom `init()` with a `#Predicate` date range (`startOfDay..<startOfNextDay`) rather than a static `@Query` property, because the "today" boundary has to be computed at view-construction time. V1 is single-day/Today-only by design (see spec's out-of-scope list) — there is no date picker on the main grid, only inside the add/edit sheet.

**Hourly grid layout** — [Planner/Views/HourlyGridView.swift](Planner/Views/HourlyGridView.swift) renders hour rows as a background `VStack`, then overlays task blocks in a `GeometryReader` layer positioned by absolute `.offset(x:y:)` computed from `startHour`/`durationMinutes` — this is a manual calendar-day-view layout, not a `List`/`LazyVGrid`. Grid range (6 AM–10 PM) and row height live in [Planner/Support/GridConfig.swift](Planner/Support/GridConfig.swift); change the visible hour range there.

**Overlap layout** — [Planner/Support/TaskLayout.swift](Planner/Support/TaskLayout.swift) implements interval-graph-coloring to give overlapping tasks side-by-side columns (standard calendar-app technique). `HourlyGridView` calls `TaskLayoutEngine.layout(for:)` and uses the returned `column`/`columnCount` to compute each block's width and x-offset. If task blocks ever overlap visually, this is the file to check.

**Add/Edit** — [Planner/Views/AddEditTaskView.swift](Planner/Views/AddEditTaskView.swift) is one sheet used for both create and edit, keyed by whether an `editingTask: PlannerTask?` was passed in. Field defaults (duration 60 min, reminder 30 min before) come from `GridConfig`.

## Current status (see task list / spec milestones)

Completed: Milestone 1 (project scaffold), Milestone 2 (manual CRUD + hourly grid). Not yet built: reminder notifications, completion check-in notifications, voice entry, CloudKit sync, polish — build these in the milestone order given in the spec, verifying each one (build + run in simulator) before moving to the next.
