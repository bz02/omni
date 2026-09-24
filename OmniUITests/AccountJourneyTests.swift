import XCTest
import StoreKitTest

/// A deliberately unavailable loopback service exercises the real account error
/// path. This test never opens Apple's authorization UI or uses account credentials.
@MainActor
final class AccountJourneyTests: XCTestCase {
    private var app: XCUIApplication!
    private var storeKit: SKTestSession!

    override func setUpWithError() throws {
        continueAfterFailure = false
        let bundle = Bundle(for: AccountJourneyTests.self)
        let fixture = bundle.url(forResource: "Omni", withExtension: "storekit", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "Omni", withExtension: "storekit")
        storeKit = try SKTestSession(contentsOf: XCTUnwrap(fixture))
        storeKit.resetToDefaultState(); storeKit.clearTransactions()
        storeKit.disableDialogs = true
        storeKit.timeRate = .realTime
        storeKit.storefront = "USA"
        storeKit.locale = Locale(identifier: "en_US")
        app = XCUIApplication()
        app.launchEnvironment["OMNI_TEST_STORAGE"] = UUID().uuidString
        app.launchEnvironment["OMNI_MEMORY_API_URL"] = "http://127.0.0.1:18098"
        app.launchEnvironment["OMNI_MEMORY_SESSION_TOKEN"] = ""
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        storeKit?.clearTransactions(); storeKit?.resetToDefaultState()
    }

    func testUnavailableAccountServiceAllowsGuestPurchaseAndRestore() {
        let start = app.buttons["welcome.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10)); reveal(start); start.tap()
        let finish = app.buttons["welcome.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5)); reveal(finish); finish.tap()
        selectTab("You")

        let signIn = app.buttons["Sign in with Apple"]
        reveal(signIn)
        // The padded row, including its center Spacer, must respond to a tap.
        // Verify navigation before waiting for the account network result.
        signIn.tap()
        XCTAssertTrue(app.buttons["account.done"].waitForExistence(timeout: 5), "The account screen must open before checking its connection state.")
        let error = app.staticTexts["account.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 15), "The refused loopback connection should show a recoverable account error.")
        XCTAssertFalse(app.buttons["account.appleSignIn"].exists, "Apple authorization must wait for a server nonce.")
        let prepare = app.buttons["account.prepare"]
        reveal(prepare)
        XCTAssertTrue(prepare.isEnabled)
        prepare.tap()
        let retryFinished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: prepare)
        XCTAssertEqual(XCTWaiter.wait(for: [retryFinished], timeout: 15), .completed)
        XCTAssertTrue(error.exists)
        XCTAssertFalse(app.buttons["account.appleSignIn"].exists)
        app.buttons["account.done"].tap()

        // Local authored reflection remains usable when account services fail.
        selectTab("Today")
        let checkIn = app.buttons["today.checkin"]
        reveal(checkIn); checkIn.tap()
        XCTAssertTrue(app.buttons["Hopeful"].waitForExistence(timeout: 5)); app.buttons["Hopeful"].tap()
        let intention = app.descendants(matching: .any).matching(identifier: "field.One small thing I can do for myself").firstMatch
        enter("A quiet walk without my phone", in: intention)
        if app.keyboards.firstMatch.exists { app.buttons["keyboard.done"].firstMatch.tap() }
        reveal(app.buttons["checkin.save"]); app.buttons["checkin.save"].tap()
        selectTab("Journal")
        XCTAssertTrue(app.staticTexts["A quiet walk without my phone"].waitForExistence(timeout: 5))

        // A failed optional account service must never gate StoreKit purchases.
        selectTab("You")
        let plus = app.buttons.containing(.staticText, identifier: "Explore Omni Plus").firstMatch
        for _ in 0..<7 {
            if plus.isHittable { break }
            app.scrollViews.firstMatch.swipeDown()
        }
        reveal(plus); plus.tap()
        let subscribe = app.buttons["plus.subscribe"]
        XCTAssertTrue(subscribe.waitForExistence(timeout: 10)); reveal(subscribe); subscribe.tap()
        let active = app.staticTexts["Your Plus subscription is active"]
        XCTAssertTrue(active.waitForExistence(timeout: 10))
        XCTAssertEqual(storeKit.allTransactions().count, 1)
        XCTAssertFalse(app.buttons["account.appleSignIn"].exists)
        let purchaseScreenshot = XCTAttachment(screenshot: app.screenshot())
        purchaseScreenshot.name = "Guest-Plus-purchased-without-registration"
        purchaseScreenshot.lifetime = .keepAlways; add(purchaseScreenshot)
        let restore = app.buttons["plus.restore"]
        reveal(restore); restore.tap()
        XCTAssertTrue(active.waitForExistence(timeout: 10))
        XCTAssertEqual(storeKit.allTransactions().count, 1, "Restore must not charge again.")
        app.buttons["Close"].tap()
        app.terminate(); app.launch()
        selectTab("Journal")
        XCTAssertTrue(app.staticTexts["A quiet walk without my phone"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "10-Guest-journal-after-account-failure"; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    private func enter(_ text: String, in field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        reveal(field)
        var inputIsReady = false
        // The first keyboard presentation can lag on a fresh simulator. The Done
        // control is rendered only when this check-in field's FocusState is true.
        for _ in 0..<2 {
            field.tap()
            if app.keyboards.firstMatch.waitForExistence(timeout: 5),
               app.buttons["keyboard.done"].firstMatch.waitForExistence(timeout: 5) {
                inputIsReady = true
                break
            }
        }
        XCTAssertTrue(inputIsReady, "The check-in field must show its keyboard and focused Done control before typing.")
        guard inputIsReady else { return }
        field.typeText(text)
        let entered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", text), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [entered], timeout: 5), .completed, "The authored intention must appear in the field before saving.")
    }

    private func selectTab(_ title: String) {
        // iPadOS 18 places tabs in a top control outside the tabBars container.
        let tab = app.buttons[title].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        let destination: XCUIElement
        switch title {
        case "You": destination = app.staticTexts["You get to keep becoming."]
        case "Today": destination = app.buttons["today.checkin"]
        case "Journal": destination = app.staticTexts["A RECORD OF BECOMING"]
        default: XCTFail("Unexpected tab in this journey"); return
        }
        tab.tap()
        XCTAssertTrue(destination.waitForExistence(timeout: 10), "The \(title) destination must appear after selecting its tab.")
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<9 {
            if element.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
}
