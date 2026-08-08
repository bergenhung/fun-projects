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

There is no test target yet.

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

`project.yml` does not set a `DEVELOPMENT_TEAM`. Running on a real iPhone requires picking a signing team in Xcode's Signing & Capabilities UI, which XcodeGen will **wipe on the next `xcodegen generate`** unless the team ID is added to `project.yml`.

## CloudKit sync is prepared but not wired in

`PlannerTask` has inline default values on every property (`var isCompleted: Bool = false`, etc.) specifically because SwiftData requires that — non-optional properties without defaults — for a model to be CloudKit-syncable. That part is safe and already done.

The rest is deliberately **not** turned on, because it requires a paid Apple Developer account the project doesn't have yet, and enabling it without one would break the app: a `ModelConfiguration(..., cloudKitDatabase: .automatic)` needs a matching `com.apple.developer.icloud-services` entitlement backed by a real provisioning profile, and `PlannerApp.init()` currently `fatalError()`s if `ModelContainer` init throws — so a half-configured CloudKit setup would crash on every launch instead of degrading gracefully.

To actually enable it once there's a Team ID:
1. Add `DEVELOPMENT_TEAM` to `project.yml` and add an `entitlements:` block for the `Planner` target with `com.apple.developer.icloud-container-identifiers` and `com.apple.developer.icloud-services: [CloudKit]` (mirrors the existing `info:` block pattern already in `project.yml`).
2. Add `UIBackgroundModes: [remote-notification]` to the iOS Info.plist properties (CloudKit sync uses silent push to notify other devices of remote changes).
3. In `PlannerApp.swift`, switch to `ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)` — and don't `fatalError` on failure; fall back to a local-only configuration instead, since users without a properly provisioned build should still get a working local-only app rather than a crash.
4. Test with two simulators (or a simulator + device) signed into the *same* iCloud account in Settings.

## Architecture

**Data model** — single SwiftData `@Model`, [Planner/Models/PlannerTask.swift](Planner/Models/PlannerTask.swift). Named `PlannerTask`, not `Task` — the spec's data model calls it `Task`, but that collides with Swift's concurrency `Task` type, so every reference in code and views uses `PlannerTask`.

**Today-only querying** — [Planner/Views/ContentView.swift](Planner/Views/ContentView.swift) builds its `@Query` in a custom `init()` with a `#Predicate` date range (`startOfDay..<startOfNextDay`) rather than a static `@Query` property, because the "today" boundary has to be computed at view-construction time. V1 is single-day/Today-only by design (see spec's out-of-scope list) — there is no date picker on the main grid, only inside the add/edit sheet.

**Hourly grid layout** — [Planner/Views/HourlyGridView.swift](Planner/Views/HourlyGridView.swift) renders hour rows as a background `VStack`, then overlays task blocks in a `GeometryReader` layer positioned by absolute `.offset(x:y:)` computed from `startHour`/`durationMinutes` — this is a manual calendar-day-view layout, not a `List`/`LazyVGrid`. Grid range (7 AM–7 PM) and row height live in [Planner/Support/GridConfig.swift](Planner/Support/GridConfig.swift); change the visible hour range there.

**Overlap layout** — [Planner/Support/TaskLayout.swift](Planner/Support/TaskLayout.swift) implements interval-graph-coloring to give overlapping tasks side-by-side columns (standard calendar-app technique). `HourlyGridView` calls `TaskLayoutEngine.layout(for:)` and uses the returned `column`/`columnCount` to compute each block's width and x-offset. If task blocks ever overlap visually, this is the file to check.

**Add/Edit** — [Planner/Views/AddEditTaskView.swift](Planner/Views/AddEditTaskView.swift) is one sheet used for both create and edit, keyed by whether an `editingTask: PlannerTask?` was passed in. Field defaults (duration 60 min, reminder 30 min before) come from `GridConfig`.

**Notifications** — [Planner/Notifications/NotificationScheduler.swift](Planner/Notifications/NotificationScheduler.swift) is the single place that computes reminder/check-in trigger dates and schedules/cancels them; every create/edit/delete/complete-toggle path (in `AddEditTaskView` and `ContentView`) calls into it rather than touching `UNUserNotificationCenter` directly. Both a task's reminder and its completion check-in are identified by `"reminder-\(task.id)"` / `"checkin-\(task.id)"`, so `reschedule(for:)` can always cancel-then-recreate idempotently. [Planner/Notifications/PlannerNotificationDelegate.swift](Planner/Notifications/PlannerNotificationDelegate.swift) handles the check-in's Yes/No actions — it deliberately opens its own `ModelContext(modelContainer)` rather than using `mainContext`, because delegate callbacks can land on a background queue and `mainContext` is meant for the main actor. **Known constraint**: local notifications don't appear in `pendingNotificationRequests` (and by extension won't display) until the user has answered the system permission prompt at least once — this can only be verified by a human tapping "Allow"/"Don't Allow" in the simulator, which this environment couldn't do headlessly (see Testing section below).

**Voice entry** — [Planner/Voice/SpeechRecognizer.swift](Planner/Voice/SpeechRecognizer.swift) wraps `SFSpeechRecognizer` + `AVAudioEngine` behind a small `@MainActor` `ObservableObject`; [Planner/Support/SpokenTaskParser.swift](Planner/Support/SpokenTaskParser.swift) is pure, dependency-free logic that pulls a spoken time out of a transcript via `NSDataDetector` (not hand-rolled regex/NLP) and strips the matched phrase to produce a clean title. If no time is detected, [Planner/Views/VoiceEntryView.swift](Planner/Views/VoiceEntryView.swift) falls back to `GridConfig.nextOpenHour(for:)`. `AVAudioSession` calls in `SpeechRecognizer` are `#if os(iOS)`-gated since that type doesn't exist on macOS.

## Testing constraints in this environment

Two things can't be exercised headlessly here and had to be verified by other means — worth knowing before assuming something is broken:
- **No simulator tap/touch input.** The native `mcp__Claude_Code_iOS_Simulator__control` tool needs `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, which needs an interactive password prompt. So sheet flows (add/edit/delete, voice entry's mic button, notification permission prompts, check-in Yes/No taps) are verified by code review + build success + screenshot of the rendered state, not by actually driving the UI.
- **`simctl privacy` doesn't cover notification or speech-recognition authorization** (only TCC services like microphone, camera, contacts, etc. — confirmed by checking `xcrun simctl privacy grant --help`'s service list). So those permission prompts can't be pre-granted headlessly either; they need a real tap.
- Where useful, `SpokenTaskParser`'s pure logic was verified by running it standalone via `swift <file>.swift` outside the simulator entirely — that's a good pattern to reuse for any future logic that doesn't need SwiftUI/UIKit.

## Current status (see task list / spec milestones)

All seven spec milestones have a first pass done. 1–5 (scaffold, CRUD + grid, reminders, check-ins, voice entry) and 7 (polish: notification-denied banner in `ContentView`, dark-mode pass, mic-denied empty state in `VoiceEntryView`) are built and verified to the extent the constraints above allow. Milestone 6 (CloudKit) is intentionally left prepared-but-inactive — see the CloudKit section above — since it needs a real Apple Developer Team ID this project doesn't have yet.
