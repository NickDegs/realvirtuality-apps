import SwiftUI
import StoreKit

// MARK: - Hesabım (SMS ile doğrula → satın alınanları göster + Restore)

private let BASE_URL = "https://nickdegs.com"

struct HesabimView: View {
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @State private var ulke = ULKE_VARSAYILAN
    @State private var tel = ""
    @State private var smsKod = ""
    @State private var smsGonderildi = false
    @State private var bekle = false
    @State private var hata = ""
    @State private var satinaldiklarim: SatinAlinanlar? = nil
    @State private var restoreMsg = ""
    @State private var silOnay = false
    @StateObject private var magaza = Magaza()

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedArka(c1: tema.c1, c2: tema.c2)
                LensFlare()
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer(minLength: 16)
                        // Logo
                        VStack(spacing: 6) {
                            Image(systemName: "bag.fill.badge.checkmark").font(.system(size: 48)).foregroundStyle(tema.grad)
                            Text("Hesabım").font(.largeTitle.bold()).foregroundStyle(.rvText)
                            Text("Satın aldıklarını görmek için numaranı doğrula").font(.subheadline).foregroundStyle(.rvMut).multilineTextAlignment(.center)
                        }

                        if let s = satinaldiklarim {
                            satinAldiklarimGorunum(s)
                        } else {
                            smsGirisForm
                        }

                        if !hata.isEmpty {
                            Text(hata).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center).padding(.horizontal)
                        }
                        if !restoreMsg.isEmpty {
                            Text(restoreMsg).font(.caption).foregroundStyle(.green).multilineTextAlignment(.center)
                        }

                        // Restore Purchases
                        Button {
                            restoreMsg = ""
                            Task {
                                bekle = true; defer { bekle = false }
                                let r = await magaza.restorePurchases()
                                restoreMsg = r == "ok" ? "Satın alımlar geri yüklendi." : r
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if bekle { ProgressView().tint(tema.c1) }
                                Image(systemName: "arrow.clockwise.circle")
                                Text("Satın Alımları Geri Yükle")
                            }.font(.subheadline).foregroundStyle(tema.c1)
                        }.disabled(bekle).padding(.top, 4)

                        if satinaldiklarim != nil {
                            Button { satinaldiklarim = nil; smsKod = ""; smsGonderildi = false; tel = ""; oturumSil() } label: {
                                Text("Çıkış Yap").font(.caption).foregroundStyle(.rvMut)
                            }.padding(.top, 2)
                            Button(role: .destructive) { silOnay = true } label: {
                                Text("Hesabımı Sil").font(.caption.bold()).foregroundStyle(.red)
                            }.padding(.top, 6)
                            .confirmationDialog("Hesabını kalıcı olarak sil? Kişisel erişimin ve verilerin silinir. Aboneliğin App Store'dan yönetilir (Ayarlar > Apple Kimliği > Abonelikler).", isPresented: $silOnay, titleVisibility: .visible) {
                                Button("Hesabı Sil", role: .destructive) { Task { await hesapSil() } }
                                Button("Vazgeç", role: .cancel) {}
                            }
                        }
                        Spacer()
                    }.padding(24).frame(maxWidth: 480)
                }
            }
            .navigationTitle("Hesabım").navigationBarTitleDisplayMode(.inline)
            .task { oturumGeriYukle() }   // kapat-aç'ta üyeliği geri yükle (SMS sorma)
        }.tint(tema.c1)
    }

    // MARK: SMS giriş formu
    var smsGirisForm: some View {
        VStack(spacing: 14) {
            // Ülke kodu + tel
            HStack(spacing: 10) {
                UlkeKodSecici(secili: $ulke)
                    .padding(.horizontal, 12).padding(.vertical, 14)
                    .background(Color.rvCard, in: .rect(cornerRadius: 12))
                Divider().frame(height: 22).overlay(Color.rvMut.opacity(0.4))
                TextField("5xx xxx xx xx", text: $tel)
                    .keyboardType(.phonePad).autocorrectionDisabled()
                    .foregroundStyle(.rvText).padding(.vertical, 14).padding(.horizontal, 12)
                    .background(Color.rvCard, in: .rect(cornerRadius: 12))
            }
            if smsGonderildi {
                TextField("SMS kodu", text: $smsKod)
                    .keyboardType(.numberPad).autocorrectionDisabled()
                    .foregroundStyle(.rvText).padding(.vertical, 14).padding(.horizontal, 12)
                    .background(Color.rvCard, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(tema.c1.opacity(0.5), lineWidth: 1))

                Button { Task { await smsDogrula() } } label: {
                    anaButon("Doğrula & Görüntüle")
                }.disabled(bekle || smsKod.trimmingCharacters(in: .whitespaces).count < 4)

                Button("← Numarayı değiştir") {
                    smsGonderildi = false; smsKod = ""; hata = ""
                }.font(.caption).foregroundStyle(tema.c2)
            } else {
                Button { Task { await smsGonder() } } label: {
                    anaButon("SMS Kodu Gönder")
                }.disabled(bekle || tel.trimmingCharacters(in: .whitespaces).count < 7)
            }
        }
    }

    func anaButon(_ t: String) -> some View {
        HStack(spacing: 8) {
            if bekle { ProgressView().tint(.white) }
            Text(t).font(.headline.bold())
        }
        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(tema.grad, in: .rect(cornerRadius: 16))
        .shadow(color: tema.c1.opacity(0.35), radius: 12, y: 5)
    }

    // MARK: Satın alınanları göster
    @ViewBuilder func satinAldiklarimGorunum(_ s: SatinAlinanlar) -> some View {
        VStack(spacing: 14) {
            if let isl = s.isletme, !isl.panel_url.isEmpty {
                PaketKartiK(
                    ikon: "storefront.fill", baslik: "İşletme Paneli",
                    renk: .blue, aktif: isl.aktif, bitis: isl.bitis
                ) {
                    BilgiSatiriK(etiket: "Panel Adresi", deger: isl.panel_url)
                    BilgiSatiriK(etiket: "Kullanıcı Adı", deger: isl.kadi)
                    BilgiSatiriK(etiket: "Şifre", deger: isl.sifre, gizle: true)
                    BilgiSatiriK(etiket: "Dashboard Kodu", deger: isl.tenant)
                    NavigationLink {
                        IsletmePanelView(
                            apiBase: isl.apiBase.isEmpty ? isl.panel_url : isl.apiBase,
                            did: isl.did.isEmpty ? isl.tenant : isl.did,
                            aile: isl.aile, sektor: isl.sektor,
                            kadi: isl.kadi, sifre: isl.sifre)
                    } label: {
                        Label("İşletmeyi Yönet (Canlı Panel)", systemImage: "chart.bar.doc.horizontal")
                            .font(.subheadline.bold()).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(tema.grad, in: .rect(cornerRadius: 12))
                    }.padding(.top, 4)
                    Text("Siparişleri, ciroyu ve menüyü doğrudan uygulamadan yönet.")
                        .font(.caption2).foregroundStyle(.rvMut).padding(.top, 2)
                }
            } else {
                BosPaketK(ikon: "storefront", baslik: "İşletme Paneli", mesaj: "Henüz işletme paneli satın alınmadı")
            }

            if let guv = s.guvenlik, !guv.guvenlik_url.isEmpty {
                PaketKartiK(ikon: "lock.shield.fill", baslik: "Güvenlik Paketi", renk: .green, aktif: guv.aktif, bitis: guv.bitis) {
                    BilgiSatiriK(etiket: "Korunan Adres", deger: guv.guvenlik_url)
                    Text("Cloudflare WAF + DDoS koruması aktif").font(.caption2).foregroundStyle(.rvMut)
                }
            } else {
                BosPaketK(ikon: "lock.shield", baslik: "Güvenlik Paketi", mesaj: "Güvenlik paketi eklenmedi")
            }

            if let hush = s.hush, !hush.hush_url.isEmpty {
                PaketKartiK(ikon: "bubble.left.and.bubble.right.fill", baslik: "Hush Chat", renk: .purple, aktif: hush.aktif, bitis: hush.bitis) {
                    BilgiSatiriK(etiket: "Sohbet Adresi", deger: hush.hush_url)
                    BilgiSatiriK(etiket: "Kullanıcı ID", deger: hush.hush_uid)
                    BilgiSatiriK(etiket: "Şifre", deger: hush.sifre, gizle: true)
                }
            } else {
                BosPaketK(ikon: "bubble.left.and.bubble.right", baslik: "Hush Chat", mesaj: "Hush chat paketi eklenmedi")
            }
        }
    }

    // MARK: API
    func tamNumara() -> String {
        let d = String(tel.filter { $0.isNumber }.drop(while: { $0 == "0" }))
        return "+\(ulke.kod)\(d)"
    }

    func post(_ yol: String, _ govde: [String: Any]) async -> [String: Any] {
        guard let url = URL(string: BASE_URL + yol) else { return ["ok": false] }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.timeoutInterval = 25
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: govde)
        guard let (d, _) = try? await URLSession.shared.data(for: r),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return ["ok": false] }
        return j
    }

    func smsGonder() async {
        hata = ""; bekle = true; defer { bekle = false }
        let j = await post("/api/iap/sms-gonder", ["tel": tamNumara()])
        if j["ok"] as? Bool == true { smsGonderildi = true }
        else { hata = (j["mesaj"] as? String) ?? "SMS gönderilemedi." }
    }

    func smsDogrula() async {
        hata = ""; bekle = true; defer { bekle = false }
        let j = await post("/api/iap/sms-dogrula", ["tel": tamNumara(), "kod": smsKod])
        if j["ok"] as? Bool == true {
            let s = SatinAlinanlar(from: j)
            satinaldiklarim = s
            oturumKaydet(j, tamNumara())   // kapat-aç'ta tekrar SMS isteme
            // İşletme sahibiyse APNs push'a kaydol (yeni sipariş/randevu bildirimi)
            if let isl = s.isletme, !isl.panelToken.isEmpty {
                UserDefaults.standard.set(isl.panelToken, forKey: "biz_panel_token")
                pushKaydet()
            }
        } else {
            hata = (j["mesaj"] as? String) ?? "Kod doğrulanamadı."
        }
    }

    // ── Oturum kalıcılığı (Barış 2026-06-30): kapat-aç'ta tekrar SMS login istemesin ──
    func oturumKaydet(_ j: [String: Any], _ telNo: String) {
        if let d = try? JSONSerialization.data(withJSONObject: j) {
            UserDefaults.standard.set(d, forKey: "biz_hesabim_json")
            UserDefaults.standard.set(telNo, forKey: "biz_hesabim_tel")
        }
    }
    /// Açılışta cache'lenmiş üyeliği geri yükler (SMS sormadan) + arka planda tazeler.
    func oturumGeriYukle() {
        guard satinaldiklarim == nil,
              let d = UserDefaults.standard.data(forKey: "biz_hesabim_json"),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              j["ok"] as? Bool == true else { return }
        tel = UserDefaults.standard.string(forKey: "biz_hesabim_tel") ?? tel
        satinaldiklarim = SatinAlinanlar(from: j)
        if let isl = satinaldiklarim?.isletme, !isl.panelToken.isEmpty {
            UserDefaults.standard.set(isl.panelToken, forKey: "biz_panel_token")
        }
        Task { await tazele() }   // arka planda güncel veriyi çek (abonelik/expiry değişmişse)
    }
    /// Saklı telefon + imzalı token ile güncel satın alınanları yeniden çek (SMS gerektirmez).
    func tazele() async {
        let telNo = UserDefaults.standard.string(forKey: "biz_hesabim_tel") ?? ""
        var tok = ""
        if let d = UserDefaults.standard.data(forKey: "biz_hesabim_json"),
           let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            tok = j["durumTok"] as? String ?? ""
        }
        guard !telNo.isEmpty, !tok.isEmpty else { return }
        let j = await post("/api/iap/durum", ["tel": telNo, "tok": tok])
        if j["ok"] as? Bool == true {
            satinaldiklarim = SatinAlinanlar(from: j)
            oturumKaydet(j, telNo)
        }
    }
    func oturumSil() {
        UserDefaults.standard.removeObject(forKey: "biz_hesabim_json")
        UserDefaults.standard.removeObject(forKey: "biz_hesabim_tel")
    }
    // Apple 5.1.1(v): uygulama-içi hesap silme. Sunucuda kişisel erişim/entitlement kayıtlarını siler,
    // oturumu kapatır. Abonelik Apple'da kalır (Restore ile geri gelir).
    func hesapSil() async {
        let telNo = UserDefaults.standard.string(forKey: "biz_hesabim_tel") ?? ""
        var tok = ""
        if let d = UserDefaults.standard.data(forKey: "biz_hesabim_json"),
           let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            tok = j["durumTok"] as? String ?? ""
        }
        if !telNo.isEmpty, !tok.isEmpty {
            _ = await post("/api/iap/hesap-sil", ["tel": telNo, "tok": tok])
        }
        satinaldiklarim = nil; smsKod = ""; smsGonderildi = false; tel = ""
        oturumSil()
    }
}

// MARK: - Veri modelleri

struct SatinAlinanlar {
    struct IslPaketi {
        let aktif: Bool; let tenant: String; let panel_url: String
        let kadi: String; let sifre: String; let bitis: Int
        let apiBase: String; let did: String; let aile: String; let sektor: String
        let panelToken: String
    }
    struct GuvPaketi { let aktif: Bool; let guvenlik_url: String; let bitis: Int }
    struct HushPaketi { let aktif: Bool; let hush_url: String; let hush_uid: String; let sifre: String; let bitis: Int }

    let isletme: IslPaketi?
    let guvenlik: GuvPaketi?
    let hush: HushPaketi?

    init(from j: [String: Any]) {
        if let d = j["isletme"] as? [String: Any], !(d["panel_url"] as? String ?? "").isEmpty {
            let aktif = d["aktif"] as? Bool ?? false
            let tenant = d["tenant"] as? String ?? ""
            let purl = d["panel_url"] as? String ?? ""
            let kadi = d["kadi"] as? String ?? ""
            let sifre = d["sifre"] as? String ?? ""
            let bitis = d["bitis"] as? Int ?? 0
            let apiBase = d["api_base"] as? String ?? ""
            let did = d["did"] as? String ?? ""
            let aile = d["aile"] as? String ?? ""
            let sektor = d["sektor"] as? String ?? ""
            let pt = d["panel_token"] as? String ?? ""
            isletme = .init(aktif: aktif, tenant: tenant, panel_url: purl, kadi: kadi, sifre: sifre,
                            bitis: bitis, apiBase: apiBase, did: did, aile: aile, sektor: sektor, panelToken: pt)
        } else { isletme = nil }

        if let d = j["guvenlik"] as? [String: Any], !(d["guvenlik_url"] as? String ?? "").isEmpty {
            guvenlik = .init(aktif: d["aktif"] as? Bool ?? false,
                             guvenlik_url: d["guvenlik_url"] as? String ?? "",
                             bitis: d["bitis"] as? Int ?? 0)
        } else { guvenlik = nil }

        if let d = j["hush"] as? [String: Any], !(d["hush_url"] as? String ?? "").isEmpty {
            hush = .init(aktif: d["aktif"] as? Bool ?? false,
                         hush_url: d["hush_url"] as? String ?? "",
                         hush_uid: d["hush_uid"] as? String ?? "",
                         sifre: d["sifre"] as? String ?? "",
                         bitis: d["bitis"] as? Int ?? 0)
        } else { hush = nil }
    }
}

// MARK: - Yardımcı görünümler (Business app'e özgü, Dashboard'dan bağımsız)

struct PaketKartiK<C: View>: View {
    let ikon: String; let baslik: String; let renk: Color
    let aktif: Bool; let bitis: Int
    @ViewBuilder let icerik: () -> C
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: ikon).font(.system(size: 20)).foregroundStyle(renk)
                Text(baslik).font(.subheadline.bold()).foregroundStyle(.rvText)
                Spacer()
                Label(aktif ? "Aktif" : "Süresi doldu",
                      systemImage: aktif ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2.bold()).foregroundStyle(aktif ? .green : .red)
            }
            if bitis > 0 {
                Text("Bitiş: \(Date(timeIntervalSince1970: TimeInterval(bitis)), style: .date)")
                    .font(.caption2).foregroundStyle(.rvMut)
            }
            Divider().overlay(Color.rvLine)
            icerik()
        }.padding(14)
            .background(Color.rvCard, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rvLine, lineWidth: 1))
            .padding(.horizontal)
    }
}

struct BilgiSatiriK: View {
    let etiket: String; let deger: String; var gizle: Bool = false
    @State private var goster = false
    var body: some View {
        if deger.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(etiket).font(.caption2).foregroundStyle(.rvMut)
                HStack(spacing: 8) {
                    if gizle && !goster {
                        Text(String(repeating: "•", count: min(deger.count, 12)))
                            .font(.subheadline.bold()).foregroundStyle(.rvText)
                        Button { goster = true } label: {
                            Image(systemName: "eye").font(.caption).foregroundStyle(.rvMut)
                        }.buttonStyle(.plain)
                    } else {
                        Text(deger).font(.subheadline.bold()).foregroundStyle(.rvText).textSelection(.enabled)
                        if gizle {
                            Button { goster = false } label: {
                                Image(systemName: "eye.slash").font(.caption).foregroundStyle(.rvMut)
                            }.buttonStyle(.plain)
                        }
                        Button {
                            UIPasteboard.general.string = deger
                        } label: {
                            Image(systemName: "doc.on.doc").font(.caption).foregroundStyle(.rvMut)
                        }.buttonStyle(.plain)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct BosPaketK: View {
    let ikon: String; let baslik: String; let mesaj: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: ikon).font(.system(size: 20)).foregroundStyle(.rvMut)
            VStack(alignment: .leading, spacing: 2) {
                Text(baslik).font(.subheadline.bold()).foregroundStyle(.rvMut)
                Text(mesaj).font(.caption2).foregroundStyle(.rvMut.opacity(0.6))
            }
        }
        .padding(14)
        .background(Color.rvCard.opacity(0.6), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rvLine.opacity(0.5), lineWidth: 1))
        .padding(.horizontal)
    }
}
