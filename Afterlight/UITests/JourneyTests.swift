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
        let finish=app.buttons.matching(NSPredicate(format:"label CONTAINS 'FESTIVAL'")).firstMatch
        XCTAssertTrue(finish.waitForExistence(timeout:60)); capture("07-result",app); XCTAssertTrue(finish.isHittable,"Finish navigation must be visible without scrolling"); app.buttons.matching(NSPredicate(format:"label CONTAINS 'NEXT EVENT'")).firstMatch.tap()
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

    func testSteeringButtonsMatchBothLandscapeOrientations() {
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation=orientation
            for (button,direction) in [("LEFT",-1.0),("RIGHT",1.0)] {
                let app=XCUIApplication()
                app.launchArguments=["--journey-review","--preview-region","0","--controls-review"]
                app.launch()
                let control=app.buttons["control-"+button]
                XCTAssertTrue(control.waitForExistence(timeout:15))
                control.press(forDuration:4.2)
                let scene=app.descendants(matching:.any)["race-scene"]
                let raw=scene.value as? String ?? "missing"
                guard let offset=Double(raw) else {XCTFail("Missing camera-space telemetry: \(raw)");app.terminate();continue}
                XCTAssertGreaterThan(offset*direction,1,"\(button) must steer in its labeled screen direction in \(orientation)")
                capture("steering-\(orientation.rawValue)-\(button)",app)
                app.terminate()
            }
        }
    }

    func testAllTwentyCalendarRoutesAreReachable() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app=XCUIApplication();app.launchArguments=["--visual-review","--preview-calendar"];app.launch()
        XCTAssertTrue(app.scrollViews["race-calendar"].waitForExistence(timeout:10))
        for region in 0..<4 {
            app.buttons["district-\(region)"].tap()
            let ids=[region]+Array((4+region*4)..<(8+region*4))
            for id in ids {
                let event=app.buttons["event-\(id)-1"]
                for _ in 0..<6 {if event.isHittable {break};app.scrollViews["race-calendar"].swipeLeft()}
                XCTAssertTrue(event.isHittable,"Route \(id) must be reachable")
                XCTAssertTrue(event.isEnabled)
            }
            capture("world-tour-district-\(region)",app)
        }
        app.buttons["event-19-1"].tap()
        let brief=app.buttons.matching(NSPredicate(format:"label CONTAINS %@","LET'S RACE")).firstMatch
        if brief.waitForExistence(timeout:3) {brief.tap()}
        XCTAssertTrue(app.buttons["Pause race"].waitForExistence(timeout:10))
        app.buttons["control-NITRO"].press(forDuration:5)
        capture("last-light-new-route",app)
        app.buttons["Pause race"].tap();app.buttons["Leave race"].tap()
    }

    func testRouteSceneryReview() {
        XCUIDevice.shared.orientation = .landscapeLeft
        for id in 0..<20 {
            let app=XCUIApplication();app.launchArguments=["--visual-review","--preview-region",String(id)];app.launch()
            XCTAssertTrue(app.buttons["Pause race"].waitForExistence(timeout:15))
            app.buttons["control-NITRO"].press(forDuration:4)
            capture("route-art-\(id)",app)
            let sample=app.descendants(matching:.any)["race-scene"].value as? String ?? "0"
            print("AFTERLIGHT-FPS route \(id): \(sample)")
            XCTAssertGreaterThanOrEqual(Double(sample.split(separator:" ").first ?? "0") ?? 0,30,"Route \(id) render timing")
            app.terminate()
        }
    }

    func testNitroHoldKeepsSimulationAdvancing() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app=XCUIApplication();app.launchArguments=["--journey-review","--preview-region","18","--preview-grid","--nitro-review"];app.launch()
        XCTAssertTrue(app.buttons["control-NITRO"].waitForExistence(timeout:15))
        // Cold scene creation can delay the countdown on a physical device.
        // Start measuring only once the race clock is actually advancing.
        let running=NSPredicate { _,_ in
            guard let raw=app.descendants(matching:.any)["race-scene"].value as? String,
                  let value=try? JSONDecoder().decode([String:Double].self,from:Data(raw.utf8)) else{return false}
            return (value["elapsed"] ?? 0)>0.5
        }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:running,object:nil)],timeout:15),.completed)
        func sample() throws -> [String:Double] {
            let value=try XCTUnwrap(app.descendants(matching:.any)["race-scene"].value as? String)
            return try JSONDecoder().decode([String:Double].self,from:Data(value.utf8))
        }
        let before=try sample()
        for duration in [0.5,0.7,3.0] {app.buttons["control-NITRO"].press(forDuration:duration)}
        let after=try sample()
        XCTAssertGreaterThan(try XCTUnwrap(after["elapsed"])-XCTUnwrap(before["elapsed"]),3.8,"Held nitro must not suspend race time")
        XCTAssertGreaterThan(try XCTUnwrap(after["frames"])-XCTUnwrap(before["frames"]),100)
        XCTAssertGreaterThan(try XCTUnwrap(after["boostSamples"]),90)
        XCTAssertLessThan(try XCTUnwrap(after["maxBoostGap"]),0.25,"Nitro input must not stall the simulation clock")
        let note=XCTAttachment(string:"Before: \(before)\nAfter: \(after)");note.name="Nitro touch timing";note.lifetime = .keepAlways;add(note)
        capture("nitro-with-varied-rivals",app)
        app.buttons["Pause race"].tap();app.buttons["Leave race"].tap()
    }

    func testCanyonArchReview() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app=XCUIApplication();app.launchArguments=["--visual-review","--preview-region","2"];app.launch()
        XCTAssertTrue(app.buttons["Pause race"].waitForExistence(timeout:15))
        capture("canyon-arch-grid",app)
        app.buttons["control-NITRO"].press(forDuration:4)
        capture("canyon-arch-racing",app)
        app.terminate()
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
            let swatch=app.buttons[name];XCTAssertTrue(swatch.isHittable);swatch.tap()
            XCTAssertTrue(app.descendants(matching:.any)["showroom-ready-"+name].waitForExistence(timeout:10))
            capture("fleet-"+name,app)
        }
        app.buttons["WORLD"].tap()
        for region in 0..<4 {
            app.buttons["district-\(region)"].tap()
            let event=app.buttons["event-\(region)-1"]
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
