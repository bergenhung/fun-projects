import Foundation

/// Extracts a spoken time (e.g. "meeting at 3:15pm") from a voice-entry
/// transcript, using Foundation's date detector rather than hand-rolled time
/// parsing.
enum SpokenTaskParser {
    struct Result {
        let title: String
        let hour: Int?
        let minute: Int?
    }

    static func parse(_ transcript: String) -> Result {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Result(title: "", hour: nil, minute: nil) }

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return Result(title: trimmed, hour: nil, minute: nil)
        }

        let fullRange = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = detector.firstMatch(in: trimmed, range: fullRange),
              let matchRange = Range(match.range, in: trimmed),
              let date = match.date else {
            return Result(title: trimmed, hour: nil, minute: nil)
        }

        let rawHour = Calendar.current.component(.hour, from: date)
        let clampedHour = min(max(rawHour, GridConfig.startHour), GridConfig.endHour - 1)
        let rawMinute = Calendar.current.component(.minute, from: date)
        // Snap to the nearest quarter-hour the grid actually supports.
        let snappedMinute = GridConfig.minuteOptions.min(by: { abs($0 - rawMinute) < abs($1 - rawMinute) }) ?? 0

        var title = trimmed
        title.removeSubrange(matchRange)
        title = title.replacingOccurrences(
            of: #"\s+(at|on|for|around)\s*$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: ",."))
        if title.isEmpty { title = trimmed }

        return Result(title: title, hour: clampedHour, minute: snappedMinute)
    }
}
