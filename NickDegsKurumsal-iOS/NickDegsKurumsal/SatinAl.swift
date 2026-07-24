import SwiftUI
import StoreKit

// NickDegs Dashboard uygulamasını aç. Kurulu değilse App Store'daki Dashboard
// sayfasını açar (App Store ID 6782606941) — web sitesine DÜŞMEZ.
@MainActor
func dashboardUygulamasiniAc(token: String?, _ ac: OpenURLAction) {
    let dashYukle = URL(string: "https://apps.apple.com/app/id6782606941")!
    let scheme = (token?.isEmpty == false) ? "nickdegs-panel://login?t=\(token!)" : "nickdegs-panel://"
    if let deeplink = URL(string: scheme) {
        ac(deeplink) { acildi in
            if !acildi { ac(dashYukle) }   // Dashboard app yoksa yükleme sayfası
        }
    } else {
        ac(dashYukle)
    }
}

// MARK: - StoreKit Mağaza yöneticisi (App Store içi satın alma + sunucu provision)
@MainActor
final class Magaza: ObservableObject {
    static let urunIdleri = [
        "com.nickdegs.business.isletme.baslangic.yil",
        "com.nickdegs.business.isletme.pro.yil",
        "com.nickdegs.business.isletme.kurumsal.yil",
        "com.nickdegs.business.guvenlik.ay",
        "com.nickdegs.business.guvenlik.yil",
        "com.nickdegs.business.hush.ay",
        "com.nickdegs.business.hush.yil",
        "com.nickdegs.business.sunucu.ay",
        "com.nickdegs.business.sunucu.yil",
    ]
    @Published var urunler: [Product] = []
    @Published var yukleniyor = false

    func yukle() async {
        yukleniyor = true; defer { yukleniyor = false }
        urunler = ((try? await Product.products(for: Magaza.urunIdleri)) ?? [])
            .sorted { $0.price < $1.price }
    }
    func urun(_ id: String) -> Product? { urunler.first { $0.id == id } }

    // Satın al → doğrulanmış işlemin imzalı JWS'ini döndür
    // tx.finish() ÇAĞIRMA — provision başarılı olunca çağıran finish() çağırır
    func satinAl(_ p: Product) async -> (jws: String?, tx: StoreKit.Transaction?, hata: String?) {
        do {
            switch try await p.purchase() {
            case .success(let v):
                if case .verified(let t) = v {
                    return (v.jwsRepresentation, t, nil)
                }
                return (nil, nil, "Satın alma doğrulanamadı")
            case .userCancelled: return (nil, nil, "iptal")
            case .pending: return (nil, nil, "Onay bekleniyor")
            @unknown default: return (nil, nil, "Bilinmeyen durum")
            }
        } catch { return (nil, nil, error.localizedDescription) }
    }

    // Restore Purchases — App Store'dan mevcut abonelikleri yeniden çek
    func restorePurchases() async -> String {
        do {
            try await AppStore.sync()
            await entitlementleriYukle()
            return "ok"
        } catch {
            return error.localizedDescription
        }
    }

    // Bu Apple Kimliği/cihazda AKTİF olan abonelikler (StoreKit currentEntitlements)
    // — SMS/sunucu gerektirmez, satın alım anında görünür.
    struct EntitlementBilgi: Identifiable {
        let id: String        // productId
        let bitis: Date?      // yenilenme/bitiş tarihi
    }
    @Published var aktifEntitlementlar: [EntitlementBilgi] = []

    func entitlementleriYukle() async {
        var list: [EntitlementBilgi] = []
        for await sonuc in Transaction.currentEntitlements {
            guard case .verified(let t) = sonuc else { continue }
            if t.revocationDate != nil { continue }              // iptal/iade edilmiş
            guard Magaza.urunIdleri.contains(t.productID) else { continue }
            if !list.contains(where: { $0.id == t.productID }) {
                list.append(EntitlementBilgi(id: t.productID, bitis: t.expirationDate))
            }
        }
        aktifEntitlementlar = list.sorted { $0.id < $1.id }
    }

    // productId → okunabilir ad (StoreKit ürünü yüklü değilse yedek)
    static func urunAdi(_ id: String) -> String {
        let map: [String: String] = [
            "com.nickdegs.business.isletme.baslangic.yil": "İşletme Başlangıç (Yıllık)",
            "com.nickdegs.business.isletme.pro.yil":       "İşletme Profesyonel (Yıllık)",
            "com.nickdegs.business.isletme.kurumsal.yil":  "İşletme Kurumsal (Yıllık)",
            "com.nickdegs.business.guvenlik.ay":  "Güvenlik (Aylık)",
            "com.nickdegs.business.guvenlik.yil": "Güvenlik (Yıllık)",
            "com.nickdegs.business.hush.ay":      "Hush Sohbet (Aylık)",
            "com.nickdegs.business.hush.yil":     "Hush Sohbet (Yıllık)",
            "com.nickdegs.business.sunucu.ay":    "Sunucu (Aylık)",
            "com.nickdegs.business.sunucu.yil":   "Sunucu (Yıllık)",
        ]
        return map[id] ?? id
    }

    // Provision: işletme aboneliği alındıysa sunucuda tenant + Dashboard hesabı açtırır
    func provision(jws: String, ad: String, sektor: String) async -> [String: Any] {
        var r = URLRequest(url: URL(string: "https://nickdegs.com/api/iap/provision")!)
        r.httpMethod = "POST"; r.timeoutInterval = 130
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["signedTransaction": jws, "ad": ad, "sektor": sektor])
        guard let (d, _) = try? await URLSession.shared.data(for: r),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return ["ok": false, "err": "bağlantı"] }
        return j
    }
}

// MARK: - Sektör modeli
struct Sektor: Identifiable {
    let id: String; let ad: String; let ikon: String
}
let SEKTORLER: [Sektor] = [
    Sektor(id: "lokanta",    ad: "Restoran / Lokanta",     ikon: "fork.knife"),
    Sektor(id: "kafe",       ad: "Kafe",                   ikon: "cup.and.saucer.fill"),
    Sektor(id: "market",     ad: "Market / Mağaza",        ikon: "cart.fill"),
    Sektor(id: "otel",       ad: "Otel / Pansiyon",        ikon: "bed.double.fill"),
    Sektor(id: "kuafor",     ad: "Kuaför / Güzellik",      ikon: "scissors"),
    Sektor(id: "klinik",     ad: "Klinik / Hastane",       ikon: "cross.fill"),
    Sektor(id: "veteriner",  ad: "Veteriner",              ikon: "pawprint.fill"),
    Sektor(id: "spor",       ad: "Spor Salonu",            ikon: "figure.run"),
    Sektor(id: "estetik",    ad: "Estetik / Spa",          ikon: "sparkles"),
    Sektor(id: "hukuk",      ad: "Hukuk Bürosu",           ikon: "building.columns.fill"),
    Sektor(id: "ogretmen",   ad: "Öğretmen / Eğitim",      ikon: "graduationcap.fill"),
    Sektor(id: "diger",      ad: "Diğer İşletme",          ikon: "briefcase.fill"),
]

// MARK: - Satın alma sayfası
struct SatinAlView: View {
    let urun: Urun
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @StateObject private var magaza = Magaza()
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var acURL
    @State private var isletmeAd = ""
    @State private var seciliSektor: Sektor = SEKTORLER[0]
    @State private var secili: Product? = nil
    @State private var bekle = false
    @State private var sonuc: [String: Any]? = nil
    @State private var hata = ""
    @State private var lokalFiyatlar: [String: String] = [:]   // pid → "₺X,XXX"

    // Bu ürünün sekmesine göre uygun App Store abonelikleri
    private var planlar: [Product] {
        let pre = urun.sekme == "guvenlik" ? "com.nickdegs.business.guvenlik"
                : "com.nickdegs.business.isletme"
        let p = magaza.urunler.filter { $0.id.hasPrefix(pre) }
        return p.isEmpty ? magaza.urunler.filter { $0.id.contains("isletme") } : p
    }
    private var isletmeMi: Bool { urun.sekme != "guvenlik" }
    // Bu ekranda gösterilen planlardan zaten sahip olunanlar (tekrar satın almayı önler)
    private var sahipOlunanPlanlar: [Product] {
        planlar.filter { p in magaza.aktifEntitlementlar.contains { $0.id == p.id } }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedArka(c1: tema.c1, c2: tema.c2)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let s = sonuc, s["ok"] as? Bool == true {
                            basariKart(s)
                        } else {
                            Text(yerel.u(urun.ad)).font(.title2.bold()).foregroundStyle(.rvText)
                            Text("Aboneliğini App Store üzerinden güvenle başlat. Ödeme sonrası paneline anında erişirsin.")
                                .font(.subheadline).foregroundStyle(.rvMut)

                            if isletmeMi {
                                Text("İşletme adı").font(.caption.bold()).foregroundStyle(.rvMut).padding(.top, 4)
                                TextField("Örn. Köşe Cafe", text: $isletmeAd)
                                    .padding(14).glassEffect(.regular, in: .rect(cornerRadius: 14)).foregroundStyle(.rvText)

                                Text("Sektör").font(.caption.bold()).foregroundStyle(.rvMut).padding(.top, 2)
                                Menu {
                                    ForEach(SEKTORLER) { s in
                                        Button {
                                            seciliSektor = s
                                        } label: {
                                            Label(s.ad, systemImage: s.ikon)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: seciliSektor.ikon).foregroundStyle(tema.c1)
                                        Text(seciliSektor.ad).foregroundStyle(.rvText)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.rvMut)
                                    }
                                    .padding(14).glassEffect(.regular, in: .rect(cornerRadius: 14))
                                }
                            }

                            if magaza.yukleniyor {
                                ProgressView().tint(tema.c1).frame(maxWidth: .infinity).padding()
                            } else if planlar.isEmpty {
                                Text("Planlar yüklenemedi. İnternet bağlantını kontrol et.").font(.caption).foregroundStyle(.orange)
                            } else {
                                ForEach(planlar, id: \.id) { p in planKart(p) }
                            }

                            // Zaten sahip olunan abonelik varsa uyar (tekrar satın alma yerine yönlendir)
                            if !sahipOlunanPlanlar.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                                    Text("Bu aboneliğe zaten sahipsin. 'Hesabım' sekmesinden görebilir, App Store > Abonelikler'den yönetebilirsin.")
                                        .font(.caption).foregroundStyle(.rvText)
                                }
                                .padding(12).background(Color.green.opacity(0.12), in: .rect(cornerRadius: 12))
                            }

                            if !hata.isEmpty { Text(hata).font(.caption).foregroundStyle(.orange) }

                            Button { Task { await satinAl() } } label: {
                                HStack(spacing: 8) {
                                    if bekle { ProgressView().tint(.white) }
                                    Image(systemName: "applelogo"); Text("App Store ile Satın Al")
                                }
                                .font(.headline.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(tema.grad, in: .rect(cornerRadius: 16))
                            }.disabled(bekle)   // buton HER ZAMAN tepki verir; eksik alan varsa satinAl() uyarır (Apple 2.1b fiksi)
                            .padding(.top, 6)

                            Text("Abonelik otomatik yenilenir, dilediğin an iptal edebilirsin. Ödeme Apple hesabından alınır.")
                                .font(.caption2).foregroundStyle(.rvMut).padding(.top, 4)

                            // Guideline 3.1.2(c): Privacy + Terms abonelik ekranında görünmeli
                            HStack(spacing: 12) {
                                Link("Gizlilik Politikası", destination: URL(string: "https://nickdegs.com/legal/privacy")!)
                                Text("·").foregroundStyle(.rvMut)
                                Link("Kullanım Koşulları", destination: URL(string: "https://nickdegs.com/legal/tos")!)
                            }
                            .font(.caption2).foregroundStyle(tema.c1)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 2)
                        }
                    }.padding(20)
                }
            }
            .navigationTitle("Satın Al").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(tema.c1) } }
        }
        .tint(tema.c1)
        .task {
            await magaza.yukle(); secili = planlar.first
            await lokalFiyatYukle()
            await magaza.entitlementleriYukle()   // zaten sahip olunanları işaretle
        }
    }

    func planKart(_ p: Product) -> some View {
        let sec = secili?.id == p.id
        let gosterFiyat = lokalFiyatlar[p.id] ?? p.displayPrice
        return Button { secili = p } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.displayName).font(.subheadline.bold()).foregroundStyle(.rvText).lineLimit(1).minimumScaleFactor(0.7)
                    Text(p.description).font(.caption2).foregroundStyle(.rvMut).lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(gosterFiyat).font(.subheadline.bold()).foregroundStyle(tema.c2).lineLimit(1).minimumScaleFactor(0.6)
                    if lokalFiyatlar[p.id] != nil {
                        Text(p.displayPrice).font(.system(size: 9)).foregroundStyle(.rvMut)
                    }
                }
                Image(systemName: sec ? "checkmark.circle.fill" : "circle").foregroundStyle(sec ? tema.c1 : .rvMut)
            }
            .padding(15)
            .background(Color.rvCard, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(sec ? tema.c1 : Color.rvLine, lineWidth: sec ? 2 : 1))
        }.buttonStyle(.plain)
    }

    func lokalFiyatYukle() async {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        guard let url = URL(string: "https://nickdegs.com/api/iap/local-prices?lang=\(lang)") else { return }
        guard let (d, _) = try? await URLSession.shared.data(from: url),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let prices = j["prices"] as? [String: Any] else { return }
        var dict: [String: String] = [:]
        for (k, v) in prices {
            if let info = v as? [String: Any], let price = info["price"] as? String {
                dict[k] = price
            }
        }
        lokalFiyatlar = dict
    }

    func basariKart(_ s: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 50)).foregroundStyle(.green)
            Text("Sistemin hazır! 🎉").font(.title2.bold()).foregroundStyle(.rvText)
            if let url = s["url"] as? String, !url.isEmpty { satir("Panel adresi", url) }
            if let sf = s["sifre"] as? String, !sf.isEmpty { satir("Şifre (kaydet)", sf) }

            // Panele git → NickDegs Dashboard uygulamasını aç (işletme sahibi görünümü).
            // Kurulu değilse App Store'daki Dashboard sayfasına gider — web'e DÜŞMEZ.
            Button {
                dashboardUygulamasiniAc(token: s["panel_token"] as? String, acURL)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right.app.fill")
                    Text("Dashboard'da Aç")
                }
                .font(.headline.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(tema.grad, in: .rect(cornerRadius: 16))
            }.padding(.top, 4)
            Text("NickDegs Dashboard uygulaması işletme sahibi olarak açılır. Kurulu değilse App Store'dan yükleyebilirsin.")
                .font(.caption2).foregroundStyle(.rvMut).multilineTextAlignment(.center)
            if let kod = s["dashboard_kod"] as? String ?? s["tenant"] as? String {
                satir("Dashboard giriş kodu", kod)
            }

            Button("Kapat") { dismiss() }.font(.subheadline).foregroundStyle(.rvMut)
                .frame(maxWidth: .infinity).padding(.vertical, 12).padding(.top, 4)
        }
    }
    func satir(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.caption2).foregroundStyle(.rvMut)
            Text(v).font(.subheadline.bold()).foregroundStyle(tema.c1).textSelection(.enabled)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color.rvCard, in: .rect(cornerRadius: 12))
    }

    func satinAl() async {
        // Buton her zaman tepki verir; eksik alanları burada net uyarı ile bildir (Apple 2.1b)
        if isletmeMi && isletmeAd.trimmingCharacters(in: .whitespaces).isEmpty {
            hata = "Lütfen önce işletme adını girin."; return
        }
        guard let p = secili ?? planlar.first else {
            hata = "Bir abonelik planı seçin (planlar yüklenemediyse internet bağlantını kontrol et)."; return
        }
        secili = p
        hata = ""; bekle = true; defer { bekle = false }
        let (jws, tx, h) = await magaza.satinAl(p)
        if let h = h { if h != "iptal" { hata = h }; return }
        guard let jws = jws else { hata = "Satın alma doğrulanamadı"; return }
        let r = await magaza.provision(jws: jws, ad: isletmeAd, sektor: isletmeMi ? seciliSektor.id : urun.g)
        if r["ok"] as? Bool == true {
            // Provision başarılı → şimdi finish()
            if let tx = tx { await tx.finish() }
            // Dashboard oto-giriş token'ını sakla (Hesabım'daki 'Dashboard'da Aç' bunu kullanır)
            if let pt = r["panel_token"] as? String, !pt.isEmpty {
                UserDefaults.standard.set(pt, forKey: "biz_panel_token")
            }
            sonuc = r
        } else {
            // Provision başarısız — transaction bitmedi, Apple yeniden deneyecek
            hata = (r["err"] as? String) ?? "Kurulum yapılamadı — abonelik aktif, destek ile iletişime geç."
        }
    }
}
