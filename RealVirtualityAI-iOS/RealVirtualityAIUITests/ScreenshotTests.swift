import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchEnvironment["SS_MODE"] = "1"
        app.launch()
    }

    func testAppScreenshots() throws {
        // 1. Ana ekran — AI araçlar grid
        sleep(4)
        attach("01_ana_ekran")

        // 2. Kategori scroll — içerik araçları
        let scroll = app.scrollViews.firstMatch
        if scroll.exists {
            scroll.swipeUp()
            sleep(1)
        }
        attach("02_kategoriler")

        // 3. İlk araç kartı — detay
        scroll.swipeDown()
        sleep(1)
        let cards = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '🖼' OR label BEGINSWITH '🤳' OR label BEGINSWITH '🎤'"))
        if cards.count > 0 { cards.element(boundBy: 0).tap(); sleep(2) }
        else { app.cells.firstMatch.tap(); sleep(2) }
        attach("03_arac_detay")

        // Geri dön
        let geri = app.navigationBars.buttons.firstMatch
        if geri.exists { geri.tap(); sleep(1) }
        else { app.swipeRight(); sleep(1) }

        // 4. Kredi / IAP ekranı — toolbar'dan aç
        // Toolbar: bolt.fill (kredi) butonu
        let toolbar = app.navigationBars
        let boltButtons = toolbar.buttons.matching(NSPredicate(format: "label CONTAINS '⚡' OR label CONTAINS 'kredi' OR label CONTAINS 'Kredi'"))
        if boltButtons.count > 0 {
            boltButtons.firstMatch.tap(); sleep(2)
            attach("04_kredi_iap")
            // Kapat
            let kapat = app.buttons["xmark.circle.fill"]
            if kapat.exists { kapat.tap() }
            else { app.swipeDown(); sleep(1) }
        } else {
            // Toolbar'daki ikinci butona tap (kredi pill)
            let trailing = app.navigationBars.firstMatch.buttons
            if trailing.count > 1 { trailing.element(boundBy: 0).tap(); sleep(2); attach("04_kredi_iap") }
        }

        sleep(1)

        // 5. Ayarlar / tema seçimi
        let ayarBtn = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS 'RV' OR label CONTAINS 'sparkles'")).firstMatch
        if ayarBtn.exists { ayarBtn.tap(); sleep(2); attach("05_ayarlar") }

        // 6. Arama — araç bul
        if app.exists {
            let searchFields = app.searchFields
            if searchFields.count > 0 { searchFields.firstMatch.tap(); sleep(1) }
            let textFields = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'Ara' OR placeholderValue CONTAINS 'ara'"))
            if textFields.count > 0 { textFields.firstMatch.tap(); sleep(1) }
        }
        attach("06_ana_tam")
    }

    private func attach(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
