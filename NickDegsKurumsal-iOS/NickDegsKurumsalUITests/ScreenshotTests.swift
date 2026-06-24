import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testAppScreenshots() throws {
        sleep(4)

        // 1. İlk sekme: İşletme kataloğu
        attach("01_isletme_katalog")

        // 2. Katalog scroll — daha fazla ürün
        app.scrollViews.firstMatch.swipeUp()
        sleep(1)
        attach("02_katalog_scroll")

        // 3. Ürün detayı — ilk karta tık
        app.scrollViews.firstMatch.swipeDown()
        sleep(1)
        let hucre = app.otherElements.matching(NSPredicate(format: "label CONTAINS '🍽' OR label CONTAINS '🌐' OR label CONTAINS '✂'"))
        if hucre.count > 0 { hucre.firstMatch.tap(); sleep(2) }
        attach("03_urun_detay")
        // Geri
        let back = app.navigationBars.buttons.firstMatch
        if back.exists { back.tap(); sleep(1) }

        // 4. Bireysel sekme (index 1)
        let tabs = app.tabBars.buttons
        if tabs.count > 1 { tabs.element(boundBy: 1).tap(); sleep(2) }
        attach("04_bireysel")

        // 5. Dijital sekme (index 2)
        if tabs.count > 2 { tabs.element(boundBy: 2).tap(); sleep(2) }
        attach("05_dijital")

        // 6. Hesabım / Abonelik (son sekme)
        if tabs.count > 0 { tabs.element(boundBy: tabs.count - 1).tap(); sleep(2) }
        attach("06_hesabim_abonelik")
    }

    private func attach(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
