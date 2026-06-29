import AppIntents
import SwiftUI

// MARK: - Siri & Kısayollar (App Intents — ANA target, ayrı extension YOK → imza riski yok)
// "RealVirtuality'de görsel üret" gibi komutlar uygulamayı ilgili sekmeye açar.

enum RVHedef: Int {
    case gorsel = 0, icerik = 1, studyo = 2, kutuphane = 3
}

// Intent (gerekirse arka plan/cold-launch süreci) → app süreci köprüsü: UserDefaults (aynı sandbox)
enum RVNav {
    static let key = "rv_nav_tab"
    @MainActor static func iste(_ h: RVHedef) { UserDefaults.standard.set(h.rawValue, forKey: key) }
    @MainActor static func bekleyen() -> Int? {
        let d = UserDefaults.standard
        guard d.object(forKey: key) != nil else { return nil }
        let v = d.integer(forKey: key); d.removeObject(forKey: key); return v
    }
}

struct GorselUretIntent: AppIntent {
    static var title: LocalizedStringResource = "Görsel Üret"
    static var description = IntentDescription("RealVirtuality AI'da görsel üretim araçlarını açar.")
    static var openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult {
        RVNav.iste(.gorsel); return .result()
    }
}

struct IcerikYazIntent: AppIntent {
    static var title: LocalizedStringResource = "İçerik Yaz"
    static var description = IntentDescription("RealVirtuality AI'da yazı/içerik araçlarını açar.")
    static var openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult {
        RVNav.iste(.icerik); return .result()
    }
}

struct StudyoIntent: AppIntent {
    static var title: LocalizedStringResource = "Stüdyo"
    static var description = IntentDescription("RealVirtuality AI ses & video stüdyosunu açar.")
    static var openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult {
        RVNav.iste(.studyo); return .result()
    }
}

struct KutuphaneIntent: AppIntent {
    static var title: LocalizedStringResource = "Kütüphanem"
    static var description = IntentDescription("RealVirtuality AI üretim kütüphaneni açar.")
    static var openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult {
        RVNav.iste(.kutuphane); return .result()
    }
}

struct RVShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: GorselUretIntent(), phrases: [
            "\(.applicationName)'de görsel üret",
            "\(.applicationName) ile görsel oluştur",
            "Create an image with \(.applicationName)",
            "Generate art in \(.applicationName)",
        ], shortTitle: "Görsel Üret", systemImageName: "photo.artframe")

        AppShortcut(intent: IcerikYazIntent(), phrases: [
            "\(.applicationName)'de içerik yaz",
            "\(.applicationName) ile yazı oluştur",
            "Write content with \(.applicationName)",
        ], shortTitle: "İçerik Yaz", systemImageName: "text.word.spacing")

        AppShortcut(intent: StudyoIntent(), phrases: [
            "\(.applicationName) stüdyosunu aç",
            "\(.applicationName)'de seslendirme yap",
            "Open \(.applicationName) studio",
        ], shortTitle: "Stüdyo", systemImageName: "waveform")

        AppShortcut(intent: KutuphaneIntent(), phrases: [
            "\(.applicationName) kütüphanemi aç",
            "Open my \(.applicationName) library",
        ], shortTitle: "Kütüphanem", systemImageName: "books.vertical.fill")
    }
}
