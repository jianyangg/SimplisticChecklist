import Foundation

struct ChecklistDisplayPreferences {
    private static let completedVisibilityPrefix = "simplisticChecklist.showsCompleted."

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func showsCompleted(for checklistID: UUID) -> Bool {
        let key = completedVisibilityKey(for: checklistID)
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    func setShowsCompleted(_ showsCompleted: Bool, for checklistID: UUID) {
        defaults.set(showsCompleted, forKey: completedVisibilityKey(for: checklistID))
    }

    private func completedVisibilityKey(for checklistID: UUID) -> String {
        Self.completedVisibilityPrefix + checklistID.uuidString
    }
}
