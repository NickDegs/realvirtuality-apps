import SwiftUI

// MARK: - Restoran/Kafe/Otel paneli (resto-sistem) — sipariş/menü/masa
struct RestoranPanel: View {
    @ObservedObject var api: PanelAPI
    @EnvironmentObject var tema: Tema
    @State private var sekme = 0

    @State private var gelir = 0
    @State private var adet = 0
    @State private var aktif = 0
    @State private var siparisler: [[String: Any]] = []
    @State private var menu: [[String: Any]] = []
    @State private var masalar: [[String: Any]] = []
    @State private var yeniMasa = ""
    @State private var mAd = ""
    @State private var mKat = ""
    @State private var mFiyat = ""

    static let durumAd = ["🆕 Yeni", "👨‍🍳 Hazırlanıyor", "✅ Hazır", "📦 Teslim edildi"]
    static let durumRenk: [Color] = [.blue, .orange, .green, .gray]
    let sekmeler = [("Özet", "chart.bar.fill"), ("Siparişler", "bag.fill"), ("Masalar", "tablecells"),
                    ("Menü", "fork.knife"), ("Personel", "person.2.fill"), ("Ayar", "gearshape.fill")]

    var body: some View {
        VStack(spacing: 0) {
            PanelChips(sekmeler: sekmeler, secili: $sekme, tema: tema)
            switch sekme {
            case 0: ozet
            case 1: siparisTab
            case 2: masaTab
            case 3: menuTab
            case 4: PersonelSekmesi(api: api, tema: tema)
            default: AyarSekmesi(api: api, tema: tema)
            }
        }
        .task { await yenile(); while !Task.isCancelled { try? await Task.sleep(nanoseconds: 25_000_000_000); await yenile() } }
    }

    func yenile() async {
        let s = await api.getObj("stats")
        gelir = s["revenue"] as? Int ?? 0; adet = s["count"] as? Int ?? 0; aktif = s["active"] as? Int ?? 0
        siparisler = await api.getArr("orders")
        menu = await api.getArr("menu")
        masalar = await api.getArr("tables")
    }

    var ozet: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    panelKpi("Bugün Ciro", "₺\(gelir)", "turkishlirasign.circle.fill", .green)
                    panelKpi("Bugün Sipariş", "\(adet)", "bag.fill", .blue)
                }
                panelKpi("Aktif Sipariş", "\(aktif)", "flame.fill", .orange)
                RaporKart(api: api, tema: tema)
            }.padding()
        }.refreshable { await yenile() }
    }

    var siparisTab: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if siparisler.isEmpty { Text("Henüz sipariş yok").foregroundStyle(.rvMut).padding(.top, 40) }
                ForEach(Array(siparisler.enumerated()), id: \.offset) { _, s in
                    let id = s["id"] as? Int ?? 0
                    let durum = s["status"] as? Int ?? 0
                    let masa = s["table_no"] as? String ?? ""
                    panelKart {
                        HStack {
                            Text("#\(id)").font(.headline).foregroundStyle(.rvText)
                            if !masa.isEmpty && masa != "-" {
                                Text("Masa \(masa)").font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.rvLine, in: .capsule).foregroundStyle(.rvMut)
                            }
                            Spacer()
                            Text("₺\(s["total"] as? Int ?? 0)").font(.headline).foregroundStyle(tema.c1)
                        }
                        HStack {
                            Text(Self.durumAd[min(3, max(0, durum))]).font(.caption.bold())
                                .foregroundStyle(Self.durumRenk[min(3, max(0, durum))])
                            Spacer()
                            Text("\((s["items"] as? [Any])?.count ?? 0) ürün").font(.caption2).foregroundStyle(.rvMut)
                        }
                        if let n = s["note"] as? String, !n.isEmpty { Text("📝 \(n)").font(.caption2).foregroundStyle(.rvMut) }
                        if durum < 3 {
                            Button { Task { _ = await api.post("order/\(id)/advance"); await yenile() } } label: {
                                Text("Sonraki aşamaya geçir →").font(.caption.bold()).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                            }
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    var masaTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text("Masa Ekle").font(.subheadline.bold()).foregroundStyle(.rvText)
                    HStack {
                        TextField("Masa adı (ör. Masa 5)", text: $yeniMasa).padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                        Button { Task { _ = await api.post("tables", ["name": yeniMasa]); yeniMasa = ""; await yenile() } } label: {
                            Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(tema.c1)
                        }.disabled(yeniMasa.isEmpty)
                    }
                }
                ForEach(Array(masalar.enumerated()), id: \.offset) { _, m in
                    let id = m["id"] as? Int ?? 0
                    panelKart {
                        HStack {
                            Text(m["name"] as? String ?? "-").font(.subheadline.bold()).foregroundStyle(.rvText)
                            Spacer()
                            Button { Task { _ = await api.post("tables/\(id)/delete"); await yenile() } } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    var menuTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text("Ürün Ekle").font(.subheadline.bold()).foregroundStyle(.rvText)
                    TextField("Ürün adı", text: $mAd).padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                    HStack {
                        TextField("Kategori", text: $mKat).padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                        TextField("Fiyat ₺", text: $mFiyat).keyboardType(.numberPad).padding(10).background(Color.rvBg, in: .rect(cornerRadius: 10))
                    }
                    Button { Task { _ = await api.post("menu", ["name": mAd, "category": mKat.isEmpty ? "Diğer" : mKat, "price": Int(mFiyat) ?? 0]); mAd = ""; mKat = ""; mFiyat = ""; await yenile() } } label: {
                        Text("Menüye Ekle").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                    }.disabled(mAd.isEmpty || (Int(mFiyat) ?? 0) <= 0)
                }
                ForEach(Array(menu.enumerated()), id: \.offset) { _, m in
                    let id = m["id"] as? Int ?? 0
                    let aktifMi = (m["available"] as? Int ?? 1) == 1
                    panelKart {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m["name"] as? String ?? "-").font(.subheadline.bold()).foregroundStyle(.rvText)
                                Text("\(m["category"] as? String ?? "") · ₺\(m["price"] as? Int ?? 0)").font(.caption2).foregroundStyle(.rvMut)
                            }
                            Spacer()
                            Button { Task { _ = await api.post("menu/\(id)/toggle"); await yenile() } } label: {
                                Text(aktifMi ? "Satışta" : "Tükendi").font(.caption.bold()).foregroundStyle(aktifMi ? .green : .orange)
                                    .padding(.horizontal, 12).padding(.vertical, 6).background((aktifMi ? Color.green : Color.orange).opacity(0.15), in: .capsule)
                            }
                            Button { Task { _ = await api.post("menu/\(id)/delete"); await yenile() } } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }.padding(.leading, 6)
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }
}
