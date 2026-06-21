import SwiftUI

// MARK: - Native Sunucu Kontrol (WebView yok)
struct SunucuNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var ram = ""
    @State private var disk = ""
    @State private var load = ""
    @State private var uptime = ""
    @State private var servisler: [(ad: String, aktif: Bool)] = []
    @State private var yukleniyor = true
    @State private var mesaj = ""
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    LazyVGrid(columns: [GridItem(.flexible(),spacing:12),GridItem(.flexible(),spacing:12)], spacing: 12) {
                        kutu("🧠 RAM", ram); kutu("💾 Disk", disk); kutu("📊 Yük", load); kutu("⏱️ Çalışma", uptime)
                    }
                    Text("Servisler").font(.headline.bold()).foregroundStyle(.rvText).padding(.top, 6)
                    ForEach(servisler, id: \.ad) { s in
                        HStack(spacing: 10) {
                            Circle().fill(s.aktif ? .green : .red).frame(width: 10, height: 10)
                            Text(s.ad).font(.subheadline).foregroundStyle(.rvText)
                            Spacer()
                            Button("Yeniden Başlat") { Task { await restart(s.ad) } }
                                .font(.caption.bold()).foregroundStyle(tema.c1)
                        }
                        .padding(13).glassEffect(.regular, in: .rect(cornerRadius: 14))
                    }
                    if !mesaj.isEmpty { Text(mesaj).font(.caption).foregroundStyle(tema.c2) }
                }.padding(16)
            }
            if yukleniyor { ProgressView().tint(tema.c1).scaleEffect(1.3) }
        }
        .navigationTitle("Sunucu Kontrol").navigationBarTitleDisplayMode(.inline)
        .task { await yukle() }.refreshable { await yukle() }
    }
    func kutu(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(k).font(.caption2).foregroundStyle(.rvMut)
            Text(v.isEmpty ? "—" : v).font(.subheadline.bold()).foregroundStyle(.rvText).lineLimit(2)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
    func yukle() async {
        yukleniyor = true; defer { yukleniyor = false }
        guard let d = await api.durum() else { mesaj = "Bağlanılamadı"; return }
        ram = d["ram"] as? String ?? ""; disk = d["disk"] as? String ?? ""
        load = d["load"] as? String ?? ""; uptime = d["uptime"] as? String ?? ""
        servisler = ((d["servisler"] as? [[String:Any]]) ?? []).map { ($0["ad"] as? String ?? "", $0["aktif"] as? Bool ?? false) }
    }
    func restart(_ svc: String) async {
        mesaj = "\(svc) yeniden başlatılıyor…"
        let ok = await api.servisRestart(svc)
        mesaj = ok ? "✓ \(svc) yeniden başlatıldı" : "⚠️ \(svc) hata"
        await yukle()
    }
}

// MARK: - Native IPTV (WebView yok)
struct IPTVNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var sekme = 0
    @State private var kaynak = ""
    @State private var kanalSayisi = 0
    @State private var hatlar: [[String:Any]] = []
    @State private var kanallar: [[String:Any]] = []
    @State private var yukleniyor = true
    @State private var hata = ""
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            VStack(spacing: 0) {
                Picker("", selection: $sekme) { Text("Hatlar").tag(0); Text("Kanallar (\(kanalSayisi))").tag(1) }
                    .pickerStyle(.segmented).padding(16)
                if !hata.isEmpty {
                    VStack(spacing: 12) { Image(systemName: "tv.slash").font(.system(size: 44)).foregroundStyle(tema.c2); Text(hata).foregroundStyle(.rvMut).multilineTextAlignment(.center) }.padding(30)
                } else {
                    ScrollView {
                        if sekme == 0 { hatGorunum } else { kanalGorunum }
                    }.scrollIndicators(.hidden).refreshable { await yukle() }
                }
            }
            if yukleniyor { ProgressView().tint(tema.c1).scaleEffect(1.3) }
        }
        .navigationTitle("📺 IPTV").navigationBarTitleDisplayMode(.inline)
        .task { await yukle() }
    }
    var hatGorunum: some View {
        VStack(spacing: 10) {
            ForEach(Array(hatlar.enumerated()), id: \.offset) { _, h in
                let mx = (h["max_baglanti"] as? Int) ?? 1, ak = (h["aktif_baglanti"] as? Int) ?? 0
                let durum = h["durum"] as? String ?? "bos"
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Circle().fill(durum=="dolu" ? .red : (durum=="kismi" ? .orange : .green)).frame(width:11,height:11)
                        Text(h["kullanici"] as? String ?? (h["id"] as? String ?? "-")).font(.subheadline.bold()).foregroundStyle(.rvText)
                        Spacer(); Text("\(ak)/\(mx)").font(.caption.bold()).foregroundStyle(.rvMut)
                    }
                    GeometryReader { g in ZStack(alignment:.leading){ Capsule().fill(.white.opacity(0.1)); Capsule().fill(tema.grad).frame(width: g.size.width * min(1, Double(ak)/Double(max(mx,1)))) } }.frame(height:6)
                    HStack(spacing: 8) {
                        kbtn("Boşalt", .green) { Task { _ = await api.iptvHatAksiyon(h["id"] as? String ?? "", "bosalt"); await yukle() } }
                        kbtn("Banla", .red) { Task { _ = await api.iptvHatAksiyon(h["id"] as? String ?? "", "banla"); await yukle() } }
                    }
                }.padding(14).glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        }.padding(16)
    }
    var kanalGorunum: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(kanallar.prefix(300).enumerated()), id: \.offset) { _, k in
                HStack {
                    Text(k["ad"] as? String ?? "-").font(.subheadline).foregroundStyle(.rvText).lineLimit(1)
                    Spacer()
                    let kis = (k["kisitli"] as? Bool) ?? false
                    kbtn(kis ? "Aç" : "Kısıtla", tema.c2) { Task { _ = await api.iptvKanalAksiyon(k["id"] as? String ?? "", kis ? "ac":"kisitla"); await yukle() } }
                }.padding(12).glassEffect(.regular, in: .rect(cornerRadius: 12))
            }
        }.padding(16)
    }
    func kbtn(_ t: String, _ c: Color, _ a: @escaping () -> Void) -> some View {
        Button(t, action: a).font(.caption.bold()).foregroundStyle(c)
            .padding(.horizontal,11).padding(.vertical,6).glassEffect(.regular, in: .capsule)
    }
    func yukle() async {
        yukleniyor = true; defer { yukleniyor = false }
        guard let d = await api.iptvDurum() else { hata = "Bağlanılamadı"; return }
        if let e = d["error"] as? String { hata = (d["mesaj"] as? String) ?? e; return }
        hata = ""
        kaynak = "\(d["kaynak"] ?? "")"; kanalSayisi = d["kanal_sayisi"] as? Int ?? 0
        hatlar = d["hatlar"] as? [[String:Any]] ?? []
        kanallar = await api.iptvKanallar()
    }
}

// MARK: - Native İşletme verisi (sipariş/menü/randevu/özet) — WebView yok
struct IsletmeVeriNative: View {
    let kind: String      // orders / menu / appts / stats
    let baslik: String
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var liste: [[String:Any]] = []
    @State private var yukleniyor = true
    @State private var bos = false
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            if yukleniyor { ProgressView().tint(tema.c1).scaleEffect(1.3) }
            else if bos { VStack(spacing:12){ Image(systemName:"tray").font(.system(size:44)).foregroundStyle(tema.c2); Text("Kayıt yok").foregroundStyle(.rvMut) } }
            else { ScrollView { LazyVStack(spacing: 10) {
                ForEach(Array(liste.enumerated()), id: \.offset) { _, it in satir(it) }
            }.padding(16) }.refreshable { await yukle() } }
        }
        .navigationTitle(baslik).navigationBarTitleDisplayMode(.inline)
        .task { await yukle() }
    }
    func satir(_ it: [String:Any]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(it["name"] as? String ?? it["table_no"] as? String ?? it["client"] as? String ?? "#\(it["id"] ?? "")").font(.subheadline.bold()).foregroundStyle(.rvText)
                Spacer()
                if let t = it["total"] { Text("\(t)₺").font(.subheadline.bold()).foregroundStyle(.green) }
                else if let p = it["price"] { Text("\(p)₺").font(.subheadline.bold()).foregroundStyle(tema.c2) }
            }
            if let items = it["items"] as? [[String:Any]] {
                Text(items.map { "\($0["qty"] ?? 1)× \($0["name"] ?? "")" }.joined(separator: ", ")).font(.caption2).foregroundStyle(.rvMut).lineLimit(2)
            } else if let c = it["category"] as? String { Text(c).font(.caption2).foregroundStyle(.rvMut) }
            if let cr = it["created"] as? String { Text(cr).font(.caption2).foregroundStyle(.rvMut) }
        }.frame(maxWidth:.infinity, alignment:.leading).padding(14).glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
    func yukle() async {
        yukleniyor = true; defer { yukleniyor = false }
        liste = await api.bizVeri(kind); bos = liste.isEmpty
    }
}

// MARK: - Native Admin (14 sekme → JSON API /dash/aapi) — WebView yok
struct AdminNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var sekme = "overview"
    @State private var ozet: [(String,String)] = []
    @State private var liste: [[String:Any]] = []
    @State private var yukleniyor = true
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    let sekmeler: [(String,String)] = [("overview","📊 Genel"),("members","👥 Üye"),("payments","💳 Ödeme"),("ips","🛡️ IP"),("containers","🐳 Container"),("teslimat","📦 Teslimat")]

    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { ForEach(sekmeler, id:\.0){ s in
                        Text(s.1).font(.caption.bold()).padding(.horizontal,13).padding(.vertical,8)
                            .background(sekme==s.0 ? AnyShapeStyle(tema.grad):AnyShapeStyle(.clear), in: .capsule)
                            .foregroundStyle(sekme==s.0 ? .white : .rvMut)
                            .overlay(Capsule().stroke(.white.opacity(sekme==s.0 ?0:0.15)))
                            .onTapGesture { sekme=s.0; Task { await yukle() } }
                    }}.padding(.horizontal,16).padding(.vertical,10)
                }
                if yukleniyor { Spacer(); ProgressView().tint(tema.c1).scaleEffect(1.2); Spacer() }
                else { ScrollView {
                    if sekme=="overview" {
                        LazyVGrid(columns:[GridItem(.flexible(),spacing:12),GridItem(.flexible(),spacing:12)], spacing:12) {
                            ForEach(ozet, id:\.0){ o in VStack(alignment:.leading,spacing:4){ Text(o.1).font(.title3.bold()).foregroundStyle(.rvText); Text(o.0).font(.caption2).foregroundStyle(.rvMut) }.frame(maxWidth:.infinity,alignment:.leading).padding(14).glassEffect(.regular,in:.rect(cornerRadius:14)) }
                        }.padding(16)
                    } else {
                        LazyVStack(spacing:8){ ForEach(Array(liste.prefix(200).enumerated()),id:\.offset){ _,it in
                            Text(_satirMetin(it)).font(.caption).foregroundStyle(.rvText).frame(maxWidth:.infinity,alignment:.leading).padding(12).glassEffect(.regular,in:.rect(cornerRadius:12))
                        }}.padding(16)
                    }
                }.refreshable { await yukle() } }
            }
        }
        .navigationTitle("Admin Panel").navigationBarTitleDisplayMode(.inline)
        .task { await yukle() }
    }
    func _satirMetin(_ it: [String:Any]) -> String {
        let keys = ["name","email","tg_user","ip","plan","ad","tutar","amount","durum","status","when","reason"]
        let parts = keys.compactMap { it[$0].map { v in "\(v)" } }.filter { !$0.isEmpty }
        return parts.isEmpty ? it.map { "\($0.key): \($0.value)" }.prefix(3).joined(separator: " · ") : parts.prefix(4).joined(separator: " · ")
    }
    func yukle() async {
        yukleniyor = true; defer { yukleniyor = false }
        if sekme=="overview" {
            let d = await api.get_overview()
            ozet = [("Aktif üye","\(d["active_members"] ?? "-")"),("Ödeme","\(d["payments_count"] ?? d["payments"] ?? "-")"),("Servis","\(d["services"] ?? "-")"),("RAM",(d["ram"] as? String ?? "-")),("Disk",(d["disk"] as? String ?? "-")),("Uptime",(d["uptime"] as? String ?? "-"))]
        } else {
            liste = await api.adminListe(sekme)
        }
    }
}
extension PanelAPI {
    func get_overview() async -> [String:Any] { (await get("/dash/aapi/overview")) ?? [:] }
    func adminListe(_ p: String) async -> [[String:Any]] { await getArr("/dash/aapi/\(p)") }
}

// MARK: - Native Güvenlik (koruma/ziyaretçi/ban) — WebView yok
struct GuvenlikNative: View {
    let tip: String   // koruma / ziyaretci / ban
    let baslik: String
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var d: [String:Any] = [:]
    @State private var yukleniyor = true
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            if yukleniyor { ProgressView().tint(tema.c1).scaleEffect(1.3) }
            else { ScrollView { VStack(alignment:.leading, spacing: 12) { icerik }.padding(16) }.refreshable { await yukle() } }
        }
        .navigationTitle(baslik).navigationBarTitleDisplayMode(.inline)
        .task { await yukle() }
    }
    @ViewBuilder var icerik: some View {
        if tip == "koruma" {
            Text("🛡️ Koruma AKTİF").font(.title3.bold()).foregroundStyle(.green)
            ForEach((d["servisler"] as? [[String:Any]]) ?? [], id: \.self.description) { s in
                HStack { Circle().fill((s["aktif"] as? Bool ?? false) ? .green : .red).frame(width:10,height:10)
                    Text(s["ad"] as? String ?? "").foregroundStyle(.rvText); Spacer() }
                .padding(12).glassEffect(.regular, in: .rect(cornerRadius: 12))
            }
            Text("Engellenen IP: \(d["ban"] as? Int ?? 0) · Firewall DROP: \(d["firewall_drop"] as? Int ?? 0)").font(.caption).foregroundStyle(.rvMut)
        } else if tip == "ban" {
            Text("\(d["toplam"] as? Int ?? 0)").font(.system(size:44,weight:.bold)).foregroundStyle(tema.c1)
            Text("toplam engellenen IP").font(.caption).foregroundStyle(.rvMut)
            Text(d["kararlar"] as? String ?? "—").font(.system(size:11,design:.monospaced)).foregroundStyle(.rvMut)
                .frame(maxWidth:.infinity,alignment:.leading).padding(12).glassEffect(.regular,in:.rect(cornerRadius:12))
        } else {
            ForEach(Array(((d["kayitlar"] as? [[String:Any]]) ?? []).enumerated()), id:\.offset) { _, r in
                VStack(alignment:.leading,spacing:3){
                    HStack{ Text(r["ip"] as? String ?? "").font(.caption.bold()).foregroundStyle(.rvText); Spacer(); Text(r["durum"] as? String ?? "").font(.caption2).foregroundStyle(.rvMut) }
                    Text(r["istek"] as? String ?? "").font(.caption2).foregroundStyle(.rvMut).lineLimit(1)
                }.padding(11).glassEffect(.regular,in:.rect(cornerRadius:11))
            }
        }
    }
    func yukle() async { yukleniyor = true; defer { yukleniyor = false }; d = await api.guvenlik(tip) ?? [:] }
}

// MARK: - Native İşletme Ekle (süper onboarding) — WebView yok
struct IsletmeEkleNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var ad = "", kod = "", tel = "", sifre = "", slug = ""
    @State private var sluglar: [String] = []
    @State private var sonuc = ""
    @State private var basari = false
    @State private var bekle = false
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            ScrollView { VStack(spacing: 12) {
                Text("Yeni işletme oluştur — kod/şifre üret, müşteriye ver.").font(.subheadline).foregroundStyle(.rvMut).frame(maxWidth:.infinity,alignment:.leading)
                alan("İşletme adı", $ad); alan("Giriş kodu", $kod)
                alan("Telefon (+90… opsiyonel)", $tel); alan("Şifre (boş=otomatik)", $sifre)
                if !sluglar.isEmpty {
                    Picker("Sektör paneli (opsiyonel)", selection: $slug) {
                        Text("— bağlama —").tag(""); ForEach(sluglar, id:\.self){ Text($0).tag($0) }
                    }.pickerStyle(.menu).tint(tema.c1).frame(maxWidth:.infinity,alignment:.leading)
                     .padding(12).glassEffect(.regular,in:.rect(cornerRadius:14))
                }
                Button { Task { await ekle() } } label: {
                    HStack{ if bekle { ProgressView().tint(.white) }; Text("İşletme Oluştur").bold() }
                        .foregroundStyle(.white).frame(maxWidth:.infinity).padding(.vertical,15).background(tema.grad,in:.rect(cornerRadius:14))
                }.disabled(bekle || ad.isEmpty || kod.isEmpty)
                if !sonuc.isEmpty { Text(sonuc).font(.callout).foregroundStyle(basari ? .green : .orange).frame(maxWidth:.infinity,alignment:.leading).padding(12).glassEffect(.regular,in:.rect(cornerRadius:12)) }
            }.padding(16) }
        }
        .navigationTitle("➕ İşletme Ekle").navigationBarTitleDisplayMode(.inline)
        .task { sluglar = await api.slugListesi() }
    }
    func alan(_ ip: String, _ b: Binding<String>) -> some View {
        TextField(ip, text: b).autocorrectionDisabled().textInputAutocapitalization(.never)
            .foregroundStyle(.rvText).padding(14).glassEffect(.regular,in:.rect(cornerRadius:14))
    }
    func ekle() async {
        bekle = true; defer { bekle = false }; sonuc = ""
        let r = await api.isletmeEkle(ad:ad,kod:kod,tel:tel,sifre:sifre,slug:slug)
        if r?["ok"] as? Bool == true {
            basari = true; sonuc = "✓ Oluşturuldu\nKod: \(r?["kod"] ?? "")\nŞifre: \(r?["sifre"] ?? "")" + (slug.isEmpty ? "" : "\nPanel: \(slug)")
            ad=""; kod=""; tel=""; sifre=""; slug=""
        } else { basari = false; sonuc = "⚠️ " + ((r?["mesaj"] as? String) ?? "Hata") }
    }
}
