import Foundation

/// Command-line switches used by deterministic UI-test launches.
///
/// Production launches use the standard store and legacy preferences. UI tests
/// opt into one of the explicit modes below so a test never depends on a
/// previous test process or on a developer's personal defaults.
enum ChecklistLaunchConfiguration {
    static let freshInMemoryArgument = "--ui-testing-in-memory"
    static let persistentArgument = "--ui-testing-persistent"
    static let seededLegacyArgument = "--ui-testing-seeded-legacy"
    static let resetPersistentArgument = "--ui-testing-reset-persistent"

    static let uiTestingDefaultsSuite = "SimplisticChecklist.ui-testing"
    static let uiTestingStoreName = "SimplisticChecklist.ui-testing"

    private static var arguments: Set<String> {
        Set(ProcessInfo.processInfo.arguments)
    }

    static var isFreshInMemory: Bool {
        arguments.contains(freshInMemoryArgument)
    }

    static var isPersistent: Bool {
        arguments.contains(persistentArgument)
    }

    static var isSeededLegacy: Bool {
        arguments.contains(seededLegacyArgument)
    }

    static var resetsPersistentStore: Bool {
        arguments.contains(resetPersistentArgument)
    }

    static var isUITesting: Bool {
        isFreshInMemory || isPersistent || isSeededLegacy
    }

    static var selectionStore: UserDefaults {
        guard isUITesting else { return .standard }
        return UserDefaults(suiteName: uiTestingDefaultsSuite) ?? .standard
    }
}
