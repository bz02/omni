import XCTest

@MainActor
final class ClarityJourneyTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["OMNI_TEST_STORAGE"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    func testWelcomeAndDailyReflectionPersistAcrossRelaunch() {
        screenshot("01-Welcome")
        onboard()
        screenshot("02-Today")
        let checkIn = app.buttons["today.checkin"]
        reveal(checkIn)
        checkIn.tap()
        XCTAssertTrue(app.buttons["Tender"].waitForExistence(timeout: 5))
        app.buttons["Hopeful"].tap()
        let intention = app.descendants(matching: .any).matching(identifier: "field.One small thing I can do for myself").firstMatch
        XCTAssertTrue(intention.waitForExistence(timeout: 5))
        intention.tap(); intention.typeText("Take a quiet walk before dinner")
        dismissKeyboard()
        reveal(app.buttons["checkin.save"])
        app.buttons["checkin.save"].tap()
        XCTAssertTrue(app.staticTexts["Take a quiet walk before dinner"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Journal"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Journal"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Take a quiet walk before dinner"].waitForExistence(timeout: 5))
        app.staticTexts["Take a quiet walk before dinner"].tap()
        app.buttons["Add a reflection"].tap()
        XCTAssertTrue(app.buttons["Grounded"].waitForExistence(timeout: 5))
        app.buttons["Grounded"].tap()
        reveal(app.buttons["reflection.save"])
        app.buttons["reflection.save"].tap()
        XCTAssertTrue(app.staticTexts["Later, I felt grounded"].waitForExistence(timeout: 5))
        screenshot("03-Reflection")
    }

    func testConnectionFlowSavedWithoutSendingMessages() {
        onboard()
        app.buttons["Connect"].firstMatch.tap()
        screenshot("04-Connect")
        reveal(app.buttons["connect.uncertainty"])
        app.buttons["connect.uncertainty"].tap()
        fill("What do you know for sure?", "They have not replied since lunch")
        fill("What story is your mind adding?", "I worry I said something wrong")
        fill("What is one thing within your control?", "Put my phone away and see a friend")
        reveal(app.buttons["connection.save"])
        app.buttons["connection.save"].tap()
        XCTAssertTrue(app.staticTexts["SAVED TO YOUR JOURNAL"].waitForExistence(timeout: 5))
        screenshot("05-Clarity")
        reveal(app.buttons["connection.done"])
        app.buttons["connection.done"].tap()
        app.buttons["Journal"].firstMatch.tap()
        app.buttons["Connections"].tap()
        XCTAssertTrue(app.staticTexts["They have not replied since lunch"].waitForExistence(timeout: 5))
        app.buttons["Connect"].firstMatch.tap()
        reveal(app.buttons["connect.uncertainty"])
        app.buttons["connect.uncertainty"].tap()
        XCTAssertTrue(app.staticTexts["OMNI PLUS"].waitForExistence(timeout: 5))
        screenshot("06-Plus")
        XCTAssertTrue(app.buttons["Close"].exists)
    }

    func testConnectInvitationEntryPreservesOriginalReflection() {
        onboard()
        app.buttons["Connect"].firstMatch.tap()
        let entry = app.buttons["connect.compatibility"]
        reveal(entry); entry.tap()
        let signIn = app.buttons["connect.signIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        screenshot("12-Connect-Invite")
        signIn.tap()
        XCTAssertTrue(app.buttons["account.done"].waitForExistence(timeout: 5))
        app.buttons["account.done"].tap()
        app.buttons["Done"].firstMatch.tap()
        reveal(app.buttons["connect.uncertainty"])
        XCTAssertTrue(app.buttons["connect.uncertainty"].exists)
    }

    func testSettingsOfferPrivacyAndKeepChartsHiddenWithoutEndpoint() {
        onboard()
        app.buttons["You"].firstMatch.tap()
        screenshot("07-You")
        XCTAssertTrue(app.buttons["Export my journal"].exists)
        XCTAssertFalse(app.buttons["Explore my birth chart"].exists)
        app.buttons["Privacy & your data"].tap()
        XCTAssertTrue(app.staticTexts["Your journal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Reflection guidance"].exists)
    }

    func testCosmosSharesOutfitAndReturnsToExistingApp() {
        onboard()
        let cosmos = app.buttons["today.cosmos"]
        XCTAssertTrue(cosmos.waitForExistence(timeout: 5))
        cosmos.tap()
        XCTAssertTrue(app.buttons["cosmos.horoscope"].waitForExistence(timeout: 5))
        let poster = app.buttons["cosmos.poster"]
        reveal(poster); poster.tap()
        let share = app.buttons["Share image"]
        reveal(share)
        screenshot("08-Cosmos-Outfit")
        app.navigationBars.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Today"].firstMatch.waitForExistence(timeout: 5))
        let checkIn = app.buttons["today.checkin"]
        reveal(checkIn); checkIn.tap()
        XCTAssertTrue(app.buttons["Hopeful"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        for tab in ["Connect", "Talk", "Journal", "You"] {
            XCTAssertTrue(app.buttons[tab].firstMatch.exists)
        }
    }

    func testReadyCosmosAndAstrologyChatPreserveGuestNavigation() {
        onboard()
        app.buttons["Connect"].firstMatch.tap()
        #if DEBUG
        let dating = app.buttons["connect.dating"]
        reveal(dating); dating.tap()
        XCTAssertTrue(app.buttons["dating.signIn"].waitForExistence(timeout: 5))
        screenshot("12-Discovery-Guest")
        app.navigationBars.buttons["Done"].tap()
        #else
        XCTAssertFalse(app.buttons["connect.dating"].exists)
        #endif
        app.buttons["Today"].firstMatch.tap()
        app.buttons["today.cosmos"].tap()
        let profile = app.buttons["cosmos.profile"]
        reveal(profile); profile.tap()
        XCTAssertTrue(app.buttons["Manage memory & privacy"].waitForExistence(timeout: 5))
        app.buttons["cosmicProfile.done"].tap()
        XCTAssertFalse(app.buttons["cosmos.imageStudio"].exists)
        app.buttons["cosmos.done"].tap()
        app.buttons["Talk"].firstMatch.tap()
        let horoscope = app.buttons["talk.starter.horoscope"]
        reveal(horoscope); horoscope.tap()
        let field = app.descendants(matching: .any).matching(identifier: "talk.message").firstMatch
        XCTAssertTrue((field.value as? String)?.contains("personal horoscope") == true)
        app.buttons["talk.keyboardDone"].tap()
        screenshot("11-Astrology-Chat-Starter")
        app.buttons["Today"].firstMatch.tap()
        let checkIn = app.buttons["today.checkin"]
        reveal(checkIn); checkIn.tap()
        XCTAssertTrue(app.buttons["Hopeful"].waitForExistence(timeout: 5))
    }

    private func onboard() {
        let start = app.buttons["welcome.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        reveal(start); start.tap()
        let finish = app.buttons["welcome.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        reveal(finish); finish.tap()
        XCTAssertTrue(app.buttons["Today"].firstMatch.waitForExistence(timeout: 5))
    }

    private func fill(_ prompt: String, _ value: String) {
        let field = app.descendants(matching: .any).matching(identifier: "field." + prompt).firstMatch
        reveal(field); field.tap(); field.typeText(value); dismissKeyboard()
    }

    private func dismissKeyboard() {
        if app.keyboards.firstMatch.exists {
            let done = app.buttons["keyboard.done"].firstMatch
            XCTAssertTrue(done.waitForExistence(timeout: 3))
            done.tap()
        }
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
