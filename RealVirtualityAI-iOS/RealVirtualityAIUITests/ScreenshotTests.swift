import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchEnvironment["SS_MODE"] = "1"
        app.launch()
    }

    func testAppScreenshots() throws {
        sleep(4)
        // Alt sekmeler: 0=Görsel 1=Yazı 2=Stüdyo 3=Kütüphane 4=Ürünler
        let tabs = app.tabBars.buttons

        // 1) Görsel (ilk sekme)
        attach("01_gorsel")

        // 2) Yazı
        if tabs.count > 1 { tabs.element(boundBy: 1).tap(); sleep(2); attach("02_yazi") }

        // 3) Stüdyo
        if tabs.count > 2 { tabs.element(boundBy: 2).tap(); sleep(2); attach("03_studyo") }

        // 4) Ürünler (dolu görünür — Kütüphane boş olabilir, onu atla)
        if tabs.count > 4 { tabs.element(boundBy: 4).tap(); sleep(2); attach("04_urunler") }

        // 5) Görsel sekmesine dön + ilk aracın detayını aç
        if tabs.count > 0 { tabs.element(boundBy: 0).tap(); sleep(1) }
        let kart = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'görsel' OR label CONTAINS[c] 'üret' OR label CONTAINS[c] 'logo' OR label CONTAINS[c] 'photo'"
        ))
        if kart.count > 0 { kart.element(boundBy: 0).tap(); sleep(2); attach("05_detay") }

        // 6) PAYWALL / IAP — kredi satın alma ekranı (IAP review screenshot için EN ÖNEMLİ)
        // SS_MODE'da mock giriş yapıldığı için "Kredi Al" butonu doğrudan paketleri açar.
        if tabs.count > 0 { tabs.element(boundBy: 0).tap(); sleep(1) }
        let krediBtn = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'kredi' OR label CONTAINS[c] 'credit' OR label CONTAINS[c] 'bolt'"
        )).firstMatch
        if krediBtn.waitForExistence(timeout: 4) {
            krediBtn.tap(); sleep(3); attach("04_kredi_iap")
        }
    }

    private func attach(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
