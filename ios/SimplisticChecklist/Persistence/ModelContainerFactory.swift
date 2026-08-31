import Foundation
import SwiftData

enum ModelContainerFactory {
    static func makePersistent(named name: String = "SimplisticChecklist") throws -> ModelContainer {
        let configuration = ModelConfiguration(
            name,
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

    static func makePersistentUITesting(reset: Bool) throws -> ModelContainer {
        let directory = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("SimplisticChecklist", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let storeURL = directory.appendingPathComponent("ui-testing.sqlite")
        if reset {
            let fileManager = FileManager.default
            for suffix in ["", "-shm", "-wal", "-journal"] {
                try? fileManager.removeItem(at: directory.appendingPathComponent("ui-testing.sqlite\(suffix)"))
            }
        }
        return try makePersistent(
            named: ChecklistLaunchConfiguration.uiTestingStoreName,
            at: storeURL
        )
    }

    private static func makePersistent(named name: String, at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ChecklistSchemaV1.self)
        let configuration = ModelConfiguration(
            name,
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
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
