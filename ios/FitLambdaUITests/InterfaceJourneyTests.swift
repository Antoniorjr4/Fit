import XCTest

/// User journeys against the running app. Health and connection values are demo data.
final class InterfaceJourneyTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-fit-ui-language", "pt-BR"]
    }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            print("FIT_UI_FAILURE_HIERARCHY\n\(app.debugDescription)")
            capture("failure")
        }
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
        tap("goal.open")
        expectSheet("goal")
        capture("light-goal")
        closeSheet()
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
        app.launchArguments.append("-fit-ui-large-text")
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

    func testFirstLaunchLanguagePersistsAndCancelKeepsChoice() {
        app.launchArguments = ["-fit-ui-reset-language"]
        app.launch()
        XCTAssertTrue(element("language.title").waitForExistence(timeout: 10))
        XCTAssertFalse(element("today.greeting").exists)
        tap("language.en")
        XCTAssertEqual(element("language.title").label, "Your rhythm. Your language.")
        capture("language-first-launch")
        tap("language.save")
        XCTAssertTrue(element("today.greeting").waitForExistence(timeout: 5))
        XCTAssertTrue(element("today.greeting").label.contains("Good evening"))
        app.terminate()
        app.launchArguments = []
        launch()
        XCTAssertFalse(element("language.title").exists)
        XCTAssertTrue(element("today.greeting").label.contains("Good evening"))
        selectTab(3, title: "profile.title")
        tap("language.open")
        tap("language.es")
        XCTAssertEqual(element("language.title").label, "Tu ritmo. Tu idioma.")
        closeSheet()
        XCTAssertEqual(element("profile.title").label, "Your way.")
    }

    func testPortugueseEnglishSpanishNavigation() {
        verifyLanguages([
            ("pt-BR", ["Hoje", "Evolução", "Pulseira", "Perfil"], "Boa noite", "Seu ritmo.", "Sua Fit.", "Do seu jeito.", "10.000"),
            ("en", ["Today", "Trends", "Band", "Profile"], "Good evening", "Your rhythm.", "Your Fit.", "Your way.", "10,000"),
            ("es", ["Hoy", "Progreso", "Pulsera", "Perfil"], "Buenas noches", "Tu ritmo.", "Tu Fit.", "A tu manera.", nil)
        ])
    }

    func testFrenchGermanItalianNavigation() {
        verifyLanguages([
            ("fr", ["Aujourd’hui", "Évolution", "Bracelet", "Profil"], "Bonsoir", "Votre rythme.", "Votre Fit.", "À votre façon.", nil),
            ("de", ["Heute", "Entwicklung", "Armband", "Profil"], "Guten Abend", "Dein Rhythmus.", "Deine Fit.", "Auf deine Art.", "10.000"),
            ("it", ["Oggi", "Progressi", "Bracciale", "Profilo"], "Buonasera", "Il tuo ritmo.", "La tua Fit.", "A modo tuo.", "10.000")
        ])
    }

    func testEmptyAndPartialData() {
        launch()
        chooseScenario("firstUse")
        XCTAssertTrue(element("empty.today.title").waitForExistence(timeout: 5))
        XCTAssertFalse(element("today.progress").exists)
        capture("empty-today")
        selectTab(1, title: "trends.title")
        XCTAssertTrue(element("empty.trends.title").exists)
        XCTAssertFalse(app.segmentedControls["trends.period"].exists)
        capture("empty-trends")
        selectTab(3, title: "profile.title")
        tap("permissions.open")
        tap("permissions.allow")
        expectClosedSheet()
        selectTab(0, title: "today.greeting")
        XCTAssertFalse(element("today.progress").exists, "Permission alone must not create data")
        XCTAssertTrue(element("empty.today.title").exists)

        chooseScenario("partial")
        XCTAssertTrue(element("today.progress").exists)
        scrollTo(app.buttons["empty.sleep.action"])
        XCTAssertTrue(element("empty.sleep.title").exists)
        XCTAssertFalse(app.buttons["sleep.open"].exists)
        capture("partial-sleep")
        tap("empty.sleep.action")
        expectSheet("sync")
        tap("sync.retry")
        expectClosedSheet()
        XCTAssertTrue(app.buttons["sleep.open"].exists)
        XCTAssertTrue(element("today.progress").exists)
    }

    func testPermissionAndConnectionRecovery() {
        launch()
        chooseScenario("permissionNeeded")
        tap("state.action")
        expectSheet("permissions")
        capture("permission-explanation")
        tap("permissions.deny")
        expectClosedSheet()
        XCTAssertEqual(element("state.title").label, "A conexão precisa da sua permissão.")
        XCTAssertTrue(element("today.progress").exists)
        tap("state.action")
        tap("permissions.allow")
        expectClosedSheet()
        XCTAssertEqual(element("state.title").label, "Sua Fit ainda não apareceu.")
        capture("band-not-found")
        tap("state.action")
        expectSheet("pairing")
        tap("pairing.next"); tap("pairing.next"); tap("pairing.next")
        expectClosedSheet()
        XCTAssertTrue(element("state.recovered").exists)
        XCTAssertFalse(element("state.title").exists)
    }

    func testConnectionFailuresPreserveHistory() {
        launch()
        selectTab("Pulseira", title: "band.title")
        XCTAssertEqual(element("band.status").label, "Nenhuma pulseira conectada")
        for scenario in ["bluetoothOff", "disconnected", "syncFailed"] {
            chooseScenario(scenario)
            XCTAssertTrue(element("state.title").exists)
            XCTAssertTrue(element("today.progress").label.contains("8.432"))
            capture("state-\(scenario)")
            if scenario == "bluetoothOff" {
                tap("state.action")
                expectSheet("permissions")
                closeSheet()
            }
        }
        selectTab("Pulseira", title: "band.title")
        XCTAssertTrue(element("band.status").label.contains("Conexão simulada"))
        XCTAssertEqual(element("band.sync.status").label, "Não foi possível atualizar agora.")
        XCTAssertTrue(element("band.sync.history").exists)
        tap("band.diagnostics.open")
        expectSheet("diagnostics")
        closeSheet()
        tap("band.sync.now")
        XCTAssertEqual(element("band.sync.status").label, "Sincronizando · demo")
        XCTAssertTrue(element("band.sync.history").exists)
        tap("band.sync.finish")
        XCTAssertEqual(element("band.sync.status").label, "Dados de exemplo atualizados")
        selectTab("Hoje", title: "today.greeting")
        XCTAssertTrue(element("state.recovered").exists)
        XCTAssertFalse(element("state.title").exists)
        XCTAssertTrue(element("today.progress").label.contains("8.432"))
    }

    func testGermanLargeTextAndLanguageSettings() {
        app.launchArguments = ["-fit-ui-language", "de", "-fit-ui-large-text"]
        launch()
        capture("german-large-today")
        selectTab(3, title: "profile.title")
        tap("language.open")
        XCTAssertEqual(element("language.title").label, "Dein Rhythmus. Deine Sprache.")
        capture("german-large-language")
        tap("language.it")
        tap("language.save")
        expectClosedSheet()
        XCTAssertEqual(element("profile.title").label, "A modo tuo.")
        selectTab(0, title: "today.greeting")
        XCTAssertTrue(element("today.greeting").label.contains("Buonasera"))
    }

    private func verifyLanguages(_ languages: [(String, [String], String, String, String, String, String?)]) {
        launch()
        for (code, tabs, greeting, trends, band, profile, goal) in languages {
            selectTab(3, title: "profile.title")
            tap("language.open")
            tap("language.\(code)")
            tap("language.save")
            expectClosedSheet()
            XCTAssertEqual(element("profile.title").label, profile)
            for label in tabs { XCTAssertTrue(app.tabBars.buttons[label].exists, "Missing localized tab: \(label)") }
            selectTab(0, title: "today.greeting")
            XCTAssertTrue(element("today.greeting").label.contains(greeting))
            capture("locale-\(code)-today")
            tap("goal.open")
            expectSheet("goal")
            if let goal { XCTAssertEqual(element("goal.value").label, goal) }
            closeSheet()
            selectTab(1, title: "trends.title")
            XCTAssertEqual(element("trends.title").label, trends)
            capture("locale-\(code)-trends")
            selectTab(2, title: "band.title")
            XCTAssertEqual(element("band.title").label, band)
        }
    }

    private func chooseScenario(_ code: String) {
        selectTab(3, title: "profile.title")
        tap("scenarios.open")
        expectSheet("scenarios")
        let target = app.buttons["scenario.\(code)"]
        let scroll = app.scrollViews["sheet.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for _ in 0..<8 {
            if target.exists && target.isHittable && scroll.frame.contains(target.frame) {
                break
            }
            scroll.swipeUp()
        }
        XCTAssertTrue(target.exists && target.isHittable, "Scenario is unreachable: \(code)")
        target.tap()
        expectClosedSheet()
        selectTab(0, title: "today.greeting")
    }

    private func selectTab(_ index: Int, title identifier: String) {
        let button = app.tabBars.buttons.element(boundBy: index)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(element(identifier).waitForExistence(timeout: 5))
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
        // The presented sheet and the retained tab can both expose a scroll view.
        // Always drag the active page instead of relying on accessibility-tree order.
        let languageScroll = app.scrollViews["language.scroll"]
        let sheetScroll = app.scrollViews["sheet.scroll"]
        let scroll = languageScroll.exists ? languageScroll
            : sheetScroll.exists ? sheetScroll : app.scrollViews["page.scroll"]
        for _ in 0..<14 {
            let nav = app.navigationBars.firstMatch
            let tabs = app.tabBars.firstMatch
            let top = nav.exists && nav.isHittable ? nav.frame.maxY + 8 : app.frame.minY + 54
            var bottom = tabs.exists && tabs.isHittable ? tabs.frame.minY - 8 : app.frame.maxY - 28
            let languageSave = app.buttons["language.save"]
            if languageSave.exists && languageSave.isHittable && (!target.exists || target.identifier != "language.save") {
                bottom = min(bottom, languageSave.frame.minY - 8)
            }
            if target.exists && target.isHittable {
                // The language picker pins this action to the safe-area footer.
                // The bounds below apply to content that scrolls behind it.
                if target.identifier == "language.save" ||
                    (target.frame.minY >= top && target.frame.maxY <= bottom) {
                    return
                }
            }
            // SwiftUI may report a partly covered button as hittable. Move its
            // entire frame into the content area before tapping, above the tab bar.
            let moveDown = target.exists && !target.frame.isEmpty && target.frame.minY < top
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: moveDown ? 0.4 : 0.65))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: moveDown ? 0.65 : 0.4))
            start.press(forDuration: 0.05, thenDragTo: end)
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
