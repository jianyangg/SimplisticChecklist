import Foundation

enum LegacyPreferenceKeys {
    static let sharedPreferencesPrefix = "flutter."
    static let masterChecklist = "masterChecklist7dL5&gK9q@2mF"
    static let tutorialChecklist = "main7dL5&gK9q@2mF"
    static let lastLoadedList = "lastLoadedList"

    static let nativeMigrationCompleted = "simplisticChecklist.nativeMigration.v1.completed"
    static let nativeSelectedChecklistID = "simplisticChecklist.selectedChecklistID"

    static var masterChecklistKey: String {
        prefixed(masterChecklist)
    }

    static var tutorialChecklistKey: String {
        prefixed(tutorialChecklist)
    }

    static var tutorialCompletionKey: String {
        completionKey(for: tutorialChecklist)
    }

    static var lastLoadedListKey: String {
        prefixed(lastLoadedList)
    }

    static func itemKey(for listName: String) -> String {
        prefixed(listName)
    }

    static func completionKey(for listName: String) -> String {
        prefixed("\(listName)_completion")
    }

    private static func prefixed(_ key: String) -> String {
        "\(sharedPreferencesPrefix)\(key)"
    }
}

protocol LegacyPreferenceReading {
    func value(forKey key: String) -> Any?
}

struct UserDefaultsLegacyPreferenceReader: LegacyPreferenceReading {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func value(forKey key: String) -> Any? {
        defaults.object(forKey: key)
    }
}

struct DictionaryLegacyPreferenceReader: LegacyPreferenceReading {
    let values: [String: Any]

    func value(forKey key: String) -> Any? {
        values[key]
    }
}
