import Foundation

enum ChecklistInputError: LocalizedError, Equatable {
    case emptyListName
    case listNameTooLong
    case duplicateListName
    case emptyItemTitle
    case itemTitleTooLong

    var errorDescription: String? {
        switch self {
        case .emptyListName:
            "Enter a list name."
        case .listNameTooLong:
            "List names can be up to 80 characters."
        case .duplicateListName:
            "A list with this name already exists."
        case .emptyItemTitle:
            "Item text cannot be empty."
        case .itemTitleTooLong:
            "Items can be up to 500 characters."
        }
    }
}

enum ChecklistInputValidator {
    static let maximumListNameLength = 80
    static let maximumItemTitleLength = 500

    static func listName(_ value: String, existingNames: [String] = []) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw ChecklistInputError.emptyListName }
        guard normalized.count <= maximumListNameLength else {
            throw ChecklistInputError.listNameTooLong
        }

        let duplicate = existingNames.contains { existingName in
            existingName.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(normalized) == .orderedSame
        }
        guard !duplicate else { throw ChecklistInputError.duplicateListName }
        return normalized
    }

    static func itemTitle(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw ChecklistInputError.emptyItemTitle }
        guard normalized.count <= maximumItemTitleLength else {
            throw ChecklistInputError.itemTitleTooLong
        }
        return normalized
    }
}
