//
//  BeaconUITests.swift
//  BeaconUITests
//
//  Created by Denys Yazan on 22.08.2026.
//

import XCTest

final class BeaconUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSettingsCanBeSearchedAndUnfavorited() throws {
        let app = application(favoriteIDs: ["command:settings"])
        app.launch()

        let settingsResult = app.buttons["openBeaconSettingsResult"]
        XCTAssertTrue(settingsResult.waitForExistence(timeout: 2))

        let searchField = app.textFields["launcherSearchField"]
        searchField.click()
        searchField.typeText("settings")
        XCTAssertTrue(settingsResult.waitForExistence(timeout: 2))

        searchField.typeKey("k", modifierFlags: .command)
        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeKey(.delete, modifierFlags: [])

        XCTAssertTrue(app.staticTexts["No favorites yet"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testSearchKeepsFirstResultSelectedUnderStationaryPointer() throws {
        let app = application(favoriteIDs: ["command:settings", "command:applications"])
        app.launch()

        let searchField = app.textFields["launcherSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.click()

        let applicationsResult = app.buttons.matching(identifier: "launcherResult").firstMatch
        XCTAssertTrue(applicationsResult.waitForExistence(timeout: 2))
        applicationsResult
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .hover()
        XCTAssertTrue(applicationsResult.isSelected)

        searchField.typeText("settings")

        let settingsResult = app.buttons["openBeaconSettingsResult"]
        XCTAssertTrue(settingsResult.waitForExistence(timeout: 2))
        XCTAssertTrue(settingsResult.isSelected)
    }

    @MainActor
    func testDownArrowSelectsAndOpensFooterSettings() throws {
        let app = application(favoriteIDs: ["command:settings"])
        app.launch()

        let searchField = app.textFields["launcherSearchField"]
        let settingsButton = app.buttons["openSettingsButton"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))

        searchField.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(settingsButton.isSelected)
        searchField.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(app.otherElements["settingsView"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testOptionDownArrowReordersSelectedFavorite() throws {
        let app = application(favoriteIDs: ["command:settings", "command:applications"])
        app.launch()

        let searchField = app.textFields["launcherSearchField"]
        let settingsResult = app.buttons["openBeaconSettingsResult"]
        let applicationsResult = app.buttons.matching(identifier: "launcherResult").firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        XCTAssertTrue(settingsResult.waitForExistence(timeout: 2))
        XCTAssertTrue(applicationsResult.waitForExistence(timeout: 2))
        XCTAssertTrue(settingsResult.isSelected)

        searchField.typeKey(.downArrow, modifierFlags: .option)

        XCTAssertTrue(settingsResult.isSelected)
        XCTAssertLessThan(applicationsResult.frame.minY, settingsResult.frame.minY)
    }

    private func application(favoriteIDs: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["BEACON_UI_TESTING"] = "1"
        app.launchEnvironment["BEACON_UI_TEST_FAVORITE_IDS"] = favoriteIDs.joined(separator: "\n")
        return app
    }
}
