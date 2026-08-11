import Foundation

enum GridConfig {
    static let startHour = 7
    static let endHour = 19
    static let hourHeight: CGFloat = 64
    static let hourGutterWidth: CGFloat = 52

    static let durationOptions = [15, 30, 45, 60, 75, 90, 105, 120]
    static let reminderOptions = [0, 5, 10, 15, 30, 60]
    static let minuteOptions = [0, 15, 30, 45]

    static func hourLabel(_ hour: Int) -> String {
        let normalized = ((hour % 24) + 24) % 24
        let period = normalized < 12 ? "AM" : "PM"
        let displayHour = normalized % 12 == 0 ? 12 : normalized % 12
        return "\(displayHour) \(period)"
    }

    /// Full clock time, e.g. "9 AM" when on the hour, "9:15 AM" otherwise.
    static func timeLabel(hour: Int, minute: Int) -> String {
        guard minute != 0 else { return hourLabel(hour) }
        let normalized = ((hour % 24) + 24) % 24
        let period = normalized < 12 ? "AM" : "PM"
        let displayHour = normalized % 12 == 0 ? 12 : normalized % 12
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    static func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours) hr \(remainder) min"
    }

    static func reminderLabel(_ minutes: Int) -> String {
        minutes == 0 ? "At start time" : "\(minutes) min before"
    }

    /// The earliest quarter-hour slot at or after `hour:minute` with no existing
    /// task, wrapping back to the start of the grid if the rest of the day is full.
    static func nextOpenSlot(
        for tasks: [PlannerTask],
        from hour: Int = Calendar.current.component(.hour, from: Date()),
        minute: Int = 0
    ) -> (hour: Int, minute: Int) {
        let occupied = Set(tasks.map { $0.startHour * 60 + $0.startMinute })
        let snappedMinute = minuteOptions.min(by: { abs($0 - minute) < abs($1 - minute) }) ?? 0
        let clampedStartTotal = min(max(hour * 60 + snappedMinute, startHour * 60), (endHour - 1) * 60 + 45)

        let allSlots = stride(from: startHour * 60, to: endHour * 60, by: 15)
        if let open = allSlots.first(where: { $0 >= clampedStartTotal && !occupied.contains($0) }) {
            return (open / 60, open % 60)
        }
        if let open = allSlots.first(where: { $0 < clampedStartTotal && !occupied.contains($0) }) {
            return (open / 60, open % 60)
        }
        return (clampedStartTotal / 60, clampedStartTotal % 60)
    }
}
