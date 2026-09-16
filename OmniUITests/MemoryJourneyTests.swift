import XCTest
import StoreKitTest

/// These journeys use Apple's local StoreKit environment. No Apple Account is
/// charged, and no app entitlement flag or synthetic premium override is used.
/// Run serially: SKTestSession shares its environment with other StoreKit tests.
@MainActor
final class MemoryJourneyTests: XCTestCase {
    private var app: XCUIApplication!
    private var session: SKTestSession!
    private let yearlyID = "omni.ai.Omni.plus.yearly"
    private let editorFieldID = "field.What would you like Omni to remember?"

    override func setUpWithError() throws {
        continueAfterFailure = false
        let bundle = Bundle(for: MemoryJourneyTests.self)
        let resource = bundle.url(forResource: "Omni", withExtension: "storekit", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "Omni", withExtension: "storekit")
        let configuration = try XCTUnwrap(resource, "Copy OmniUITests/Fixtures/Omni.storekit into the UI test bundle.")
        session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.timeRate = .realTime
        session.storefront = "USA"
        session.locale = Locale(identifier: "en_US")
        session.askToBuyEnabled = false
        session.interruptedPurchasesEnabled = false

        app = XCUIApplication()
        app.launchEnvironment["OMNI_TEST_STORAGE"] = UUID().uuidString
        // This journey verifies the deliberately disconnected build. It must
        // never use a developer's live conversation endpoint or account token.
        app.launchEnvironment["OMNI_MEMORY_API_URL"] = ""
        app.launchEnvironment["OMNI_MEMORY_SESSION_TOKEN"] = ""
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        onboard()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        session?.clearTransactions()
        session?.resetToDefaultState()
        app = nil
        session = nil
    }

    func testPlusMemoryPersistsAndRemainsManageableAfterSubscriptionExpires() throws {
        openMemory()
        XCTAssertEqual(app.switches["memory.enabled"].value as? String, "0")
        app.switches["memory.enabled"].tap()
        XCTAssertTrue(app.staticTexts["OMNI PLUS"].waitForExistence(timeout: 5))
        let subscribe = app.buttons["plus.subscribe"]
        XCTAssertTrue(subscribe.waitForExistence(timeout: 10))
        reveal(subscribe)
        subscribe.tap()
        XCTAssertTrue(app.staticTexts["Your Plus subscription is active"].waitForExistence(timeout: 15))
        XCTAssertTrue(session.allTransactions().contains { $0.productIdentifier == yearlyID }, "The app must create a real local StoreKit transaction.")
        app.buttons["Close"].tap()

        scrollToTop(app.switches["memory.enabled"])
        app.switches["memory.enabled"].tap()
        let allow = app.buttons["Turn on memory"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5))
        allow.tap()
        waitForValue("1", of: app.switches["memory.enabled"])

        let rememberProfile = app.buttons["memory.rememberProfile"]
        reveal(rememberProfile)
        rememberProfile.tap()
        let field = editorField()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue((field.value as? String)?.contains("My current focus is") == true)
        replaceEditorText(with: "My name is Taylor.")
        reveal(app.buttons["memory.editor.save"])
        app.buttons["memory.editor.save"].tap()
        XCTAssertTrue(app.staticTexts["My name is Taylor."].waitForExistence(timeout: 5))
        screenshot("08-Memory-saved")

        app.terminate(); app.launch()
        openMemory()
        reveal(app.staticTexts["My name is Taylor."])
        XCTAssertTrue(app.staticTexts["My name is Taylor."].exists)

        // Expiration comes from StoreKit, never from an injected app flag.
        try session.expireSubscription(productIdentifier: yearlyID)
        app.terminate(); app.launch()
        openMemory()
        XCTAssertTrue(app.staticTexts["A Plus subscription lets you add and use memories. Your existing memories remain available to view, edit, delete and export."].waitForExistence(timeout: 10))
        XCTAssertEqual(app.switches["memory.enabled"].value as? String, "0")
        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "memory.options.")).firstMatch
        reveal(options); options.tap()
        app.buttons["Edit memory"].tap()
        replaceEditorText(with: "My name is Taylor. I enjoy quiet dates.")
        reveal(app.buttons["memory.editor.save"])
        app.buttons["memory.editor.save"].tap()
        let revised = app.staticTexts["My name is Taylor. I enjoy quiet dates."]
        XCTAssertTrue(revised.waitForExistence(timeout: 5))
        reveal(app.buttons["memory.export"])
        XCTAssertTrue(app.buttons["memory.export"].isEnabled)

        scrollToTop(app.switches["memory.enabled"])
        let editOptions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "memory.options.")).firstMatch
        reveal(editOptions); editOptions.tap()
        app.buttons["Delete memory"].tap()
        let confirmation = app.buttons["Delete memory"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
        XCTAssertTrue(app.otherElements["memory.empty"].waitForExistence(timeout: 5) || app.staticTexts["Start with what matters."].exists)
        XCTAssertFalse(revised.exists)
    }

    func testFreeMemoryGateAndTemporaryConversationStayHonestWhenOffline() {
        openMemory()
        XCTAssertEqual(app.switches["memory.enabled"].value as? String, "0")
        app.switches["memory.enabled"].tap()
        XCTAssertTrue(app.staticTexts["OMNI PLUS"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertEqual(app.switches["memory.enabled"].value as? String, "0")
        reveal(app.buttons["memory.export"])
        XCTAssertTrue(app.buttons["memory.export"].isEnabled)
        app.buttons["memory.done"].tap()

        selectTab("Talk")
        reveal(app.staticTexts["Conversations aren't connected yet"])
        XCTAssertTrue(app.staticTexts["Conversations aren't connected yet"].exists)
        XCTAssertFalse(app.buttons["talk.send"].isEnabled)
        let temporary = app.switches["talk.temporary"]
        scrollToTop(temporary); temporary.tap()
        waitForValue("1", of: temporary)
        let draft = app.descendants(matching: .any).matching(identifier: "talk.message").firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        draft.tap(); draft.typeText("A private temporary draft")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertFalse(app.buttons["talk.send"].isEnabled)
        scrollToTop(app.buttons["talk.memory"])
        app.buttons["talk.memory"].tap()
        XCTAssertTrue(app.buttons["memory.done"].waitForExistence(timeout: 5))
        app.buttons["memory.done"].tap()
        // A settings sheet is not a deliberate departure from the conversation.
        XCTAssertEqual(temporary.value as? String, "1")
        XCTAssertEqual(draft.value as? String, "A private temporary draft")
        screenshot("09-Talk-unconnected")

        selectTab("You")
        selectTab("Talk")
        waitForValue("0", of: temporary)
        XCTAssertNotEqual(draft.value as? String, "A private temporary draft")
        app.buttons["talk.history"].tap()
        XCTAssertTrue(app.staticTexts["Your saved conversations will appear here."].waitForExistence(timeout: 5))
    }

    private func onboard() {
        let start = app.buttons["welcome.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        reveal(start); start.tap()
        let finish = app.buttons["welcome.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        reveal(finish); finish.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
    }

    private func openMemory() {
        selectTab("You")
        let entry = app.buttons["What Omni remembers"]
        reveal(entry); entry.tap()
        XCTAssertTrue(app.switches["memory.enabled"].waitForExistence(timeout: 5))
        scrollToTop(app.switches["memory.enabled"])
    }

    private func editorField() -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: editorFieldID).firstMatch
    }

    private func replaceEditorText(with value: String) {
        let field = editorField()
        reveal(field)
        let previous = field.value as? String ?? ""
        // These synthetic strings occupy one line. Tapping the lower blank
        // portion of this multiline field places the caret after the content.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.85)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        field.typeText(value)
        XCTAssertEqual(field.value as? String, value)
        if app.keyboards.firstMatch.exists {
            let done = app.buttons["keyboard.done"].firstMatch
            XCTAssertTrue(done.waitForExistence(timeout: 3)); done.tap()
        }
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<9 {
            if element.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func scrollToTop(_ element: XCUIElement) {
        for _ in 0..<9 {
            if element.isHittable { break }
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func selectTab(_ title: String) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        for _ in 0..<3 {
            if tab.isSelected { return }
            tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: tab)
            if XCTWaiter.wait(for: [selected], timeout: 3) == .completed { return }
        }
        XCTFail("The \(title) tab did not become selected.\n" + app.debugDescription)
    }

    private func waitForValue(_ expected: String, of element: XCUIElement) {
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed, "The control did not update to \(expected).\n" + app.debugDescription)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
