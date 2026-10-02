import XCTest
final class JourneyTests: XCTestCase {
    func capture(_ name:String,_ app:XCUIApplication) { let a=XCTAttachment(screenshot:XCUIScreen.main.screenshot()); a.name=name; a.lifetime = .keepAlways; add(a) }
    func testJourneyAndRace() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app=XCUIApplication(); app.launchArguments=["--journey-review"]; app.launch()
        XCTAssertTrue(app.buttons["HOME"].waitForExistence(timeout:10)); XCTAssertTrue(app.descendants(matching:.any)["showroom-ready-SOLSTICE"].waitForExistence(timeout:10)); capture("01-home",app)
        app.buttons["GARAGE"].tap(); XCTAssertTrue(app.descendants(matching:.any)["showroom-ready-SOLSTICE"].waitForExistence(timeout:10)); XCTAssertTrue(app.staticTexts["SOLSTICE"].waitForExistence(timeout:5)); capture("02-garage",app)
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
        XCTAssertTrue(finish.waitForExistence(timeout:60)); capture("07-result",app); XCTAssertTrue(finish.isHittable,"Finish navigation must be visible without scrolling"); app.buttons.matching(NSPredicate(format:"label CONTAINS 'CHOOSE NEXT EVENT'")).firstMatch.tap()
        XCTAssertTrue(app.scrollViews["race-calendar"].waitForExistence(timeout:5))
        app.buttons.matching(NSPredicate(format:"label CONTAINS 'Drift run'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Pause race"].waitForExistence(timeout:5),"A second event must start after the first result")
        XCTAssertFalse(brief.exists,"The introductory briefing must appear only before the first race")
        app.buttons["Pause race"].tap(); app.buttons["Leave race"].tap()
        app.buttons["Settings"].tap(); XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout:5)); capture("08-settings",app)
    }
    func testTabletScreens() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app=XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["HOME"].waitForExistence(timeout:10)); XCTAssertTrue(app.descendants(matching:.any)["showroom-ready-SOLSTICE"].waitForExistence(timeout:10)); capture("01-home",app)
        app.buttons["GARAGE"].tap(); XCTAssertTrue(app.descendants(matching:.any)["showroom-ready-SOLSTICE"].waitForExistence(timeout:10)); capture("02-garage",app)
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

    func testLicensedRivalGridPerformance() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app=XCUIApplication();app.launchArguments=["--visual-review","--preview-region","0","--preview-grid"];app.launch()
        XCTAssertTrue(app.buttons["Pause race"].waitForExistence(timeout:15))
        capture("rival-grid-start",app)
        app.buttons["control-NITRO"].press(forDuration:8)
        let sample=app.descendants(matching:.any)["race-scene"].value as? String ?? "No frame sample"
        let note=XCTAttachment(string:sample);note.name="Complete licensed rival grid frame rate";note.lifetime = .keepAlways;add(note)
        XCTAssertGreaterThanOrEqual(Double(sample.split(separator:" ").first ?? "0") ?? 0,30)
        capture("rival-grid-racing",app)
        app.buttons["Pause race"].tap();app.buttons["Leave race"].tap()
    }

    func testVisualFleetAndRegions() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app=XCUIApplication();app.launchArguments=["--visual-review"];app.launch()
        XCTAssertTrue(app.buttons["GARAGE"].waitForExistence(timeout:10));app.buttons["GARAGE"].tap()
        for name in ["SOLSTICE","KOMET","VANTA","AURORA","SPECTRE","AFTERLIGHT"] {
            let swatch=app.buttons[name];if !swatch.isHittable {app.swipeUp()};swatch.tap()
            XCTAssertTrue(app.descendants(matching:.any)["showroom-ready-"+name].waitForExistence(timeout:10))
            app.swipeDown();capture("fleet-"+name,app)
        }
        app.buttons["WORLD"].tap()
        for region in 0..<4 {
            let events=app.buttons.matching(NSPredicate(format:"label CONTAINS 'Time attack'"))
            let event=events.element(boundBy:region)
            for _ in 0..<10 {if event.isHittable {break};app.scrollViews["race-calendar"].swipeLeft()}
            XCTAssertTrue(event.isHittable,"Region event must be reachable")
            event.tap()
            let brief=app.buttons.matching(NSPredicate(format:"label CONTAINS %@","LET'S RACE")).firstMatch
            if brief.waitForExistence(timeout:1) {brief.tap()}
            XCTAssertTrue(app.buttons["Pause race"].waitForExistence(timeout:10))
            app.buttons["control-NITRO"].press(forDuration:6)
            let scene=app.descendants(matching:.any)["race-scene"]
            let sample=scene.value as? String ?? "No frame sample"
            let note=XCTAttachment(string:"Region \(region): \(sample)");note.name="Render timing region \(region)";note.lifetime = .keepAlways;add(note)
            XCTAssertGreaterThanOrEqual(Double(sample.split(separator:" ").first ?? "0") ?? 0,30,"Circuit should render at least 30 fps in review")
            capture("scene-region-\(region)",app)
            app.buttons["Pause race"].tap();app.buttons["Leave race"].tap()
        }
    }

}
