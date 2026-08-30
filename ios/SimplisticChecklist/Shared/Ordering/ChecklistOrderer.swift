import Foundation

enum ChecklistOrderer {
    static func itemSort(_ lhs: ChecklistItem, _ rhs: ChecklistItem) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }
        return sortOrder(lhs, rhs)
    }

    static func sortOrder(_ lhs: ChecklistItem, _ rhs: ChecklistItem) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func checklistSort(_ lhs: Checklist, _ rhs: Checklist) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func normalize(_ checklists: [Checklist]) {
        for (index, checklist) in checklists.sorted(by: checklistSort).enumerated() {
            checklist.sortOrder = index
            for (itemIndex, item) in checklist.items.sorted(by: itemSort).enumerated() {
                item.sortOrder = itemIndex
            }
        }
    }

    static func normalizedIDs(_ ids: [UUID], from group: [ChecklistItem]) -> [UUID] {
        let validIDs = Set(group.map(\.id))
        var seen = Set<UUID>()
        return ids.filter { validIDs.contains($0) && seen.insert($0).inserted }
    }
}
