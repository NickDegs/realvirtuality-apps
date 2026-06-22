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
    @State private var filmSayisi = 0
    @State private var diziSayisi = 0
    @State private var hatlar: [[String:Any]] = []
    @State private var kanallar: [[String:Any]] = []
    @State private var kullanicilar: [[String:Any]] = []
    @State private var davetler: [[String:Any]] = []
    @State private var yukleniyor = true
    @State private var hata = ""
    // davet oluşturma
    @State private var davetAcik = false
    @State private var dName = ""
    @State private var dGun = 30
    @State private var dProvider = "tvtork"
    @State private var dVod = true
    @State private var dKilit = true
    @State private var sonDavet: [String:Any]? = nil
    @State private var davetGonderiliyor = false
    // kaynak güncelle
    @State private var kaynakAcik = false
    @State private var kaynakMetin = ""
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            VStack(spacing: 0) {
                Picker("", selection: $sekme) {
                    Text("Hatlar").tag(0); Text("Kanallar").tag(1)
                    Text("Erişim (\(kullanicilar.count))").tag(2); Text("Davet (\(davetler.count))").tag(3)
                }.pickerStyle(.segmented).padding(16)
                if !hata.isEmpty {
                    VStack(spacing: 12) { Image(systemName: "tv.slash").font(.system(size: 44)).foregroundStyle(tema.c2); Text(hata).foregroundStyle(.rvMut).multilineTextAlignment(.center) }.padding(30)
                } else {
                    ScrollView {
                        switch sekme {
                        case 0: hatGorunum
                        case 1: kanalGorunum
                        case 2: erisimGorunum
                        default: davetGorunum
                        }
                    }.scrollIndicators(.hidden).refreshable { await yukle() }
                }
            }
            if yukleniyor { ProgressView().tint(tema.c1).scaleEffect(1.3) }
        }
        .navigationTitle("📺 IPTV").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { kaynakAcik = true } label: { Image(systemName: "link.badge.plus") } } }
        .sheet(isPresented: $davetAcik) { davetSheet }
        .sheet(isPresented: $kaynakAcik) { kaynakSheet }
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
    // Erişimi olanlar (salt-okunur)
    var erisimGorunum: some View {
        VStack(spacing: 9) {
            if kullanicilar.isEmpty { Text("Erişimi olan kullanıcı yok").foregroundStyle(.rvMut).padding(.top, 30) }
            ForEach(Array(kullanicilar.enumerated()), id: \.offset) { _, u in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Circle().fill((u["durum"] as? String == "aktif") ? .green : .orange).frame(width:10,height:10)
                        Text(u["isim"] as? String ?? (u["kullanici"] as? String ?? "-")).font(.subheadline.bold()).foregroundStyle(.rvText)
                        Spacer()
                        if (u["cihaz_kilidi"] as? Bool) ?? false { Image(systemName: "lock.fill").font(.caption2).foregroundStyle(tema.c2) }
                    }
                    Text("\(u["saglayici"] as? String ?? "-") · kanal: \(u["kanal_kapsami"] as? String ?? "-") · VOD: \(u["vod"] as? String ?? "-")").font(.caption).foregroundStyle(.rvMut)
                    Text("kullanıcı: \(u["kullanici"] as? String ?? "-") · bitiş: \(u["bitis"] as? String ?? "-")").font(.caption2).foregroundStyle(.rvMut)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(13).glassEffect(.regular, in: .rect(cornerRadius: 14))
            }
        }.padding(16)
    }
    // Davetler + native davet oluştur/iptal/uzat
    var davetGorunum: some View {
        VStack(spacing: 10) {
            Button { sonDavet = nil; davetAcik = true } label: {
                HStack { Image(systemName: "plus.circle.fill"); Text("Yeni Davet Oluştur").bold() }
                    .frame(maxWidth: .infinity).padding(13).foregroundStyle(.white).background(tema.grad, in: .rect(cornerRadius: 14))
            }
            if davetler.isEmpty { Text("Henüz davet yok").foregroundStyle(.rvMut).padding(.top, 16) }
            ForEach(Array(davetler.enumerated()), id: \.offset) { _, d in
                let user = (d["username"] as? String) ?? (d["kullanici"] as? String) ?? ""
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(d["name"] as? String ?? user).font(.subheadline.bold()).foregroundStyle(.rvText)
                        Spacer(); Text(d["status"] as? String ?? "").font(.caption2.bold()).foregroundStyle(.rvMut)
                    }
                    Text("bitiş: \(d["expires"] as? String ?? "-") · kanal: \(intStr(d["channels"]))").font(.caption2).foregroundStyle(.rvMut)
                    if let l = d["invite_link"] as? String { Text(l).font(.caption2).foregroundStyle(tema.c1).lineLimit(1).textSelection(.enabled) }
                    HStack(spacing: 8) {
                        kbtn("+30 gün", .green) { Task { _ = await api.iptvDavetUzat(user, 30); await yukle() } }
                        kbtn("İptal", .red) { Task { _ = await api.iptvDavetIptal(user); await yukle() } }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(13).glassEffect(.regular, in: .rect(cornerRadius: 14))
            }
        }.padding(16)
    }
    func intStr(_ v: Any?) -> String { if let i = v as? Int { return "\(i)" }; return "\(v ?? "-")" }
    // davet oluşturma sheet
    var davetSheet: some View {
        NavigationStack {
            ZStack {
                AnimatedArka(c1: tema.c1, c2: tema.c2)
                ScrollView {
                    VStack(spacing: 14) {
                        if let s = sonDavet {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("✅ Davet oluşturuldu").font(.headline).foregroundStyle(.rvText)
                                Text("Kullanıcı: \(s["username"] as? String ?? "-")").foregroundStyle(.rvText).textSelection(.enabled)
                                Text("Şifre: \(s["password"] as? String ?? "-")").foregroundStyle(.rvText).textSelection(.enabled)
                                Text("Link: \(s["link"] as? String ?? "-")").font(.caption).foregroundStyle(tema.c1).textSelection(.enabled)
                                Text("Bitiş: \(s["expires"] as? String ?? "-") · kanal: \(intStr(s["channels"]))").font(.caption).foregroundStyle(.rvMut)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(14).glassEffect(.regular, in: .rect(cornerRadius: 16))
                        } else {
                            alan("İsim", $dName)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Sağlayıcı").font(.caption).foregroundStyle(.rvMut)
                                Picker("", selection: $dProvider) { Text("tvtork").tag("tvtork"); Text("Otomatik").tag("") }.pickerStyle(.segmented)
                            }
                            Stepper("Süre: \(dGun) gün", value: $dGun, in: 1...3650, step: 30)
                                .foregroundStyle(.rvText).padding(12).glassEffect(.regular, in: .rect(cornerRadius: 12))
                            Toggle("Tüm film + dizi (VOD)", isOn: $dVod).foregroundStyle(.rvText).padding(12).glassEffect(.regular, in: .rect(cornerRadius: 12))
                            Toggle("Cihaz kilidi", isOn: $dKilit).foregroundStyle(.rvText).padding(12).glassEffect(.regular, in: .rect(cornerRadius: 12))
                            Button { Task { await davetOlustur() } } label: {
                                HStack { if davetGonderiliyor { ProgressView().tint(.white) }; Text(davetGonderiliyor ? "Oluşturuluyor…" : "Oluştur").bold() }
                                    .frame(maxWidth: .infinity).padding(14).foregroundStyle(.white).background(tema.grad, in: .rect(cornerRadius: 14))
                            }.disabled(dName.isEmpty || davetGonderiliyor)
                        }
                    }.padding(18)
                }
            }
            .navigationTitle("Yeni Davet").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { davetAcik = false } } }
        }
    }
    func alan(_ p: String, _ b: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p).font(.caption).foregroundStyle(.rvMut)
            TextField(p, text: b).foregroundStyle(.rvText).autocorrectionDisabled().padding(12).glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
    }
    func davetOlustur() async {
        davetGonderiliyor = true; defer { davetGonderiliyor = false }
        let body: [String:Any] = ["name": dName, "contact": "", "channel": "none", "days": dGun,
                                  "provider": dProvider, "vod": dVod ? 1 : 0, "lock_device": dKilit ? 1 : 0]
        if let r = await api.iptvDavet(body), (r["ok"] as? Bool) ?? false { sonDavet = r; await yukle() }
    }
    // kaynak güncelle sheet
    var kaynakSheet: some View {
        NavigationStack {
            ZStack {
                AnimatedArka(c1: tema.c1, c2: tema.c2)
                VStack(spacing: 14) {
                    Text("Kaynak adreslerini gir (her satır bir adres). Domain ölünce media bununla günceller.").font(.caption).foregroundStyle(.rvMut)
                    TextEditor(text: $kaynakMetin).frame(height: 140).scrollContentBackground(.hidden).foregroundStyle(.rvText).padding(8).glassEffect(.regular, in: .rect(cornerRadius: 12))
                    Button { Task {
                        let adr = kaynakMetin.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        if !adr.isEmpty { _ = await api.iptvKaynakGuncelle(adr); kaynakAcik = false; await yukle() }
                    } } label: { Text("Güncelle").bold().frame(maxWidth: .infinity).padding(14).foregroundStyle(.white).background(tema.grad, in: .rect(cornerRadius: 14)) }
                    Spacer()
                }.padding(18)
            }
            .navigationTitle("🔗 Kaynak Güncelle").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { kaynakAcik = false } } }
        }
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
        filmSayisi = d["film_sayisi"] as? Int ?? 0; diziSayisi = d["dizi_sayisi"] as? Int ?? 0
        hatlar = d["hatlar"] as? [[String:Any]] ?? []
        kanallar = await api.iptvKanallar()
        kullanicilar = await api.iptvKullanicilar()
        davetler = await api.iptvDavetler()
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
    @State private var ad = ""
    @State private var kod = ""
    @State private var tel = ""
    @State private var sifre = ""
    @State private var slug = ""
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

// MARK: - Native Personel (işletme → çalışan ekle/yönet) — WebView yok
struct PersonelNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var liste: [[String:Any]] = []
    @State private var ad = ""
    @State private var kod = ""
    @State private var tel = ""
    @State private var sonuc = ""
    @State private var basari = false
    @State private var bekle = false
    @State private var yukleniyor = true
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            ScrollView { VStack(alignment: .leading, spacing: 14) {
                Text("Çalışan ekle — sınırlı panele (sipariş/randevu al) girer. Yönetim sende kalır.").font(.subheadline).foregroundStyle(.rvMut)
                alan("Çalışan adı", $ad); alan("Giriş kodu (örn: ahmet)", $kod); alan("Telefon (opsiyonel)", $tel)
                Button { Task { await ekle() } } label: {
                    HStack { if bekle { ProgressView().tint(.white) }; Text("Çalışan Ekle").bold() }
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14).background(tema.grad, in: .rect(cornerRadius: 14))
                }.disabled(bekle || ad.isEmpty || kod.isEmpty)
                if !sonuc.isEmpty { Text(sonuc).font(.callout).foregroundStyle(basari ? .green : .orange).padding(12).frame(maxWidth:.infinity,alignment:.leading).glassEffect(.regular,in:.rect(cornerRadius:12)) }
                if !liste.isEmpty {
                    Text("Çalışanlar (\(liste.count))").font(.headline.bold()).foregroundStyle(.rvText).padding(.top, 8)
                    ForEach(Array(liste.enumerated()), id: \.offset) { _, p in
                        HStack {
                            VStack(alignment:.leading,spacing:2){ Text(p["ad"] as? String ?? "").foregroundStyle(.rvText); Text(p["kod"] as? String ?? "").font(.caption2).foregroundStyle(.rvMut) }
                            Spacer()
                            Button(role:.destructive){ Task { await api.personelSil(p["kod"] as? String ?? ""); await yukle() } } label: { Image(systemName:"trash").foregroundStyle(.red) }
                        }.padding(13).glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }
                }
            }.padding(16) }
            if yukleniyor { ProgressView().tint(tema.c1).scaleEffect(1.2) }
        }
        .navigationTitle("👥 Personel").navigationBarTitleDisplayMode(.inline)
        .task { await yukle() }
    }
    func alan(_ ip: String, _ b: Binding<String>) -> some View {
        TextField(ip, text: b).autocorrectionDisabled().textInputAutocapitalization(.never)
            .foregroundStyle(.rvText).padding(13).glassEffect(.regular, in: .rect(cornerRadius: 13))
    }
    func yukle() async { yukleniyor = true; defer { yukleniyor = false }; liste = await api.personelListe() }
    func ekle() async {
        bekle = true; defer { bekle = false }; sonuc = ""
        let r = await api.personelEkle(ad: ad, kod: kod, tel: tel, sifre: "")
        if r?["ok"] as? Bool == true {
            basari = true; sonuc = "✓ Eklendi — Kod: \(r?["kod"] ?? "") · Şifre: \(r?["sifre"] ?? "")"
            ad=""; kod=""; tel=""; await yukle()
        } else { basari = false; sonuc = "⚠️ " + ((r?["mesaj"] as? String) ?? "Hata") }
    }
}

// MARK: - Native CANLI ÖZET (KPI dashboard) — gelir/üye/servis/güvenlik/medya tek ekran
struct OzetNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var ov: [String:Any] = [:]
    @State private var guv: [String:Any] = [:]
    @State private var iptv: [String:Any] = [:]
    @State private var yukleniyor = true
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var izgara: [GridItem] { [GridItem(.flexible(),spacing:12),GridItem(.flexible(),spacing:12)] }
    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            if yukleniyor { ProgressView().tint(tema.c1).scaleEffect(1.3) }
            else { ScrollView { VStack(alignment:.leading,spacing:14) {
                bolum("💰 Satış & Üye")
                LazyVGrid(columns:izgara,spacing:12){
                    kpi("Aktif üye","\(ov["active_members"] ?? "-")","person.fill.checkmark",.green)
                    kpi("Toplam üye","\(ov["total_members"] ?? "-")","person.3.fill",tema.c1)
                    kpi("Ödeme","\(ov["total_payments"] ?? "-")","creditcard.fill",.blue)
                    kpi("Servis","\(ov["services"] ?? "-")","square.stack.3d.up.fill",.purple)
                }
                bolum("🛡 Güvenlik")
                LazyVGrid(columns:izgara,spacing:12){
                    kpi("Engellenen IP","\(guv["ban"] ?? 0)","hand.raised.fill",.red)
                    kpi("Firewall DROP","\(guv["firewall_drop"] ?? 0)","shield.lefthalf.filled",.orange)
                }
                bolum("🖥 Sunucu (Ana)")
                LazyVGrid(columns:izgara,spacing:12){
                    kpi("RAM","\(ov["ram"] ?? "-")","memorychip.fill",tema.c2)
                    kpi("Disk","\(ov["disk"] ?? "-")","internaldrive.fill",tema.c1)
                    kpi("Yük","\(ov["load"] ?? "-")","gauge.medium",.yellow)
                    kpi("Container","\(ov["containers"] ?? "-")","shippingbox.fill",.cyan)
                }
                bolum("🖥 Sunucu (ND2 / Medya)")
                LazyVGrid(columns:izgara,spacing:12){
                    kpi("RAM","\(ov["nd2_ram"] ?? "-")","memorychip",.teal)
                    kpi("Yük","\(ov["nd2_load"] ?? "-")","gauge.medium",.yellow)
                    kpi("Container","\(ov["nd2_containers"] ?? "-")","shippingbox",.cyan)
                }
                bolum("🎬 Medya / IPTV")
                LazyVGrid(columns:izgara,spacing:12){
                    kpi("IPTV hat","\(iptv["hatlar"] ?? iptv["lines"] ?? "-")","tv.fill",.pink)
                    kpi("Kanal","\(iptv["kanallar"] ?? iptv["channels"] ?? "-")","play.tv.fill",.indigo)
                }
                Text("⏱ Uptime: \(ov["uptime"] as? String ?? "-")").font(.caption2).foregroundStyle(.rvMut).padding(.top,4)
            }.padding(16) }.refreshable { await yukle() } }
        }
        .navigationTitle("📊 Canlı Özet").navigationBarTitleDisplayMode(.inline)
        .task { await yukle() }
    }
    func bolum(_ t:String)->some View { Text(t).font(.headline.bold()).foregroundStyle(.rvText).padding(.top,4) }
    func kpi(_ ad:String,_ d:String,_ ic:String,_ c:Color)->some View {
        VStack(alignment:.leading,spacing:6){
            Image(systemName:ic).foregroundStyle(c).font(.title3)
            Text(d).font(.title3.bold()).foregroundStyle(.rvText).lineLimit(1).minimumScaleFactor(0.6)
            Text(ad).font(.caption2).foregroundStyle(.rvMut)
        }.frame(maxWidth:.infinity,alignment:.leading).padding(14).glassEffect(.regular,in:.rect(cornerRadius:16))
    }
    func yukle() async {
        yukleniyor = true; defer { yukleniyor = false }
        async let a = api.get_overview()
        async let b = api.guvenlik("koruma")
        async let c = api.iptvDurum()
        ov = await a; guv = (await b) ?? [:]; iptv = (await c) ?? [:]
    }
}

// MARK: - Native Medya (Emby+Plex film/dizi/canlı + indirme/istek/sistem) — WebView yok
struct MedyaNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var sekme = "embyfilm"
    @State private var embyOzet: [String:Any] = [:]
    @State private var plexOzet: [String:Any] = [:]
    @State private var plexKut: [[String:Any]] = []
    @State private var seciliPlex = ""
    @State private var icerik: [[String:Any]] = []
    @State private var indir: [[String:Any]] = []
    @State private var istek: [[String:Any]] = []
    @State private var sistem: [String:Any] = [:]
    @State private var ara = ""
    @State private var yukleniyor = true
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    let sekmeler: [(String,String)] = [("embyfilm","🎬 Film"),("embydizi","📺 Dizi"),("canli","📡 Canlı"),("plex","🟠 Plex"),("indir","⬇️ İndirme"),("istek","📨 İstek"),("sistem","🖥️ Sistem")]
    var izgara: [GridItem] { [GridItem(.adaptive(minimum: 100), spacing: 10)] }

    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { ForEach(sekmeler, id:\.0){ s in
                        Text(s.1).font(.caption.bold()).padding(.horizontal,13).padding(.vertical,8)
                            .background(sekme==s.0 ? AnyShapeStyle(tema.grad):AnyShapeStyle(.clear), in:.capsule)
                            .foregroundStyle(sekme==s.0 ? .white : .rvMut)
                            .overlay(Capsule().stroke(.white.opacity(sekme==s.0 ?0:0.15)))
                            .onTapGesture { sekme=s.0; ara=""; Task { await yukle() } }
                    }}.padding(.horizontal,16).padding(.vertical,10)
                }
                ozetSerit
                if ["embyfilm","embydizi","canli","plex"].contains(sekme) {
                    TextField("Ara…", text: $ara).foregroundStyle(.rvText).padding(10).glassEffect(.regular,in:.rect(cornerRadius:12))
                        .padding(.horizontal,16).submitLabel(.search).onSubmit { Task { await yukle() } }
                    if sekme=="plex" && !plexKut.isEmpty {
                        ScrollView(.horizontal,showsIndicators:false){ HStack(spacing:7){ ForEach(Array(plexKut.enumerated()),id:\.offset){_,k in
                            let key = String(describing: k["kutuphane"] ?? "")
                            Text(k["ad"] as? String ?? "").font(.caption2).padding(.horizontal,10).padding(.vertical,6)
                                .background(seciliPlex==key ? AnyShapeStyle(tema.c1):AnyShapeStyle(.clear),in:.capsule)
                                .foregroundStyle(seciliPlex==key ? .white : .rvMut).overlay(Capsule().stroke(.white.opacity(0.15)))
                                .onTapGesture { seciliPlex=key; Task { await yukle() } }
                        }}.padding(.horizontal,16).padding(.top,6) }
                    }
                }
                if yukleniyor { Spacer(); ProgressView().tint(tema.c1).scaleEffect(1.2); Spacer() }
                else { icerikGor }
            }
        }
        .navigationTitle("🎬 Medya").navigationBarTitleDisplayMode(.inline)
        .task { await ilkYukle() }
    }

    @ViewBuilder var ozetSerit: some View {
        if sekme != "sistem" {
            ScrollView(.horizontal,showsIndicators:false){ HStack(spacing:8){
                kart("Emby film","\(embyOzet["toplam_film"] ?? "-")"); kart("Emby dizi","\(embyOzet["toplam_dizi"] ?? "-")")
                kart("Plex film","\(plexOzet["toplam_film"] ?? "-")"); kart("Plex dizi","\(plexOzet["toplam_dizi"] ?? "-")")
            }.padding(.horizontal,16).padding(.top,4) }
        }
    }
    @ViewBuilder var icerikGor: some View {
        ScrollView {
            if sekme=="indir" {
                VStack(spacing:8){ ForEach(Array(indir.enumerated()),id:\.offset){_,d in
                    VStack(alignment:.leading,spacing:4){
                        HStack{ Text(d["baslik"] as? String ?? "").foregroundStyle(.rvText).lineLimit(1); Spacer(); Text(d["kaynak"] as? String ?? "").font(.caption2).foregroundStyle(.rvMut) }
                        HStack{ ProgressView(value: min(1,( (d["yuzde"] as? Double) ?? Double(d["yuzde"] as? Int ?? 0))/100)).tint(tema.c1)
                            Text("\(d["yuzde"] ?? 0)%").font(.caption2).foregroundStyle(.rvMut) }
                        Text("\(d["durum"] as? String ?? "") \(d["kalan"] as? String ?? "")").font(.caption2).foregroundStyle(.rvMut)
                    }.padding(11).glassEffect(.regular,in:.rect(cornerRadius:12))
                }; if indir.isEmpty { bos("Aktif indirme yok") } }.padding(16)
            } else if sekme=="istek" {
                VStack(spacing:8){ ForEach(Array(istek.enumerated()),id:\.offset){_,r in
                    HStack{ VStack(alignment:.leading,spacing:2){ Text(r["baslik"] as? String ?? r["tmdb"].map{"\($0)"} ?? "İstek #\(r["id"] ?? "")").foregroundStyle(.rvText).lineLimit(1)
                        Text("\(r["tip"] as? String ?? "") · \(r["isteyen"] as? String ?? "")").font(.caption2).foregroundStyle(.rvMut) }
                        Spacer(); Text(r["durum"] as? String ?? "").font(.caption2.bold()).foregroundStyle(tema.c1) }
                    .padding(11).glassEffect(.regular,in:.rect(cornerRadius:12))
                }; if istek.isEmpty { bos("İstek yok") } }.padding(16)
            } else if sekme=="sistem" {
                VStack(spacing:10){
                    HStack(spacing:8){ kart("Container","\(sistem["container_calisan"] ?? "-")/\(sistem["container_toplam"] ?? "-")"); kart("Disk","\(sistem["disk_kullanim"] ?? "-")") }
                    ForEach(Array(((sistem["containerlar"] as? [[String:Any]]) ?? []).enumerated()),id:\.offset){_,c in
                        HStack{ Circle().fill((c["durum"] as? String ?? "").contains("running") || (c["calisan"] as? Bool ?? false) ? .green : .red).frame(width:9,height:9)
                            Text(c["ad"] as? String ?? c["name"] as? String ?? "").font(.caption).foregroundStyle(.rvText).lineLimit(1); Spacer()
                            Text(c["durum"] as? String ?? "").font(.caption2).foregroundStyle(.rvMut) }
                        .padding(10).glassEffect(.regular,in:.rect(cornerRadius:11))
                    }
                }.padding(16)
            } else {
                LazyVGrid(columns: izgara, spacing: 10){ ForEach(Array(icerik.enumerated()),id:\.offset){_,it in
                    VStack(alignment:.leading,spacing:4){
                        ZStack{ RoundedRectangle(cornerRadius:8).fill(.white.opacity(0.06))
                            if let u = posterURL(it) { AsyncImage(url:u){ img in img.resizable().scaledToFill() } placeholder: { ProgressView().tint(tema.c1) } }
                            else { Image(systemName:"film").foregroundStyle(.rvMut) }
                        }.frame(height:150).clipShape(.rect(cornerRadius:8))
                        Text(it["ad"] as? String ?? "").font(.caption2).foregroundStyle(.rvText).lineLimit(1)
                        Text("\(it["yil"] ?? "")").font(.system(size:9)).foregroundStyle(.rvMut)
                    }
                }; }.padding(16)
                if icerik.isEmpty { bos("İçerik yok") }
            }
        }.refreshable { await yukle() }
    }
    func kart(_ t:String,_ v:String)->some View { VStack(spacing:2){ Text(v).font(.subheadline.bold()).foregroundStyle(.rvText); Text(t).font(.system(size:9)).foregroundStyle(.rvMut) }.padding(.horizontal,12).padding(.vertical,8).glassEffect(.regular,in:.rect(cornerRadius:11)) }
    func bos(_ t:String)->some View { Text(t).font(.caption).foregroundStyle(.rvMut).frame(maxWidth:.infinity).padding(.top,30) }

    func posterURL(_ it:[String:Any]) -> URL? {
        guard var p = (it["poster"] as? String), !p.isEmpty else { return nil }
        if p.hasPrefix("http") { return URL(string: p) }                 // Emby public
        if p.hasPrefix("/iptv/") { p = "/dash" + p }                     // Plex → proxy
        let h = oturum.host.hasPrefix("http") ? oturum.host : "https://" + oturum.host
        let sep = p.contains("?") ? "&" : "?"
        return URL(string: h + p + "\(sep)t=\(oturum.token)&_t=\(oturum.token)")
    }
    func ilkYukle() async {
        embyOzet = await api.embyOzet(); plexOzet = await api.plexOzet()
        plexKut = ((plexOzet["kutuphaneler"] as? [[String:Any]]) ?? []).filter { !((($0["ad"] as? String) ?? "").uppercased().contains("XXX")) }
        if seciliPlex.isEmpty, let ilk = plexKut.first { seciliPlex = String(describing: ilk["kutuphane"] ?? "") }
        await yukle()
    }
    func yukle() async {
        yukleniyor = true; defer { yukleniyor = false }
        switch sekme {
        case "embyfilm": icerik = await api.embyIcerik("film", ara, 0)
        case "embydizi": icerik = await api.embyIcerik("dizi", ara, 0)
        case "canli":    icerik = await api.embyIcerik("canli", ara, 0)
        case "plex":     icerik = await api.plexIcerik(seciliPlex, ara, 0)
        case "indir":    indir = await api.indirmeler()
        case "istek":    istek = await api.istekler()
        case "sistem":   sistem = await api.sistemOzet()
        default: break
        }
    }
}

// MARK: - Native Ülke Erişimi (aç/kapat — topluluk ban muafiyeti) — WebView yok
struct UlkeNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var liste: [[String:Any]] = []
    @State private var yukleniyor = true
    @State private var islenen = ""
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            if yukleniyor { ProgressView().tint(tema.c1).scaleEffect(1.2) }
            else { ScrollView { VStack(spacing: 8) {
                Text("Açık ülkeler topluluk banından muaf tutulur. Sadece müşterin olan ülkeleri aç.").font(.caption).foregroundStyle(.rvMut).frame(maxWidth:.infinity,alignment:.leading).padding(.bottom,4)
                ForEach(Array(liste.enumerated()), id:\.offset) { i, u in
                    HStack {
                        VStack(alignment:.leading,spacing:2){
                            Text(u["ad"] as? String ?? "").foregroundStyle(.rvText)
                            Text("risk: \(u["risk"] as? String ?? "-")").font(.caption2).foregroundStyle(.rvMut)
                        }
                        Spacer()
                        if islenen == (u["cc"] as? String ?? "") { ProgressView().tint(tema.c1) }
                        Toggle("", isOn: Binding(
                            get: { u["aktif"] as? Bool ?? false },
                            set: { yeni in Task { await degis(i, u["cc"] as? String ?? "", yeni) } }
                        )).labelsHidden().tint(.green)
                    }.padding(13).glassEffect(.regular, in: .rect(cornerRadius: 12))
                }
            }.padding(16) }.refreshable { await yukle() } }
        }
        .navigationTitle("🌍 Ülke Erişimi").navigationBarTitleDisplayMode(.inline)
        .task { await yukle() }
    }
    func yukle() async { yukleniyor = true; defer { yukleniyor = false }; liste = await api.ulkeListe() }
    func degis(_ i: Int, _ cc: String, _ ac: Bool) async {
        islenen = cc; defer { islenen = "" }
        if await api.ulkeToggle(cc, ac), i < liste.count { liste[i]["aktif"] = ac }
    }
}

// MARK: - Native Operatör/ASN (sabit/mobil hat marka marka aç/engelle) — WebView yok
struct AsnNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var liste: [[String:Any]] = []
    @State private var yukleniyor = true
    @State private var islenen = ""
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            if yukleniyor { ProgressView().tint(tema.c1).scaleEffect(1.2) }
            else { ScrollView { VStack(spacing: 8) {
                Text("Operatör/marka bazlı: Aç = whitelist (banlanmaz), Engelle = tüm IP bloğu ban, Kapat = nötr.").font(.caption).foregroundStyle(.rvMut).frame(maxWidth:.infinity,alignment:.leading).padding(.bottom,4)
                ForEach(Array(liste.enumerated()), id:\.offset) { i, o in
                    VStack(alignment:.leading,spacing:8){
                        HStack{ Text("\(o["ulke"] as? String ?? "") \(o["ad"] as? String ?? "")").foregroundStyle(.rvText)
                            Spacer(); Text(o["tip"] as? String ?? "").font(.caption2).foregroundStyle(.rvMut) }
                        let asn = String(describing: o["asn"] ?? "")
                        let dur = o["durum"] as? String ?? "off"
                        HStack(spacing:6){
                            asnBtn("Aç","allow",asn,dur,i,.green)
                            asnBtn("Engelle","block",asn,dur,i,.red)
                            asnBtn("Kapat","off",asn,dur,i,.gray)
                            if islenen == asn { ProgressView().tint(tema.c1) }
                        }
                    }.padding(13).glassEffect(.regular, in: .rect(cornerRadius: 12))
                }
            }.padding(16) }.refreshable { await yukle() } }
        }
        .navigationTitle("📡 Operatör / Marka").navigationBarTitleDisplayMode(.inline)
        .task { await yukle() }
    }
    func asnBtn(_ t: String, _ act: String, _ asn: String, _ dur: String, _ i: Int, _ c: Color) -> some View {
        Button { Task { await degis(i, asn, act) } } label: {
            Text(t).font(.caption2.bold()).foregroundStyle(dur==act ? .white : c)
                .padding(.horizontal,12).padding(.vertical,7)
                .background(dur==act ? AnyShapeStyle(c) : AnyShapeStyle(.clear), in:.capsule)
                .overlay(Capsule().stroke(c.opacity(0.5)))
        }
    }
    func yukle() async { yukleniyor = true; defer { yukleniyor = false }; liste = await api.asnListe() }
    func degis(_ i: Int, _ asn: String, _ act: String) async {
        islenen = asn; defer { islenen = "" }
        if await api.asnToggle(asn, act), i < liste.count { liste[i]["durum"] = act }
    }
}

// MARK: - Native IP Yönetimi (tekil IP ban/whitelist/aç) — WebView yok
struct IPYonetNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var ip = ""
    @State private var sonuc = ""
    @State private var basari = false
    @State private var bekle = false
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            ScrollView { VStack(spacing: 14) {
                Text("Tekil IP işlemleri. 🔴 Kernel ban · 🟢 Whitelist (asla banlanmaz) · 🔵 Tüm banlardan çıkar.").font(.caption).foregroundStyle(.rvMut).frame(maxWidth:.infinity,alignment:.leading)
                TextField("IP adresi (203.0.113.5 / 2a01:…)", text: $ip).autocorrectionDisabled().textInputAutocapitalization(.never)
                    .foregroundStyle(.rvText).padding(14).glassEffect(.regular,in:.rect(cornerRadius:14))
                HStack(spacing: 8) {
                    ipBtn("🔴 Banla","ban",.red); ipBtn("🟢 Whitelist","whitelist",.green); ipBtn("🔵 Aç","unban",.blue)
                }
                if bekle { ProgressView().tint(tema.c1) }
                if !sonuc.isEmpty { Text(sonuc).font(.callout).foregroundStyle(basari ? .green : .orange).frame(maxWidth:.infinity,alignment:.leading).padding(12).glassEffect(.regular,in:.rect(cornerRadius:12)) }
            }.padding(16) }
        }
        .navigationTitle("🚫 IP Yönetimi").navigationBarTitleDisplayMode(.inline)
    }
    func ipBtn(_ t: String, _ act: String, _ c: Color) -> some View {
        Button { Task { await uygula(act) } } label: {
            Text(t).font(.caption.bold()).foregroundStyle(c).frame(maxWidth:.infinity).padding(.vertical,12)
                .overlay(RoundedRectangle(cornerRadius:12).stroke(c.opacity(0.6)))
        }.disabled(bekle || ip.trimmingCharacters(in:.whitespaces).isEmpty)
    }
    func uygula(_ act: String) async {
        bekle = true; defer { bekle = false }; sonuc = ""
        let r = await api.ipAksiyon(ip.trimmingCharacters(in:.whitespaces), act)
        if r?["ok"] as? Bool == true {
            basari = true
            let ad = ["ban":"kernel ban","whitelist":"whitelist (asla banlanmaz)","unban":"tüm banlardan çıkarıldı"][act] ?? act
            sonuc = "✅ \(r?["ip"] ?? ip) → \(ad)"
        } else { basari = false; sonuc = "⚠️ " + ((r?["err"] as? String) ?? "Hata") }
    }
}

// MARK: - Native Admin Hub (tüm app'lere push/duyuru/kod) — WebView yok
struct AdminHubNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var apps: [[String:Any]] = []
    @State private var secili = ""
    @State private var islem = "broadcast"
    @State private var baslik = ""
    @State private var govde = ""
    @State private var link = ""
    @State private var adet = 5
    @State private var sonuc = ""
    @State private var basari = false
    @State private var bekle = false
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            ScrollView { VStack(spacing: 12) {
                Picker("Uygulama", selection: $secili) {
                    Text("— uygulama seç —").tag("")
                    ForEach(Array(apps.enumerated()), id:\.offset){ _, a in Text(a["ad"] as? String ?? "").tag(a["id"] as? String ?? "") }
                }.pickerStyle(.menu).tint(tema.c1).frame(maxWidth:.infinity,alignment:.leading).padding(12).glassEffect(.regular,in:.rect(cornerRadius:14))
                Picker("İşlem", selection: $islem) {
                    Text("📣 Push").tag("broadcast"); Text("📌 Duyuru").tag("announce"); Text("🎁 Kod").tag("gencodes")
                }.pickerStyle(.segmented)
                if islem != "gencodes" {
                    alan("Başlık", $baslik); alan("Mesaj", $govde)
                    if islem == "announce" { alan("Link (opsiyonel)", $link) }
                } else {
                    Stepper("Kaç kod: \(adet)", value: $adet, in: 1...100).foregroundStyle(.rvText).padding(12).glassEffect(.regular,in:.rect(cornerRadius:14))
                }
                Button { Task { await gonder() } } label: {
                    HStack{ if bekle { ProgressView().tint(.white) }; Text("Gönder").bold() }.foregroundStyle(.white).frame(maxWidth:.infinity).padding(.vertical,14).background(tema.grad,in:.rect(cornerRadius:14))
                }.disabled(bekle || secili.isEmpty)
                if !sonuc.isEmpty { Text(sonuc).font(.callout).foregroundStyle(basari ? .green : .orange).frame(maxWidth:.infinity,alignment:.leading).textSelection(.enabled).padding(12).glassEffect(.regular,in:.rect(cornerRadius:12)) }
            }.padding(16) }
        }
        .navigationTitle("🎛️ Admin Hub").navigationBarTitleDisplayMode(.inline)
        .task { apps = await api.hubApps() }
    }
    func alan(_ ip: String, _ b: Binding<String>) -> some View {
        TextField(ip, text: b).foregroundStyle(.rvText).padding(13).glassEffect(.regular,in:.rect(cornerRadius:13))
    }
    func gonder() async {
        bekle = true; defer { bekle = false }; sonuc = ""
        var body: [String:Any] = ["app":secili,"action":islem]
        if islem == "gencodes" { body["count"] = adet }
        else { body["title"] = baslik; body["body"] = govde; if islem == "announce" { body["url"] = link; body["active"] = true } }
        let r = await api.hubAction(body)
        if r?["ok"] as? Bool == true || r?["codes"] != nil {
            basari = true
            if let c = r?["codes"] as? [String] { sonuc = "✅ Kodlar:\n" + c.joined(separator: "\n") }
            else { sonuc = "✅ Gönderildi (\(r?["sent"] ?? "ok"))" }
            baslik=""; govde=""; link=""
        } else { basari = false; sonuc = "⚠️ " + ((r?["err"] as? String) ?? "Hata") }
    }
}

// MARK: - Native Hediye Kod (RealVirtuality kredi) — WebView yok
struct HediyeNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var paketler: [[String:Any]] = []
    @State private var secili = ""
    @State private var adet = 1
    @State private var kime = ""
    @State private var sonuc = ""
    @State private var basari = false
    @State private var bekle = false
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            ScrollView { VStack(spacing: 12) {
                Text("RealVirtuality kredi hediye kodu üret — müşteriye/arkadaşa ver.").font(.caption).foregroundStyle(.rvMut).frame(maxWidth:.infinity,alignment:.leading)
                Picker("Paket", selection: $secili) {
                    Text("— paket seç —").tag("")
                    ForEach(Array(paketler.enumerated()), id:\.offset){ _, p in Text(p["ad"] as? String ?? "").tag(p["id"] as? String ?? "") }
                }.pickerStyle(.menu).tint(tema.c1).frame(maxWidth:.infinity,alignment:.leading).padding(12).glassEffect(.regular,in:.rect(cornerRadius:14))
                Stepper("Adet: \(adet)", value: $adet, in: 1...100).foregroundStyle(.rvText).padding(12).glassEffect(.regular,in:.rect(cornerRadius:14))
                TextField("Kime (opsiyonel not)", text: $kime).foregroundStyle(.rvText).padding(13).glassEffect(.regular,in:.rect(cornerRadius:13))
                Button { Task { await uret() } } label: {
                    HStack{ if bekle { ProgressView().tint(.white) }; Text("Kod Üret").bold() }.foregroundStyle(.white).frame(maxWidth:.infinity).padding(.vertical,14).background(tema.grad,in:.rect(cornerRadius:14))
                }.disabled(bekle || secili.isEmpty)
                if !sonuc.isEmpty { Text(sonuc).font(.callout).foregroundStyle(basari ? .green : .orange).frame(maxWidth:.infinity,alignment:.leading).textSelection(.enabled).padding(12).glassEffect(.regular,in:.rect(cornerRadius:12)) }
            }.padding(16) }
        }
        .navigationTitle("🎁 Hediye Kod").navigationBarTitleDisplayMode(.inline)
        .task { paketler = await api.hediyePaketler() }
    }
    func uret() async {
        bekle = true; defer { bekle = false }; sonuc = ""
        let r = await api.hediyeKodUret(secili, adet, kime)
        if let c = (r?["kodlar"] as? [String]) ?? (r?["codes"] as? [String]) {
            basari = true; sonuc = "✅ Üretilen kodlar:\n" + c.joined(separator: "\n")
        } else { basari = false; sonuc = "⚠️ " + ((r?["mesaj"] as? String) ?? (r?["err"] as? String) ?? "Hata") }
    }
}

// MARK: - Native Demo Üret (işletme demosu → SMS+mail oto) — WebView yok
struct DemoNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var ad = ""
    @State private var sektor = "restoran"
    @State private var tel = ""
    @State private var email = ""
    @State private var sonuc = ""
    @State private var basari = false
    @State private var bekle = false
    private let sektorler: [(String,String)] = [("restoran","Restoran / Kafe"),("randevu","Kuaför / Klinik"),("hukuk","Hukuk Bürosu"),("kurumsal","Kurumsal"),("genel","Genel")]
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            ScrollView { VStack(spacing: 12) {
                Text("İşletme demosu oluştur → demo linki + giriş bilgisi SMS ve e-posta ile otomatik gider.").font(.caption).foregroundStyle(.rvMut).frame(maxWidth:.infinity,alignment:.leading)
                alan("İşletme adı", $ad)
                Picker("Sektör", selection: $sektor) { ForEach(sektorler, id:\.0){ Text($0.1).tag($0.0) } }
                    .pickerStyle(.menu).tint(tema.c1).frame(maxWidth:.infinity,alignment:.leading).padding(12).glassEffect(.regular,in:.rect(cornerRadius:14))
                alan("Telefon (905…)", $tel); alan("E-posta", $email)
                Button { Task { await uret() } } label: {
                    HStack{ if bekle { ProgressView().tint(.white) }; Text("🚀 Demo Oluştur & Gönder").bold() }.foregroundStyle(.white).frame(maxWidth:.infinity).padding(.vertical,14).background(tema.grad,in:.rect(cornerRadius:14))
                }.disabled(bekle || ad.isEmpty || (tel.isEmpty && email.isEmpty))
                if !sonuc.isEmpty { Text(sonuc).font(.callout).foregroundStyle(basari ? .green : .orange).frame(maxWidth:.infinity,alignment:.leading).textSelection(.enabled).padding(12).glassEffect(.regular,in:.rect(cornerRadius:12)) }
            }.padding(16) }
        }
        .navigationTitle("🎯 Demo Üret").navigationBarTitleDisplayMode(.inline)
    }
    func alan(_ ip: String, _ b: Binding<String>) -> some View {
        TextField(ip, text: b).autocorrectionDisabled().textInputAutocapitalization(.never)
            .foregroundStyle(.rvText).padding(13).glassEffect(.regular,in:.rect(cornerRadius:13))
    }
    func uret() async {
        bekle = true; defer { bekle = false }; sonuc = ""
        let r = await api.demoUret(["ad":ad,"sektor":sektor,"tel":tel,"email":email])
        if r?["ok"] as? Bool == true {
            basari = true
            let sms = r?["sms"] as? Bool; let ml = r?["mail"] as? Bool
            sonuc = "✅ Demo hazır\n\(r?["sektor"] ?? "")\nLink: \(r?["demo"] ?? "")\nKod: \(r?["kod"] ?? "")  Şifre: \(r?["sifre"] ?? "")\n📱 SMS: \(sms==true ? "gönderildi" : (sms==false ? "✗" : "—"))  📧 Mail: \(ml==true ? "gönderildi" : (ml==false ? "✗" : "—"))"
            ad=""; tel=""; email=""
        } else { basari = false; sonuc = "⚠️ " + ((r?["mesaj"] as? String) ?? "Hata") }
    }
}
