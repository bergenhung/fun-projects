import Foundation
import SwiftData

/// Series-wide operations on recurring `PlannerTask` occurrences: bulk delete,
/// cascading "this and future" edits, and the rolling top-up that (a) materializes
/// new occurrence rows as the window advances and (b) schedules notifications for
/// occurrences that have just entered the notification horizon (see
/// `RecurrenceEngine` for why that horizon is much shorter than the
/// materialization window).
enum SeriesEditor {
    static func siblings(ofSeries recurrenceParentId: UUID, context: ModelContext) -> [PlannerTask] {
        let targetID: UUID? = recurrenceParentId
        let descriptor = FetchDescriptor<PlannerTask>(predicate: #Predicate<PlannerTask> { $0.recurrenceParentId == targetID })
        return (try? context.fetch(descriptor)) ?? []
    }

    static func deleteThisAndFuture(from task: PlannerTask, context: ModelContext) {
        guard let recurrenceParentId = task.recurrenceParentId else {
            NotificationScheduler.cancelAll(for: task)
            context.delete(task)
            return
        }
        let cutoff = task.scheduledDate
        for occurrence in siblings(ofSeries: recurrenceParentId, context: context) where occurrence.scheduledDate >= cutoff {
            NotificationScheduler.cancelAll(for: occurrence)
            context.delete(occurrence)
        }
    }

    static func deleteEntireSeries(recurrenceParentId: UUID, context: ModelContext) {
        for occurrence in siblings(ofSeries: recurrenceParentId, context: context) {
            NotificationScheduler.cancelAll(for: occurrence)
            context.delete(occurrence)
        }
    }

    /// Applies edited field values to every sibling occurrence dated on/after
    /// `task`'s date (not including `task` itself, which the caller already
    /// updated). Each sibling keeps its own `scheduledDate`/`isCompleted`.
    static func applyEditToThisAndFuture(
        from task: PlannerTask,
        title: String,
        notes: String?,
        startHour: Int,
        startMinute: Int,
        durationMinutes: Int,
        reminderMinutesBefore: Int,
        context: ModelContext
    ) {
        guard let recurrenceParentId = task.recurrenceParentId else { return }
        let cutoff = task.scheduledDate
        for occurrence in siblings(ofSeries: recurrenceParentId, context: context)
        where occurrence.id != task.id && occurrence.scheduledDate >= cutoff {
            occurrence.title = title
            occurrence.notes = notes
            occurrence.startHour = startHour
            occurrence.startMinute = startMinute
            occurrence.durationMinutes = durationMinutes
            occurrence.reminderMinutesBefore = reminderMinutesBefore
            occurrence.checkInSent = false
            NotificationScheduler.reschedule(for: occurrence)
        }
    }

    static func topUpAllSeries(context: ModelContext) {
        let descriptor = FetchDescriptor<PlannerTask>()
        guard let allTasks = try? context.fetch(descriptor) else { return }
        let seriesGroups = Dictionary(grouping: allTasks.filter { $0.recurrenceParentId != nil }, by: { $0.recurrenceParentId! })

        let today = Calendar.current.startOfDay(for: Date())
        guard let horizonEnd = Calendar.current.date(byAdding: .day, value: RecurrenceEngine.notificationHorizonDays, to: today) else { return }

        for (recurrenceParentId, occurrences) in seriesGroups {
            guard let template = occurrences.max(by: { $0.scheduledDate < $1.scheduledDate }),
                  let rule = template.recurrenceRule else { continue }

            let existingDates = Set(occurrences.map { Calendar.current.startOfDay(for: $0.scheduledDate) })
            let neededDates = RecurrenceEngine.occurrenceDates(startingAt: today, rule: rule)

            for occurrenceDate in neededDates where !existingDates.contains(Calendar.current.startOfDay(for: occurrenceDate)) {
                let newOccurrence = PlannerTask(
                    title: template.title,
                    notes: template.notes,
                    scheduledDate: occurrenceDate,
                    startHour: template.startHour,
                    startMinute: template.startMinute,
                    durationMinutes: template.durationMinutes,
                    reminderMinutesBefore: template.reminderMinutesBefore,
                    recurrenceParentId: recurrenceParentId,
                    recurrenceRule: rule
                )
                context.insert(newOccurrence)
                if occurrenceDate <= horizonEnd {
                    NotificationScheduler.reschedule(for: newOccurrence)
                }
            }

            // Occurrences that already existed but have only now rolled inside the
            // notification horizon (created before today, beyond the horizon at the
            // time) need their notifications scheduled too.
            for occurrence in occurrences
            where occurrence.scheduledDate >= today && occurrence.scheduledDate <= horizonEnd && !occurrence.isCompleted {
                NotificationScheduler.reschedule(for: occurrence)
            }
        }

        try? context.save()
    }
}
