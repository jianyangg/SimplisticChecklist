import SwiftUI

struct ListRowView: View {
    let checklist: Checklist

    private var remainingCount: Int {
        checklist.items.reduce(into: 0) { count, item in
            if !item.isCompleted { count += 1 }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(checklist.name)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            if remainingCount > 0 {
                Text("\(remainingCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityLabel(ChecklistStrings.remaining(remainingCount))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(checklist.name)
        .accessibilityValue(
            remainingCount == 0
                ? ChecklistStrings.allItemsComplete
                : ChecklistStrings.remaining(remainingCount)
        )
        .accessibilityIdentifier("checklist-row-\(checklist.id.uuidString)")
    }
}
