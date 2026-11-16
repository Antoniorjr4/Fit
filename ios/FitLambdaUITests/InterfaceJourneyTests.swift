import XCTest

/// User journeys against the running app. Health and connection values are demo data.
final class InterfaceJourneyTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = []
    }

    override func tearDownWithError() throws {
        if testRun?.hasSucceeded == false { capture("failure") }
        app.terminate()
    }

    func testTabsAndPeriods() {
        launch()
        capture("dark-today")
        selectTab("Evolução", title: "trends.title")
        capture("dark-trends-week")
        app.segmentedControls["trends.period"].buttons["Mês"].tap()
        XCTAssertTrue(element("trends.range").label.contains("1 — 15"))
        capture("dark-trends-month")
        app.segmentedControls["trends.period"].buttons["Semana"].tap()
        XCTAssertTrue(element("trends.range").label.contains("9 — 15"))
        selectTab("Pulseira", title: "band.title")
        capture("dark-band")
        selectTab("Perfil", title: "profile.title")
        capture("dark-profile")
        selectTab("Hoje", title: "today.greeting")
        XCTAssertTrue(element("today.greeting").label.contains("Antonio"))
    }

    func testGoalSaveAndCancel() {
        launch()
        tap("goal.open")
        expectSheet("goal")
        tap("goal.increase")
        XCTAssertEqual(element("goal.value").label, "11.000")
        capture("goal-edit")
        tap("goal.save")
        expectClosedSheet()
        assertGoal(11000)

        tap("goal.open")
        tap("goal.increase")
        XCTAssertEqual(element("goal.value").label, "12.000")
        closeSheet()
        assertGoal(11000)
        selectTab("Perfil", title: "profile.title")
        XCTAssertTrue(element("profile.goal").label.contains("11.000"))
    }

    func testNameEditingAndEmptyValidation() {
        launch()
        selectTab("Perfil", title: "profile.title")
        tap("name.open")
        expectSheet("name")
        let field = app.textFields["name.field"]
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
        XCTAssertFalse(app.buttons["name.save"].isEnabled)
        field.typeText("Antonio Rufino")
        tap("name.save")
        expectClosedSheet()
        selectTab("Hoje", title: "today.greeting")
        XCTAssertTrue(element("today.greeting").label.contains("Antonio Rufino"))
        capture("today-renamed")

        selectTab("Perfil", title: "profile.title")
        tap("name.open")
        field.tap()
        field.typeText(" teste")
        closeSheet()
        selectTab("Hoje", title: "today.greeting")
        XCTAssertFalse(element("today.greeting").label.contains("teste"))
    }

    func testBandSimulationAndFaceSelection() {
        launch()
        selectTab("Pulseira", title: "band.title")
        tap("pairing.open")
        expectSheet("pairing")
        XCTAssertTrue(element("pairing.step").label.contains("1 DE 3"))
        tap("pairing.next")
        XCTAssertTrue(element("pairing.step").label.contains("2 DE 3"))
        tap("pairing.next")
        XCTAssertTrue(element("pairing.step").label.contains("3 DE 3"))
        capture("pairing-demo-confirmation")
        tap("pairing.next")
        expectClosedSheet()
        XCTAssertTrue(element("band.status").label.contains("Conexão simulada"))

        tap("faces.open")
        expectSheet("faces")
        app.segmentedControls["faces.picker"].buttons["Noturno"].tap()
        capture("face-night-preview")
        tap("faces.save")
        expectClosedSheet()
        XCTAssertEqual(element("band.illustration").value as? String, "Noturno")
        tap("faces.open")
        app.segmentedControls["faces.picker"].buttons["Essencial"].tap()
        closeSheet()
        XCTAssertEqual(element("band.illustration").value as? String, "Noturno")
    }

    func testDetailsAndWelcome() {
        launch()
        for kind in ["heart", "sleep"] {
            tap("\(kind).open")
            expectSheet(kind)
            capture("detail-\(kind)")
            closeSheet()
        }
        selectTab("Pulseira", title: "band.title")
        tap("sync.open")
        expectSheet("sync")
        closeSheet()
        selectTab("Perfil", title: "profile.title")
        for kind in ["health", "privacy", "welcome"] {
            tap("\(kind).open")
            expectSheet(kind)
            if kind == "welcome" {
                capture("welcome")
                tap("welcome.done")
                expectClosedSheet()
            } else {
                closeSheet()
            }
        }
    }

    func testLightAppearanceAcrossTabs() {
        launch()
        selectTab("Perfil", title: "profile.title")
        let toggle = app.switches["profile.dark-mode"]
        scrollTo(toggle)
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        capture("light-profile")
        selectTab("Hoje", title: "today.greeting")
        capture("light-today")
        selectTab("Evolução", title: "trends.title")
        capture("light-trends")
        selectTab("Pulseira", title: "band.title")
        capture("light-band")
        selectTab("Perfil", title: "profile.title")
        scrollTo(toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
    }

    func testLargeTextNavigationAndEditing() {
        app.launchArguments = ["-fit-ui-large-text"]
        launch()
        capture("large-text-today")
        tap("goal.open")
        expectSheet("goal")
        tap("goal.increase")
        tap("goal.save")
        expectClosedSheet()
        assertGoal(11000)
        selectTab("Evolução", title: "trends.title")
        capture("large-text-trends")
        selectTab("Pulseira", title: "band.title")
        capture("large-text-band")
        tap("pairing.open")
        expectSheet("pairing")
        tap("pairing.next")
        tap("pairing.next")
        tap("pairing.next")
        expectClosedSheet()
        XCTAssertTrue(element("band.status").label.contains("Conexão simulada"))
        selectTab("Perfil", title: "profile.title")
        capture("large-text-profile")
        tap("privacy.open")
        expectSheet("privacy")
        closeSheet()
    }

    private func launch() {
        app.launch()
        XCTAssertTrue(element("today.greeting").waitForExistence(timeout: 10))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func selectTab(_ title: String, title identifier: String) {
        let button = app.tabBars.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(element(identifier).waitForExistence(timeout: 5))
    }

    private func tap(_ identifier: String) {
        let target = app.buttons[identifier]
        scrollTo(target)
        target.tap()
    }

    private func scrollTo(_ target: XCUIElement) {
        for _ in 0..<8 {
            if target.exists && target.isHittable { return }
            app.scrollViews.firstMatch.swipeUp()
        }
        for _ in 0..<8 {
            if target.exists && target.isHittable { return }
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTFail("Control is unreachable: \(target)")
    }

    private func expectSheet(_ kind: String) {
        XCTAssertTrue(element("sheet.\(kind).title").waitForExistence(timeout: 5))
    }

    private func closeSheet() {
        app.buttons["sheet.close"].tap()
        expectClosedSheet()
    }

    private func expectClosedSheet() {
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.buttons["sheet.close"])
        waitForExpectations(timeout: 5)
    }

    private func assertGoal(_ value: Int) {
        let progress = element("today.progress")
        XCTAssertTrue(progress.exists)
        XCTAssertTrue(progress.label.filter(\.isNumber).hasSuffix(String(value)))
    }

    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
