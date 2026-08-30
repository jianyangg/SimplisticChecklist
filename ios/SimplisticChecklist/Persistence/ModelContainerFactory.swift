import SwiftData

enum ModelContainerFactory {
    static func makePersistent() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "SimplisticChecklist",
            schema: Schema(versionedSchema: ChecklistSchemaV1.self),
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: Schema(versionedSchema: ChecklistSchemaV1.self),
            migrationPlan: ChecklistSchemaMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func makeInMemory() throws -> ModelContainer {
        let schema = Schema(versionedSchema: ChecklistSchemaV1.self)
        let configuration = ModelConfiguration(
            "InMemory",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: ChecklistSchemaMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
