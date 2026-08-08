# Weekday Daily Planner — Build Spec (v2)

## Goal
A native, multiplatform (iPhone + Mac) daily planner built with Swift, SwiftUI, and SwiftData, with an hourly grid view, voice-activated task entry, timed reminders, and automatic completion check-ins.

## Platform & Tech Stack
- **Language:** Swift
- **UI:** SwiftUI (single multiplatform target)
- **Data persistence:** SwiftData
- **Sync:** CloudKit (via SwiftData)
- **Voice input:** Speech framework (`SFSpeechRecognizer`) + `AVAudioEngine` for capture
- **Notifications:** `UserNotifications` framework (local notifications — no server needed)
- **Min targets:** iOS 17+, macOS 14+

## V1 Feature Set

1. **Hourly grid view** — Day displayed as a vertical grid, one row per hour (default window 7 AM–7 PM, configurable). Tasks appear as blocks in their scheduled hour slot, similar to a calendar day view.
2. **Day navigation** — Swipe or scroll horizontally to move to the day before or after the currently viewed day (so from Today you can go back to Yesterday or forward to Tomorrow, and keep going from there). Current day is visually indicated (e.g., "Today" label or highlight) regardless of which day is being viewed.
3. **Jump to date** — A date picker (calendar icon in toolbar) lets the user jump directly to any specific date instead of scrolling day by day.
4. **Voice-activated task entry** — Tap a mic button (or hands-free trigger — see note below), speak a task, app transcribes it and creates a task. Should parse a spoken time if mentioned (e.g., "meeting at 3pm") and place it in the right grid slot; otherwise ask which hour or default to next open slot.
5. **Default reminder** — Every task automatically gets a reminder notification 15 minutes before its scheduled time, unless the user changes it.
6. **Completion check-in** — 5 minutes after a task's scheduled time passes, the app sends a notification asking "Did you complete [task]?" with Yes/No actions. If "Yes," the task is marked complete and shown with strikethrough in the grid. If "No" or ignored, task stays open.
7. Manual add/edit/delete task (typed, as a fallback to voice)
8. Mark complete/incomplete manually (tap task, or from the check-in notification)

## Explicitly OUT of scope for v1
- Multi-day/week *grid* view — day navigation (scroll/swipe day-to-day, jump to date) is in scope, but seeing multiple days side-by-side at once is not
- Full hands-free "Hey Siri"-style always-listening activation (see note below)
- Natural language for complex recurring phrases ("every weekday at 9" spoken aloud) — recurring tasks are supported (see Milestones), but set up manually, not via voice, in v1
- Collaboration/sharing

## Important note on "voice activated"
There are two very different things this could mean, with very different build effort:
- **A: Tap-to-talk** — user taps a mic button, then speaks. Straightforward with the Speech framework. This is the v1 default below.
- **B: Always-listening / wake-word activation** ("Hey Planner, add a task...") — requires either a SiriKit App Intent integration (Siri handles the wake word, hands off to your app) or continuous background audio processing, which has significant battery, privacy, and App Store review implications.

**Recommendation:** Build **A (tap-to-talk)** for v1, and consider a **SiriKit App Intent** as a v1.1 add-on (lets users say "Hey Siri, add a task in [app]" — Apple handles the wake-word detection, you just handle the request). This gets you voice activation without the complexity/battery cost of always-listening.

## Data Model
```
Task
- id: UUID
- title: String
- notes: String?
- scheduledDate: Date        // the day
- startHour: Int             // hour slot, e.g. 14 for 2 PM
- durationMinutes: Int       // default 60, for grid block sizing
- reminderMinutesBefore: Int // default 15
- isCompleted: Bool
- checkInSent: Bool          // tracks whether the 5-min-after prompt fired
- createdAt: Date
- recurrenceRule: RecurrenceRule?  // nil = one-off task
- recurrenceParentId: UUID?  // links generated instances back to the original recurring task
```

```
RecurrenceRule (enum or struct)
- frequency: daily | weekly | weekdays | custom(days: [Weekday])
- endDate: Date?   // nil = repeats indefinitely
```

## Screens
1. **Hourly Grid (main view)**
   - Vertical scroll, one row per hour, current hour highlighted (only when viewing today)
   - Horizontal swipe/scroll to move between days (yesterday, today, tomorrow, and beyond in either direction)
   - Date picker icon in toolbar to jump directly to a specific date
   - Task blocks placed in their hour row, sized roughly by duration
   - Completed tasks shown with strikethrough
   - Mic button (toolbar or floating) for voice entry
   - "+" button for manual entry (fallback)
2. **Add/Edit Task (sheet)**
   - Title, notes, date/hour picker, duration, reminder offset (default 15 min, editable)
   - Save / Cancel
3. **Voice entry flow**
   - Mic button → recording indicator → transcribed text shown for confirmation → user confirms or edits → task created

## Notification Logic
- On task creation: schedule a local notification for `startHour - reminderMinutesBefore`
- On task creation: schedule a second local notification for `startHour + durationMinutes + 5min` — the completion check-in, with Yes/No actions
- If task is marked complete manually before the check-in fires, cancel the pending check-in notification
- Handle notification actions via `UNUserNotificationCenterDelegate` to update the task's `isCompleted` state directly from Yes/No, without opening the app

## Milestones (build in this order)
1. **Project setup** — Multiplatform SwiftData project, compiles on iOS + Mac.
2. **Manual CRUD + hourly grid UI** — Add/edit/delete tasks by typing, displayed correctly in the hour grid. No voice, no notifications yet.
3. **Day navigation + jump to date** — Swipe/scroll to adjacent days (before and after today, and beyond), plus a date picker to jump directly to any date. Confirm tasks load correctly for whichever day is in view.
4. **Reminder notifications** — 15-min-before reminder fires correctly (test with a task scheduled a few minutes out).
5. **Completion check-in notifications** — 5-min-after prompt fires, Yes/No actions correctly update task state and strikethrough.
6. **Recurring tasks** — Add recurrence options to the Add/Edit Task screen (daily, weekly, weekdays, custom). On save, generate task instances per `RecurrenceRule`. Editing/deleting should ask "this occurrence only" vs. "all future occurrences."
7. **Voice entry (tap-to-talk)** — Mic button, transcription, confirm-and-create flow.
8. **CloudKit sync** — Confirm tasks sync between iPhone and Mac.
9. **Polish** — Empty states, permission-request flows (microphone + notifications), visual pass.

## Permissions you'll need to request
- Microphone access (`NSMicrophoneUsageDescription`)
- Speech recognition access (`NSSpeechRecognitionUsageDescription`)
- Notification permission (requested via `UNUserNotificationCenter`)

## How this gets built
Hand this spec to Claude Code on your Mac, one milestone at a time — don't ask for the whole app in one shot. After each milestone, build in Xcode, test the specific behavior (e.g., "does the check-in notification fire 5 minutes after?"), and report back what works or breaks before moving on.