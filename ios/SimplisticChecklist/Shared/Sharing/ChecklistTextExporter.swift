import Foundation

enum ChecklistTextExporter {
    static func text(for checklist: Checklist) -> String {
        let itemLines = checklist.items
            .sorted(by: ChecklistOrderer.itemSort)
            .map { item in
                "[\(item.isCompleted ? "x" : " ")] \(item.title)"
            }

        guard !itemLines.isEmpty else { return checklist.name }
        return ([checklist.name, ""] + itemLines).joined(separator: "\n")
    }
}
