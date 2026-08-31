import XCTest

@MainActor
final class SimplisticChecklistUITests: XCTestCase {
    func testFreshChecklistShowsOneComposerAction() {
        let app = launchFreshApp()

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["New item"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[UIIdentifier.emptyAddItemButton].exists)
        XCTAssertFalse(app.buttons[UIIdentifier.editListsButton].exists)
    }

    func testCommandNOpensTheNewListPrompt() {
        let app = launchFreshApp()

        app.typeKey("n", modifierFlags: .command)

        XCTAssertTrue(app.textFields["List name"].waitForExistence(timeout: 5))
    }

    func testCanAddMultipleItemsAsOneAction() {
        let app = launchFreshApp()
        openListActions(in: app)
        app.buttons[UIIdentifier.addMultipleItemsButton].tap()

        let editor = app.textViews[UIIdentifier.bulkItemEditor]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Passport\nBook hotel\nCall bank")
        app.buttons[UIIdentifier.bulkItemAddButton].tap()

        XCTAssertTrue(app.buttons["Passport"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Book hotel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Call bank"].waitForExistence(timeout: 5))

        openListActions(in: app)
        app.buttons[UIIdentifier.undoButton].tap()
        XCTAssertFalse(app.buttons["Passport"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Book hotel"].exists)
        XCTAssertFalse(app.buttons["Call bank"].exists)
    }

    func testSingleItemDoesNotOfferMeaninglessReordering() {
        let app = launchFreshApp()
        addItem("Only item", to: app)

        openListActions(in: app)

        XCTAssertFalse(app.buttons[UIIdentifier.editOrderButton].exists)
        XCTAssertFalse(app.buttons[UIIdentifier.showCompletedToggle].exists)
        XCTAssertFalse(app.buttons[UIIdentifier.markAllIncompleteButton].exists)
        XCTAssertFalse(app.buttons[UIIdentifier.clearCompletedButton].exists)
        XCTAssertTrue(app.buttons[UIIdentifier.shareListButton].exists)
    }

    func testCanAddSeveralItemsWithReturn() {
        let app = launchFreshApp()
        let composer = app.textFields["New item"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))

        for title in ["Buy milk", "Call bank", "Book hotel"] {
            composer.tap()
            composer.typeText(title)
            composer.typeText("\n")
        }

        XCTAssertTrue(app.buttons["Buy milk"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Call bank"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Book hotel"].waitForExistence(timeout: 5))
    }

    func testCanCompleteAndUncompleteItem() {
        let app = launchFreshApp()
        addItem("Buy milk", to: app)

        let completeButton = app.buttons["Mark Buy milk complete"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        XCTAssertTrue(app.staticTexts["All items complete"].waitForExistence(timeout: 5))
        let incompleteButton = app.buttons["Mark Buy milk incomplete"]
        XCTAssertTrue(incompleteButton.waitForExistence(timeout: 5))
        incompleteButton.tap()
        XCTAssertTrue(app.staticTexts["1 item remaining"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mark Buy milk complete"].waitForExistence(timeout: 5))
    }

    func testCanEditAndDeleteItem() {
        let app = launchFreshApp()
        addItem("Draft report", to: app)

        let titleButton = app.buttons["Draft report"]
        XCTAssertTrue(titleButton.waitForExistence(timeout: 5))
        titleButton.tap()

        let editor = app.textFields["Edit item"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(" updated")
        app.buttons["Save item"].tap()
        XCTAssertTrue(app.buttons["Draft report updated"].waitForExistence(timeout: 5))

        app.buttons["Draft report updated"].press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        app.buttons["Delete"].tap()
        XCTAssertFalse(app.buttons["Draft report updated"].waitForExistence(timeout: 2))
    }

    func testCanDeleteAndUndoItem() {
        let app = launchFreshApp()
        addItem("Undoable task", to: app)
        app.buttons["Undoable task"].press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        app.buttons["Delete"].tap()
        XCTAssertFalse(app.buttons["Undoable task"].waitForExistence(timeout: 2))

        openListActions(in: app)
        XCTAssertTrue(app.buttons[UIIdentifier.undoButton].waitForExistence(timeout: 5))
        app.buttons[UIIdentifier.undoButton].tap()
        XCTAssertTrue(app.buttons["Undoable task"].waitForExistence(timeout: 5))
    }

    func testCanCreateRenameAndSwitchLists() {
        let app = launchFreshApp()
        createList("Errands", in: app)
        app.buttons["Errands"].tap()
        addItem("Restored task", to: app)

        openListActions(in: app)
        app.buttons[UIIdentifier.renameListButton].tap()
        let renameField = app.textFields["List name"]
        XCTAssertTrue(renameField.waitForExistence(timeout: 5))
        renameField.typeText(" updated")
        app.buttons[UIIdentifier.saveListButton].tap()
        XCTAssertTrue(app.buttons["Errands updated"].waitForExistence(timeout: 5))
    }

    func testCanDuplicateAList() {
        let app = launchFreshApp()
        addItem("Reusable item", to: app)

        openListActions(in: app)
        app.buttons[UIIdentifier.duplicateListButton].tap()

        XCTAssertTrue(app.buttons["Checklist Copy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Reusable item"].waitForExistence(timeout: 5))
    }

    func testCanMoveAnItemToAnotherList() {
        let app = launchFreshApp()
        addItem("Move me", to: app)
        createList("Destination", in: app)
        app.buttons["Checklist"].tap()

        app.buttons["Move me"].press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Move to List"].waitForExistence(timeout: 5))
        app.buttons["Move to List"].tap()
        app.buttons["Destination"].tap()

        XCTAssertFalse(app.buttons["Move me"].waitForExistence(timeout: 2))
        app.buttons["Destination"].tap()
        XCTAssertTrue(app.buttons["Move me"].waitForExistence(timeout: 5))
    }

    func testCanHideShowAndClearCompletedItems() {
        let app = launchFreshApp()
        addItem("Completed task", to: app)
        app.buttons["Mark Completed task complete"].tap()

        openListActions(in: app)
        app.buttons[UIIdentifier.showCompletedToggle].tap()
        XCTAssertFalse(app.buttons["Mark Completed task incomplete"].exists)

        openListActions(in: app)
        app.buttons[UIIdentifier.showCompletedToggle].tap()
        XCTAssertTrue(app.buttons["Mark Completed task incomplete"].waitForExistence(timeout: 5))

        openListActions(in: app)
        app.buttons[UIIdentifier.showCompletedToggle].tap()
        app.buttons[UIIdentifier.clearCompletedButton].tap()
        app.buttons["Clear Completed"].tap()
        XCTAssertFalse(app.buttons["Mark Completed task complete"].waitForExistence(timeout: 2))
    }

    func testCanReorderItems() {
        let app = launchFreshApp()
        addItem("First", to: app)
        addItem("Second", to: app)

        openListActions(in: app)
        XCTAssertTrue(app.buttons[UIIdentifier.editOrderButton].waitForExistence(timeout: 5))
        app.buttons[UIIdentifier.editOrderButton].tap()

        let first = app.staticTexts["First"]
        let second = app.staticTexts["Second"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        second.press(forDuration: 0.8, thenDragTo: first)

        XCTAssertTrue(app.buttons[UIIdentifier.detailDoneButton].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForVerticalOrder(upper: second, lower: first))
        app.buttons[UIIdentifier.detailDoneButton].tap()
    }

    func testCanReorderCompletedItemsWithinTheirGroup() {
        let app = launchFreshApp()
        addItem("Done one", to: app)
        addItem("Done two", to: app)
        app.buttons["Mark Done one complete"].tap()
        app.buttons["Mark Done two complete"].tap()

        openListActions(in: app)
        app.buttons[UIIdentifier.editOrderButton].tap()
        let first = app.staticTexts["Done one"]
        let second = app.staticTexts["Done two"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        second.press(forDuration: 0.8, thenDragTo: first)
        XCTAssertTrue(waitForVerticalOrder(upper: second, lower: first))
        app.buttons[UIIdentifier.detailDoneButton].tap()
    }

    func testCanUndoAndRedoItemMutation() {
        let app = launchFreshApp()
        addItem("Undoable task", to: app)
        XCTAssertTrue(app.buttons["Undoable task"].waitForExistence(timeout: 5))

        openListActions(in: app)
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertFalse(app.buttons["Undoable task"].waitForExistence(timeout: 2))

        openListActions(in: app)
        XCTAssertTrue(app.buttons[UIIdentifier.redoButton].waitForExistence(timeout: 5))
        app.buttons[UIIdentifier.redoButton].tap()
        XCTAssertTrue(app.buttons["Undoable task"].waitForExistence(timeout: 5))
    }

    func testCanDeleteAListAndFallBackToAnotherSelection() {
        let app = launchFreshApp()
        createList("Errands", in: app)
        app.buttons["Errands"].tap()
        addItem("Restored task", to: app)

        openListActions(in: app)
        XCTAssertTrue(app.buttons["Delete List…"].waitForExistence(timeout: 5))
        app.buttons[UIIdentifier.deleteListButton].tap()
        XCTAssertTrue(app.buttons[UIIdentifier.deleteListConfirmationButton].waitForExistence(timeout: 5))
        app.buttons[UIIdentifier.deleteListConfirmationButton].tap()

        XCTAssertFalse(app.buttons["Errands"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["New item"].waitForExistence(timeout: 5))

        openListActions(in: app)
        app.buttons[UIIdentifier.undoButton].tap()
        XCTAssertTrue(app.buttons["Restored task"].waitForExistence(timeout: 5))
    }

    func testCanMarkAllItemsIncomplete() {
        let app = launchFreshApp()
        addItem("One", to: app)
        addItem("Two", to: app)
        app.buttons["Mark One complete"].tap()
        app.buttons["Mark Two complete"].tap()

        openListActions(in: app)
        XCTAssertTrue(app.buttons[UIIdentifier.markAllIncompleteButton].waitForExistence(timeout: 5))
        app.buttons[UIIdentifier.markAllIncompleteButton].tap()
        XCTAssertTrue(app.buttons["Mark One complete"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mark Two complete"].waitForExistence(timeout: 5))
    }

    func testCanClearCompletedAndUndo() {
        let app = launchFreshApp()
        addItem("Temporary", to: app)
        app.buttons["Mark Temporary complete"].tap()

        openListActions(in: app)
        app.buttons[UIIdentifier.clearCompletedButton].tap()
        app.buttons[UIIdentifier.clearCompletedConfirmationButton].tap()
        XCTAssertFalse(app.buttons["Temporary"].waitForExistence(timeout: 2))

        openListActions(in: app)
        app.buttons[UIIdentifier.undoButton].tap()
        XCTAssertTrue(app.buttons["Temporary"].waitForExistence(timeout: 5))
    }

    func testCanReorderListsInExplicitEditMode() {
        let app = launchFreshApp()
        createList("One", in: app)
        createList("Two", in: app)

        XCTAssertTrue(app.buttons[UIIdentifier.editListsButton].waitForExistence(timeout: 5))
        app.buttons[UIIdentifier.editListsButton].tap()
        let first = app.buttons["Checklist"]
        let last = app.buttons["Two"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(last.waitForExistence(timeout: 5))
        last.press(forDuration: 0.8, thenDragTo: first)
        XCTAssertTrue(waitForVerticalOrder(upper: last, lower: first))
        XCTAssertTrue(app.buttons[UIIdentifier.editListsButton].waitForExistence(timeout: 5))
        app.buttons[UIIdentifier.editListsButton].tap()
    }

    func testCanPersistSelectedListAcrossRelaunch() {
        let app = launchPersistentApp(reset: true)
        createList("Persistent", in: app)
        app.buttons["Persistent"].tap()
        addItem("Survives relaunch", to: app)

        app.terminate()
        app.launchArguments = ["--ui-testing-persistent"]
        app.launch()

        XCTAssertTrue(app.buttons["Persistent"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Survives relaunch"].waitForExistence(timeout: 5))
    }

    func testCompletedVisibilityPersistsAcrossRelaunch() {
        let app = launchPersistentApp(reset: true)
        addItem("Hidden after relaunch", to: app)
        app.buttons["Mark Hidden after relaunch complete"].tap()
        openListActions(in: app)
        app.buttons[UIIdentifier.showCompletedToggle].tap()
        XCTAssertFalse(app.buttons["Hidden after relaunch"].exists)

        app.terminate()
        app.launchArguments = ["--ui-testing-persistent"]
        app.launch()

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[UIIdentifier.listActionsButton].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Hidden after relaunch"].exists)
        openListActions(in: app)
        app.buttons[UIIdentifier.showCompletedToggle].tap()
        XCTAssertTrue(app.buttons["Hidden after relaunch"].waitForExistence(timeout: 5))
    }

    func testSeededLegacyLaunchMigratesListsAndItems() {
        let app = launchSeededLegacyApp()

        XCTAssertTrue(app.buttons["Migrated Work"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Migrated Personal"].waitForExistence(timeout: 5))
        app.buttons["Migrated Work"].tap()
        XCTAssertTrue(app.buttons["Review the migration"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mark Keep this task incomplete"].waitForExistence(timeout: 5))
    }

    func testSeededLegacyMigrationIsIdempotentAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing-persistent",
            "--ui-testing-reset-persistent",
            "--ui-testing-seeded-legacy"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["Migrated Work"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["--ui-testing-persistent", "--ui-testing-seeded-legacy"]
        app.launch()

        XCTAssertEqual(app.buttons.matching(identifier: "Migrated Work").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "Migrated Personal").count, 1)
        app.buttons["Migrated Work"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "Review the migration").count, 1)
    }

    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-in-memory"]
        app.launch()
        return app
    }

    private func launchPersistentApp(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing-persistent",
            reset ? "--ui-testing-reset-persistent" : ""
        ].filter { !$0.isEmpty }
        app.launch()
        return app
    }

    private func launchSeededLegacyApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-seeded-legacy"]
        app.launch()
        return app
    }

    private func addItem(_ title: String, to app: XCUIApplication) {
        let composer = app.textFields["New item"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText(title)
        app.buttons["Add item"].tap()
    }

    private func createList(_ name: String, in app: XCUIApplication) {
        app.buttons[UIIdentifier.newListButton].tap()
        let field = app.textFields["List name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(name)
        app.buttons[UIIdentifier.saveListButton].tap()
        XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 5))
    }

    private func openListActions(in app: XCUIApplication) {
        app.buttons[UIIdentifier.listActionsButton].tap()
    }

    private func waitForVerticalOrder(
        upper: XCUIElement,
        lower: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if upper.exists, lower.exists, upper.frame.minY < lower.frame.minY {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return upper.exists && lower.exists && upper.frame.minY < lower.frame.minY
    }
}

private enum UIIdentifier {
    static let emptyAddItemButton = "empty-add-item-button"
    static let newListButton = "new-list-button"
    static let listActionsButton = "list-actions-button"
    static let renameListButton = "rename-list-button"
    static let saveListButton = "save-list-button"
    static let showCompletedToggle = "show-completed-toggle"
    static let clearCompletedButton = "clear-completed-button"
    static let clearCompletedConfirmationButton = "clear-completed-confirmation-button"
    static let markAllIncompleteButton = "mark-all-incomplete-button"
    static let deleteListButton = "delete-list-button"
    static let deleteListConfirmationButton = "delete-list-confirmation-button"
    static let editOrderButton = "edit-order-button"
    static let detailDoneButton = "detail-done-button"
    static let undoButton = "undo-button"
    static let redoButton = "redo-button"
    static let editListsButton = "edit-lists-button"
    static let addMultipleItemsButton = "add-multiple-items-button"
    static let duplicateListButton = "duplicate-list-button"
    static let shareListButton = "share-list-button"
    static let bulkItemEditor = "bulk-item-editor"
    static let bulkItemAddButton = "bulk-item-add-button"
}
