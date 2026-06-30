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

        // 1. Ana ekran — uygulama logosu / karşılama
        attach("01_hosgeldiniz")

        // 2. Scroll — genel görünüm
        app.scrollViews.firstMatch.swipeUp()
        sleep(1)
        attach("02_genel_gorunum")
        app.scrollViews.firstMatch.swipeDown()
        sleep(1)

        // 3. Son sekme (Hesabım / Abonelik) — kişisel veri yok, IAP gerekli
        let tabs = app.tabBars.buttons
        if tabs.count > 0 {
            tabs.element(boundBy: tabs.count - 1).tap()
            sleep(2)
        }
        attach("03_hesabim")

        // 4. İkinci sekme
        if tabs.count > 1 {
            tabs.element(boundBy: 1).tap()
            sleep(2)
        }
        attach("04_kesfet")

        // 5. Üçüncü sekme
        if tabs.count > 2 {
            tabs.element(boundBy: 2).tap()
            sleep(2)
        }
        attach("05_ozellikler")

        // 6. İlk sekme — ana sayfa
        if tabs.count > 0 {
            tabs.element(boundBy: 0).tap()
            sleep(1)
        }
        attach("06_ana_sayfa")

        // 7) ABONELİK PAYWALL'LARI — her sektör için gerçek SatinAlView (IAP review screenshot)
        // App'i SS_SCREEN=<sektör> ile yeniden başlat → root doğrudan o sektörün abonelik ekranı olur.
        for sektor in ["guvenlik", "hush", "sunucu", "isletme"] {
            app.terminate()
            app.launchEnvironment["SS_MODE"] = "1"
            app.launchEnvironment["SS_SCREEN"] = sektor
            app.launch()
            sleep(4)
            attach("iap_\(sektor)")
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
