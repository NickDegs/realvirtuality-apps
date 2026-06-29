import SwiftUI

// MARK: - Randevu (kuaför/klinik/vet/spor/estetik…) + Öğretmen paneli (randevu-sistem / ogretmen-sistem)
// Aynı backend yapısı (appts/services/clients). Öğretmen için etiketler ders/öğrenci olur.
struct RandevuPanel: View {
    @ObservedObject var api: PanelAPI
    @EnvironmentObject var tema: Tema
    @State private var sekme = 0

    @State private var adet = 0, gelir = 0, doluluk = 0
    @State private var randevular: [[String: Any]] = []
    @State private var hizmetler: [[String: Any]] = []
    @State private var musteriler: [[String: Any]] = []
    // yeni randevu
    @State private var rAd = "", rTel = "", rHizmet = "", rFiyat = "", rGun = "", rSaat = ""
    // yeni hizmet
    @State private var hAd = "", hSure = "", hFiyat = ""

    static let durumAd = ["⏳ Bekliyor", "✅ Onaylandı", "🚶 Geldi", "✔️ Tamamlandı"]
    static let durumRenk: [Color] = [.orange, .blue, .purple, .green]

    var ogretmen: Bool { api.aile == .ogretmen }
    var randevuAd: String { ogretmen ? "Dersler" : "Randevular" }
    var hizmetAd: String { ogretmen ? "Ders Türleri" : "Hizmetler" }
    var musteriAd: String { ogretmen ? "Öğrenciler" : "Müşteriler" }
    var kisiAd: String { ogretmen ? "Öğrenci" : "Müşteri" }

    var sekmeler: [(String, String)] {
        [("Özet", "chart.bar.fill"), (randevuAd, "calendar"), (hizmetAd, "list.bullet.rectangle"),
         (musteriAd, "person.crop.circle"), ("Personel", "person.2.fill"), ("Ayar", "gearshape.fill")]
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelChips(sekmeler: sekmeler, secili: $sekme, tema: tema)
            switch sekme {
            case 0: ozet
            case 1: randevuTab
            case 2: hizmetTab
            case 3: musteriTab
            case 4: PersonelSekmesi(api: api, tema: tema)
            default: AyarSekmesi(api: api, tema: tema)
            }
        }.task { await yenile() }
    }

    func yenile() async {
        let s = await api.getObj("stats")
        adet = s["count"] as? Int ?? 0; gelir = s["revenue"] as? Int ?? 0; doluluk = s["occ"] as? Int ?? 0
        randevular = await api.getArr("appts")
        hizmetler = await api.getArr("services")
        musteriler = await api.getArr("clients")
    }

    var ozet: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    panelKpi(ogretmen ? "Bugün Ders" : "Bugün Randevu", "\(adet)", "calendar", .blue)
                    panelKpi("Bugün Ciro", "₺\(gelir)", "turkishlirasign.circle.fill", .green)
                }
                panelKpi("Doluluk", "%\(doluluk)", "gauge.medium", .orange)
            }.padding()
        }.refreshable { await yenile() }
    }

    var randevuTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text(ogretmen ? "Ders Ekle" : "Randevu Ekle").font(.subheadline.bold()).foregroundStyle(.rvText)
                    TextField("\(kisiAd) adı", text: $rAd).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    HStack {
                        TextField("Telefon", text: $rTel).keyboardType(.phonePad).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                        TextField(ogretmen ? "Ders" : "Hizmet", text: $rHizmet).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    }
                    HStack {
                        TextField("Fiyat ₺", text: $rFiyat).keyboardType(.numberPad).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                        TextField("GG-AA-YYYY → 2026-07-01", text: $rGun).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                        TextField("10:00", text: $rSaat).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    }
                    Button { Task { await randevuEkle() } } label: {
                        Text("Ekle").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                    }.disabled(rAd.isEmpty || rSaat.isEmpty)
                }
                if randevular.isEmpty { Text(ogretmen ? "Ders yok" : "Randevu yok").foregroundStyle(.rvMut).padding(.top, 20) }
                ForEach(Array(randevular.enumerated()), id: \.offset) { _, r in
                    let id = r["id"] as? Int ?? 0
                    let durum = r["status"] as? Int ?? 0
                    panelKart {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r["cust"] as? String ?? "-").font(.subheadline.bold()).foregroundStyle(.rvText)
                                Text("\(r["service"] as? String ?? "") · \(r["day"] as? String ?? "") \(r["time"] as? String ?? "")").font(.caption2).foregroundStyle(.rvMut)
                            }
                            Spacer()
                            Text("₺\(r["price"] as? Int ?? 0)").font(.subheadline).foregroundStyle(tema.c1)
                        }
                        HStack {
                            Text(Self.durumAd[min(3, max(0, durum))]).font(.caption.bold()).foregroundStyle(Self.durumRenk[min(3, max(0, durum))])
                            Spacer()
                            if durum < 3 {
                                Button { Task { _ = await api.post("appt/\(id)/advance"); await yenile() } } label: {
                                    Text("İlerlet →").font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 6).background(tema.grad, in: .capsule)
                                }
                            }
                            Button { Task { _ = await api.post("appt/\(id)/cancel"); await yenile() } } label: {
                                Image(systemName: "xmark.circle").foregroundStyle(.red)
                            }.padding(.leading, 6)
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    func randevuEkle() async {
        var body: [String: Any] = ["name": rAd, "phone": rTel, "service": rHizmet, "price": Int(rFiyat) ?? 0, "time": rSaat]
        if !rGun.isEmpty { body["day"] = rGun }
        _ = await api.post("appt", body)
        rAd = ""; rTel = ""; rHizmet = ""; rFiyat = ""; rGun = ""; rSaat = ""
        await yenile()
    }

    var hizmetTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text(ogretmen ? "Ders Türü Ekle" : "Hizmet Ekle").font(.subheadline.bold()).foregroundStyle(.rvText)
                    TextField(ogretmen ? "Ders adı" : "Hizmet adı", text: $hAd).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    HStack {
                        TextField("Süre (dk)", text: $hSure).keyboardType(.numberPad).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                        TextField("Fiyat ₺", text: $hFiyat).keyboardType(.numberPad).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    }
                    Button { Task { _ = await api.post("services", ["name": hAd, "dur": Int(hSure) ?? 30, "price": Int(hFiyat) ?? 0]); hAd = ""; hSure = ""; hFiyat = ""; await yenile() } } label: {
                        Text("Ekle").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                    }.disabled(hAd.isEmpty || (Int(hFiyat) ?? 0) <= 0)
                }
                ForEach(Array(hizmetler.enumerated()), id: \.offset) { _, h in
                    let id = h["id"] as? Int ?? 0
                    let aktifMi = (h["available"] as? Int ?? 1) == 1
                    panelKart {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(h["name"] as? String ?? "-").font(.subheadline.bold()).foregroundStyle(.rvText)
                                Text("\(h["dur"] as? Int ?? 0) dk · ₺\(h["price"] as? Int ?? 0)").font(.caption2).foregroundStyle(.rvMut)
                            }
                            Spacer()
                            Button { Task { _ = await api.post("services/\(id)/toggle"); await yenile() } } label: {
                                Text(aktifMi ? "Aktif" : "Kapalı").font(.caption.bold()).foregroundStyle(aktifMi ? .green : .orange)
                                    .padding(.horizontal, 12).padding(.vertical, 6).background((aktifMi ? Color.green : Color.orange).opacity(0.15), in: .capsule)
                            }
                            Button { Task { _ = await api.post("services/\(id)/delete"); await yenile() } } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }.padding(.leading, 6)
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    var musteriTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                if musteriler.isEmpty { Text("\(kisiAd) yok").foregroundStyle(.rvMut).padding(.top, 40) }
                ForEach(Array(musteriler.enumerated()), id: \.offset) { _, c in
                    panelKart {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c["cust"] as? String ?? "-").font(.subheadline.bold()).foregroundStyle(.rvText)
                                Text(c["phone"] as? String ?? "").font(.caption2).foregroundStyle(.rvMut)
                            }
                            Spacer()
                            Text("\(c["cnt"] as? Int ?? 0) \(ogretmen ? "ders" : "ziyaret")").font(.caption2).foregroundStyle(.rvMut)
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }
}
