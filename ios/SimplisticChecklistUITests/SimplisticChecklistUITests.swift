import XCTest

final class SimplisticChecklistUITests: XCTestCase {
    func testFreshChecklistShowsOneComposerAction() {
        let app = launchFreshApp()

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["New item"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["empty-add-item-button"].exists)
    }

    func testCanAddAndCompleteItem() {
        let app = launchFreshApp()
        let composer = app.textFields["New item"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))

        composer.tap()
        composer.typeText("Buy milk")
        app.buttons["Add item"].tap()

        let completeButton = app.buttons["Mark Buy milk complete"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()
        XCTAssertTrue(app.buttons["Mark Buy milk incomplete"].waitForExistence(timeout: 5))
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

    func testCanCreateRenameAndSwitchLists() {
        let app = launchFreshApp()
        app.buttons["new-list-button"].tap()

        let nameField = app.textFields["List name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.typeText("Errands")
        app.buttons["save-list-button"].tap()

        let errandsLabel = app.buttons["Errands"]
        XCTAssertTrue(errandsLabel.waitForExistence(timeout: 5))
        errandsLabel.tap()

        app.buttons["list-actions-button"].tap()
        app.buttons["rename-list-button"].tap()
        let renameField = app.textFields["List name"]
        XCTAssertTrue(renameField.waitForExistence(timeout: 5))
        renameField.typeText(" updated")
        app.buttons["save-list-button"].tap()
        XCTAssertTrue(app.buttons["Errands updated"].waitForExistence(timeout: 5))
    }

    func testCanHideAndClearCompletedItems() {
        let app = launchFreshApp()
        addItem("Completed task", to: app)
        app.buttons["Mark Completed task complete"].tap()

        app.buttons["list-actions-button"].tap()
        app.buttons["show-completed-toggle"].tap()
        XCTAssertFalse(app.buttons["Mark Completed task incomplete"].exists)

        app.buttons["list-actions-button"].tap()
        app.buttons["clear-completed-button"].tap()
        app.buttons["Clear Completed"].tap()
        XCTAssertFalse(app.buttons["Mark Completed task complete"].waitForExistence(timeout: 2))
    }

    func testCanUndoAndRedoItemMutation() {
        let app = launchFreshApp()
        addItem("Undoable task", to: app)
        XCTAssertTrue(app.buttons["Undoable task"].waitForExistence(timeout: 5))

        app.buttons["list-actions-button"].tap()
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertFalse(app.buttons["Undoable task"].waitForExistence(timeout: 2))

        app.buttons["list-actions-button"].tap()
        XCTAssertTrue(app.buttons["Redo"].waitForExistence(timeout: 5))
        app.buttons["Redo"].tap()
        XCTAssertTrue(app.buttons["Undoable task"].waitForExistence(timeout: 5))
    }

    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-in-memory"]
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
}
