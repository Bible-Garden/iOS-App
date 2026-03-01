import XCTest

// MARK: - AboutTests (requires live API for dynamic content)

final class AboutTests: XCTestCase {

    private var app: XCUIApplication!
    private static var apiChecked = false
    private static var apiAvailable = true

    override func setUpWithError() throws {
        continueAfterFailure = false

        if !Self.apiChecked {
            Self.apiChecked = true
            Self.apiAvailable = checkAPIAvailability()
        }

        try XCTSkipUnless(Self.apiAvailable, "API unavailable — skipping about tests")

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.navigateViaMenu(to: "menu-contacts")

        let aboutPage = app.otherElements["page-about"]
        XCTAssertTrue(app.waitForElement(aboutPage, timeout: 5), "About page did not appear")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    // #1 — Открываем страницу «О проекте» через меню.
    // Результат: страница `page-about` отображается.
    @MainActor
    func testAboutPageOpens() {
        let aboutPage = app.otherElements["page-about"]
        XCTAssertTrue(aboutPage.exists, "About page background should exist")
    }

    // #2 — Ждём загрузки контактов из API.
    // Результат: кнопки `contacts-telegram` и `contacts-website` видны.
    @MainActor
    func testContactButtonsExist() {
        let telegram = app.buttons["contacts-telegram"]
        let website = app.buttons["contacts-website"]

        XCTAssertTrue(app.waitForElement(telegram, timeout: 10), "Telegram contact button should exist")
        XCTAssertTrue(app.waitForElement(website, timeout: 10), "Website contact button should exist")
    }

    // #3 — Проверяем наличие текста «О приложении».
    // Результат: на странице есть текст, содержащий «Bible Garden».
    @MainActor
    func testAboutTextExists() {
        let predicate = NSPredicate(format: "label CONTAINS 'Bible Garden'")
        let aboutText = app.staticTexts.matching(predicate).firstMatch
        XCTAssertTrue(app.waitForElement(aboutText, timeout: 10), "About text containing 'Bible Garden' should be visible")
    }

    // #4 — Тап по кнопке Telegram открывает внешнюю ссылку.
    // Результат: приложение уходит в background (URL открылся в браузере/Telegram).
    @MainActor
    func testTelegramButtonOpensLink() {
        let telegram = app.buttons["contacts-telegram"]
        XCTAssertTrue(app.waitForElement(telegram, timeout: 10), "Telegram button should exist")

        telegram.tap()

        let wentToBackground = app.wait(for: .runningBackground, timeout: 5)
            || app.wait(for: .notRunning, timeout: 2)
        XCTAssertTrue(wentToBackground, "App should go to background after opening Telegram link")

        app.activate()
    }
}
