import SwiftUI
import SwiftData

@main
struct SimplisticChecklistApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var storeErrorMessage: String?

    init() {
        do {
            _modelContainer = State(initialValue: try Self.makeContainer())
            _storeErrorMessage = State(initialValue: nil)
        } catch {
            _modelContainer = State(initialValue: nil)
            _storeErrorMessage = State(initialValue: error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                AppRootView()
                    .modelContainer(modelContainer)
            } else {
                StoreUnavailableView(message: storeErrorMessage) {
                    reloadContainer()
                }
            }
        }
    }

    private func reloadContainer() {
        do {
            modelContainer = try Self.makeContainer()
            storeErrorMessage = nil
        } catch {
            storeErrorMessage = error.localizedDescription
        }
    }

    private static func makeContainer() throws -> ModelContainer {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-in-memory") {
            return try ModelContainerFactory.makeInMemory()
        }
        return try ModelContainerFactory.makePersistent()
    }
}

private struct StoreUnavailableView: View {
    let message: String?
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Storage Unavailable", systemImage: "externaldrive.badge.xmark")
        } description: {
            Text(message ?? "Your checklists could not be opened. Please try again.")
        } actions: {
            Button("Try Again", action: onRetry)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
