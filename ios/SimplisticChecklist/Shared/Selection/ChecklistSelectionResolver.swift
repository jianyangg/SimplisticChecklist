import Foundation

/// Resolves a persisted selection against the current model set.
///
/// A UUID is preferred only while its checklist exists. If a selected list was
/// deleted, deterministic ordering supplies the next valid fallback.
enum ChecklistSelectionResolver {
    static func resolve(preferred: UUID?, in checklists: [Checklist]) -> UUID? {
        let sorted = checklists.sorted(by: ChecklistOrderer.checklistSort)
        if let preferred, sorted.contains(where: { $0.id == preferred }) {
            return preferred
        }
        return sorted.first?.id
    }
}
