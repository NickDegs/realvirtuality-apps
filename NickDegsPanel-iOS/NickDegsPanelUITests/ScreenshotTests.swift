import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testAppScreenshots() throws {
        // Panel: login gerekiyor, login ekranı da çok güzel
        sleep(4)

        // 1. Giriş ekranı (logo + form)
        attach("01_login")

        // 2. Telefon alanına odaklan
        let telField = app.textFields.firstMatch
        if telField.exists { telField.tap(); sleep(1) }
        attach("02_login_form")

        // 3. Gelişmiş mod butonu varsa tık
        let advanced = app.buttons.matching(NSPredicate(format: "label CONTAINS 'gelişmiş' OR label CONTAINS 'Gelişmiş'")).firstMatch
        if advanced.exists { advanced.tap(); sleep(2); attach("03_advanced_login") }

        // 4. Loading state varsa bekle
        sleep(3)
        attach("04_state")

        // 5. Hub / Hata durumu (backend ulaşılamazsa error ekranı da göster)
        sleep(5)
        attach("05_hub_or_error")
    }

    private func attach(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
