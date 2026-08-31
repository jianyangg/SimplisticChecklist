import Foundation

enum ChecklistBulkItemParser {
    static func titles(from text: String) throws -> [String] {
        let nonemptyLines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !nonemptyLines.isEmpty else {
            throw ChecklistInputError.emptyItemTitle
        }
        return try nonemptyLines.map(ChecklistInputValidator.itemTitle)
    }
}
