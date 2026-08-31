import Foundation
import SwiftData

/// A complete, value-type representation of the checklist store.
///
/// Mutation commands use this small snapshot to record one precise history
/// entry. Keeping the snapshot independent from `UndoManager` also makes
/// relationship restoration deterministic for deletes and bulk commands.
struct ChecklistStoreSnapshot: Equatable {
    struct Item: Equatable {
        let id: UUID
        let title: String
        let isCompleted: Bool
        let sortOrder: Int
        let createdAt: Date
        let updatedAt: Date
    }

    struct List: Equatable {
        let id: UUID
        let name: String
        let sortOrder: Int
        let createdAt: Date
        let updatedAt: Date
        let items: [Item]
    }

    let lists: [List]

    init(context: ModelContext) throws {
        let fetchedLists = try context.fetch(FetchDescriptor<Checklist>())
        lists = fetchedLists.sorted(by: ChecklistOrderer.checklistSort).map { checklist in
            List(
                id: checklist.id,
                name: checklist.name,
                sortOrder: checklist.sortOrder,
                createdAt: checklist.createdAt,
                updatedAt: checklist.updatedAt,
                items: checklist.items.sorted(by: ChecklistOrderer.itemSort).map { item in
                    Item(
                        id: item.id,
                        title: item.title,
                        isCompleted: item.isCompleted,
                        sortOrder: item.sortOrder,
                        createdAt: item.createdAt,
                        updatedAt: item.updatedAt
                    )
                }
            )
        }
    }

    func apply(to context: ModelContext) throws {
        let existingLists = try context.fetch(FetchDescriptor<Checklist>())
        let existingItems = try context.fetch(FetchDescriptor<ChecklistItem>())
        let listsByID = Dictionary(uniqueKeysWithValues: existingLists.map { ($0.id, $0) })
        let itemsByID = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })
        let snapshotListIDs = Set(lists.map(\.id))
        let snapshotItemIDs = Set(lists.flatMap { $0.items.map(\.id) })

        // Clear inverse relationships before deleting or rebuilding so an
        // item restored to a different list cannot remain attached twice.
        for checklist in existingLists {
            checklist.items = []
        }
        for item in existingItems {
            item.checklist = nil
        }

        for item in existingItems where !snapshotItemIDs.contains(item.id) {
            context.delete(item)
        }
        for checklist in existingLists where !snapshotListIDs.contains(checklist.id) {
            context.delete(checklist)
        }

        for listSnapshot in lists {
            let checklist = listsByID[listSnapshot.id] ?? Checklist(
                id: listSnapshot.id,
                name: listSnapshot.name,
                sortOrder: listSnapshot.sortOrder,
                createdAt: listSnapshot.createdAt,
                updatedAt: listSnapshot.updatedAt
            )
            if listsByID[listSnapshot.id] == nil {
                context.insert(checklist)
            }

            checklist.name = listSnapshot.name
            checklist.sortOrder = listSnapshot.sortOrder
            checklist.createdAt = listSnapshot.createdAt
            checklist.updatedAt = listSnapshot.updatedAt

            for itemSnapshot in listSnapshot.items {
                let item = itemsByID[itemSnapshot.id] ?? ChecklistItem(
                    id: itemSnapshot.id,
                    title: itemSnapshot.title,
                    isCompleted: itemSnapshot.isCompleted,
                    sortOrder: itemSnapshot.sortOrder,
                    createdAt: itemSnapshot.createdAt,
                    updatedAt: itemSnapshot.updatedAt
                )
                if itemsByID[itemSnapshot.id] == nil {
                    context.insert(item)
                }

                item.title = itemSnapshot.title
                item.isCompleted = itemSnapshot.isCompleted
                item.sortOrder = itemSnapshot.sortOrder
                item.createdAt = itemSnapshot.createdAt
                item.updatedAt = itemSnapshot.updatedAt
                checklist.items.append(item)
                item.checklist = checklist
            }
        }
    }
}
