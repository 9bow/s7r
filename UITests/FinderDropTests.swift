import XCTest

final class FinderDropTests: XCTestCase {
    @MainActor func testFinderFilesAndFolders() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "kr.s7r.local")
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        func tile(_ application: XCUIApplication, side: String) {
            application.activate()
            application.menuBars.menuBarItems["Window"].click()
            let monitor = application.menuItems["Move to DELL C3422WE"]
            if monitor.exists { monitor.click() } else { application.typeKey(.escape, modifierFlags: []) }
            application.menuBars.menuBarItems["Window"].click()
            application.menuItems["Move & Resize"].hover()
            application.menuItems[side].click()
        }
        func navigate(_ path: String) {
            finder.activate()
            finder.typeKey("g", modifierFlags: [.command, .shift])
            finder.typeText(path)
            finder.typeKey(.return, modifierFlags: [])
            finder.typeKey("2", modifierFlags: [.command])
        }
        func source(_ name: String) -> XCUIElement {
            finder.textFields.matching(NSPredicate(format: "value == %@ OR value == %@", name, name.decomposedStringWithCanonicalMapping)).firstMatch
        }
        func queueRow(_ name: String) -> XCUIElement {
            app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        }
        func drag(_ name: String) {
            finder.activate()
            let item = source(name)
            XCTAssertTrue(item.waitForExistence(timeout: 10), name)
            item.click(forDuration: 1, thenDragTo: app.windows.firstMatch)
        }
        tile(app, side: "Right")
        tile(finder, side: "Left")
        app.buttons["목록 비우기"].click()
        navigate(root.appendingPathComponent(".validation/finder-drop").path)
        drag("second sample.aiff")
        XCTAssertTrue(queueRow("second sample.aiff").waitForExistence(timeout: 10))
        drag("second sample.aiff")
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", ".aiff")).count, 1)
        app.buttons["목록 비우기"].click()
        navigate(root.appendingPathComponent(".validation").path)
        drag("finder-drop")
        XCTAssertTrue(queueRow("second sample.aiff").waitForExistence(timeout: 10))
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", ".aiff")).count, 2)
        XCTAssertFalse(queueRow("nested sample.aiff").exists)
        app.buttons["목록 비우기"].click()
        app.checkBoxes["하위 폴더 포함"].click()
        drag("finder-drop")
        XCTAssertTrue(queueRow("nested sample.aiff").waitForExistence(timeout: 10))
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", ".aiff")).count, 3)
        app.buttons["start"].click()
        let summary = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "완료 3", "실패·일부 실패 0")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 60))
        let image = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        image.lifetime = .keepAlways
        add(image)
    }
}
