import Foundation

enum ChecklistDuplicateNameGenerator {
    static func name(for sourceName: String, existingNames: [String]) -> String {
        let copyWord = String(localized: "Copy", comment: "Suffix used for a duplicated checklist name.")
        let existingKeys = Set(existingNames.map(nameKey))
        let firstCandidate = candidate(
            sourceName: sourceName,
            suffix: " \(copyWord)"
        )
        guard existingKeys.contains(nameKey(firstCandidate)) else {
            return firstCandidate
        }

        var number = 2
        var numberedCandidate = candidate(
            sourceName: sourceName,
            suffix: " \(copyWord) \(number)"
        )
        while existingKeys.contains(nameKey(numberedCandidate)) {
            number += 1
            numberedCandidate = candidate(
                sourceName: sourceName,
                suffix: " \(copyWord) \(number)"
            )
        }
        return numberedCandidate
    }

    private static func candidate(sourceName: String, suffix: String) -> String {
        let maximumLength = ChecklistInputValidator.maximumListNameLength
        let boundedSuffix = String(suffix.prefix(maximumLength))
        let availableCharacters = max(0, maximumLength - boundedSuffix.count)
        let boundedSource = String(sourceName.prefix(availableCharacters))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String((boundedSource + boundedSuffix).prefix(maximumLength))
    }

    private static func nameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}
