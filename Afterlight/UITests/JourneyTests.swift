import XCTest
final class JourneyTests: XCTestCase {
    func capture(_ name:String,_ app:XCUIApplication) { let a=XCTAttachment(screenshot:app.screenshot()); a.name=name; a.lifetime = .keepAlways; add(a) }
    func testJourneyAndRace() {
        let app=XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["HOME"].waitForExistence(timeout:10)); capture("01-home",app)
        app.buttons["GARAGE"].tap(); XCTAssertTrue(app.staticTexts["SOLSTICE"].waitForExistence(timeout:5)); capture("02-garage",app)
        app.buttons["STORY"].tap(); capture("03-story",app)
        app.buttons["WORLD"].tap(); capture("04-world",app)
        let timeAttack=app.buttons.matching(NSPredicate(format:"label CONTAINS 'Time attack'")).firstMatch
        XCTAssertTrue(timeAttack.waitForExistence(timeout:5)); timeAttack.tap()
        let brief=app.buttons.matching(NSPredicate(format:"label CONTAINS %@", "LET'S RACE")).firstMatch
        if brief.waitForExistence(timeout:3) { brief.tap() }
        XCTAssertTrue(app.buttons["Pause race"].waitForExistence(timeout:5))
        app.buttons["control-NITRO"].press(forDuration:4)
        capture("05-racing",app)
        app.buttons["Pause race"].tap(); XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label CONTAINS 'RESUME'")).firstMatch.waitForExistence(timeout:5)); capture("06-pause",app)
        app.buttons.matching(NSPredicate(format:"label CONTAINS 'RESUME'")).firstMatch.tap()
        let finish=app.buttons.matching(NSPredicate(format:"label CONTAINS 'BACK TO THE FESTIVAL'")).firstMatch
        XCTAssertTrue(finish.waitForExistence(timeout:60)); capture("07-result",app); finish.tap()
        app.buttons["Settings"].tap(); XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout:5)); capture("08-settings",app)
    }
    func testTabletScreens() {
        let app=XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["HOME"].waitForExistence(timeout:10)); capture("01-home",app)
        app.buttons["GARAGE"].tap(); capture("02-garage",app)
        app.buttons["STORY"].tap(); capture("03-story",app)
        app.buttons["WORLD"].tap(); capture("04-world",app)
        app.buttons.matching(NSPredicate(format:"label CONTAINS 'Time attack'")).firstMatch.tap()
        let brief=app.buttons.matching(NSPredicate(format:"label CONTAINS %@", "LET'S RACE")).firstMatch
        if brief.waitForExistence(timeout:3) { brief.tap() }
        XCTAssertTrue(app.buttons["Pause race"].waitForExistence(timeout:5))
        app.buttons["control-NITRO"].press(forDuration:3)
        capture("05-racing",app)
        app.buttons["Pause race"].tap()
        app.buttons["Leave race"].tap()
    }

}
