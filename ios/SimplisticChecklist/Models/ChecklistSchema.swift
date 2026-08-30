import SwiftData

enum ChecklistSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Checklist.self, ChecklistItem.self, ChecklistMigrationReceipt.self]
    }
}

enum ChecklistSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ChecklistSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
