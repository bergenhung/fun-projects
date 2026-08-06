import Foundation

enum GridConfig {
    static let startHour = 6
    static let endHour = 22
    static let hourHeight: CGFloat = 64
    static let hourGutterWidth: CGFloat = 52

    static let durationOptions = [15, 30, 45, 60, 90, 120]
    static let reminderOptions = [0, 5, 10, 15, 30, 60]

    static func hourLabel(_ hour: Int) -> String {
        let normalized = ((hour % 24) + 24) % 24
        let period = normalized < 12 ? "AM" : "PM"
        let displayHour = normalized % 12 == 0 ? 12 : normalized % 12
        return "\(displayHour) \(period)"
    }

    static func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = Double(minutes) / 60
        return hours.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(hours)) hr"
            : String(format: "%.1f hr", hours)
    }

    static func reminderLabel(_ minutes: Int) -> String {
        minutes == 0 ? "At start time" : "\(minutes) min before"
    }
}
