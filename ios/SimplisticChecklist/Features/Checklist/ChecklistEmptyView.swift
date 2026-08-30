import SwiftUI

struct ChecklistEmptyView: View {
    enum State {
        case noItems
        case allItemsCompletedButHidden
    }

    let state: State
    let onShowCompleted: (() -> Void)?

    init(state: State, onShowCompleted: (() -> Void)? = nil) {
        self.state = state
        self.onShowCompleted = onShowCompleted
    }

    var body: some View {
        switch state {
        case .noItems:
            ContentUnavailableView {
                Label("No Items Yet", systemImage: "checklist")
            } description: {
                Text("Add an item below to start this checklist.")
            }
        case .allItemsCompletedButHidden:
            ContentUnavailableView {
                Label("All Done", systemImage: "checkmark.circle")
            } description: {
                Text("Completed items are hidden from this checklist.")
            } actions: {
                Button("Show Completed", action: { onShowCompleted?() })
                    .buttonStyle(.bordered)
            }
        }
    }
}
