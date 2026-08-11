import Foundation
import SwiftData

/// The V1 shape, frozen exactly as it was on disk before this fix: a single
/// `recurrenceRule: RecurrenceRule?` property, stored directly via SwiftData's
/// automatic Codable-transformable handling. **Do not use this type outside
/// this migration plan** — app code should use the live `PlannerTask` in
/// [PlannerTask.swift](../Models/PlannerTask.swift) (== `SchemaV2.PlannerTask`).
/// Kept only so `PlannerMigrationPlan` has something to migrate *from* — see
/// the "Past crash" note in CLAUDE.md for why this shape was replaced.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [PlannerTask.self] }

    @Model
    final class PlannerTask {
        var id: UUID = UUID()
        var title: String = ""
        var notes: String?
        var scheduledDate: Date = Date()
        var startHour: Int = 0
        var startMinute: Int = 0
        var durationMinutes: Int = 60
        var reminderMinutesBefore: Int = 15
        var isCompleted: Bool = false
        var checkInSent: Bool = false
        var createdAt: Date = Date()
        var recurrenceParentId: UUID?
        var recurrenceRule: RecurrenceRule?

        init() {}
    }
}

/// The current shape: recurrence is stored as flat, primitive-only fields
/// (`recurrenceFrequencyRaw`/`recurrenceCustomDays`/`recurrenceEndDate` on the
/// live `PlannerTask`) instead of the Codable `RecurrenceRule?` blob that V1
/// used — see `SchemaV1`'s doc comment for why. `PlannerTask.recurrenceRule`
/// is now a computed bridge over those fields, so every other call site keeps
/// working unchanged; SwiftData itself never sees a `RecurrenceRule` value.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [PlannerTask.self] }
}

enum PlannerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [migrateV1toV2] }

    /// Lightweight (not custom) deliberately: a custom stage's willMigrate/
    /// didMigrate closures would need to read the old `recurrenceRule` to
    /// carry it forward, re-triggering the exact fault-fulfillment path that
    /// crashes on a `.custom` value. Lightweight migration drops the old
    /// column without decoding it, so it can't hit that crash — at the cost
    /// of any previously-recurring task reverting to a one-off (everything
    /// else about it carries over; only the repeat setting resets).
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
