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
    @State private var kanalAra = ""
    @State private var topluMod = false
    @State private var seciliKanallar: Set<String> = []
    @State private var topluBekle = false
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
    var kanalSuzulmus: [[String:Any]] {
        kanalAra.isEmpty ? kanallar : kanallar.filter { (($0["ad"] as? String) ?? "").localizedCaseInsensitiveContains(kanalAra) }
    }
    var kanalGorunum: some View {
        VStack(spacing: 8) {
            TextField("Kanal ara…", text:$kanalAra).foregroundStyle(.rvText).padding(11).glassEffect(.regular,in:.rect(cornerRadius:12))
            HStack {
                Toggle("Toplu seçim", isOn:$topluMod.animation()).tint(tema.c1).foregroundStyle(.rvText).fixedSize()
                Spacer()
                if topluMod {
                    Button(seciliKanallar.count == kanalSuzulmus.count ? "Temizle":"Tümünü seç") {
                        let ids = kanalSuzulmus.compactMap { $0["id"] as? String }
                        if seciliKanallar.count == ids.count { seciliKanallar = [] } else { seciliKanallar = Set(ids) }
                    }.font(.caption.bold()).foregroundStyle(tema.c1)
                }
            }
            if topluMod && !seciliKanallar.isEmpty {
                HStack(spacing:8){
                    if topluBekle { ProgressView().tint(tema.c1) }
                    Text("Seçili: \(seciliKanallar.count)").font(.caption).foregroundStyle(.rvMut)
                    Spacer()
                    kbtn("Kısıtla", .red) { Task { await toplu("kisitla") } }
                    kbtn("Aç", .green) { Task { await toplu("ac") } }
                }.padding(10).glassEffect(.regular,in:.rect(cornerRadius:12))
            }
            ForEach(Array(kanalSuzulmus.prefix(400).enumerated()), id: \.offset) { _, k in
                let id = k["id"] as? String ?? ""
                HStack {
                    if topluMod {
                        Image(systemName: seciliKanallar.contains(id) ? "checkmark.circle.fill":"circle")
                            .foregroundStyle(seciliKanallar.contains(id) ? tema.c1 : .rvMut)
                    }
                    Text(k["ad"] as? String ?? "-").font(.subheadline).foregroundStyle(.rvText).lineLimit(1)
                    Spacer()
                    if !topluMod {
                        let kis = (k["kisitli"] as? Bool) ?? false
                        kbtn(kis ? "Aç" : "Kısıtla", tema.c2) { Task { _ = await api.iptvKanalAksiyon(id, kis ? "ac":"kisitla"); await yukle() } }
                    }
                }.padding(12).glassEffect(.regular, in: .rect(cornerRadius: 12))
                .contentShape(Rectangle())
                .onTapGesture { if topluMod { if seciliKanallar.contains(id) { seciliKanallar.remove(id) } else { seciliKanallar.insert(id) } } }
            }
        }.padding(16)
    }
    func toplu(_ aksiyon: String) async {
        topluBekle = true; defer { topluBekle = false }
        for id in seciliKanallar { _ = await api.iptvKanalAksiyon(id, aksiyon) }
        seciliKanallar = []; await yukle()
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
    @State private var seciliUye: [String:Any]? = nil
    @State private var islemMesaj = ""
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
                            if sekme=="members", it["id"] != nil {
                                Button { seciliUye = it } label: {
                                    HStack { Text(_satirMetin(it)).font(.caption).foregroundStyle(.rvText).frame(maxWidth:.infinity,alignment:.leading)
                                        Image(systemName:"slider.horizontal.3").font(.caption2).foregroundStyle(tema.c1) }
                                    .padding(12).glassEffect(.regular,in:.rect(cornerRadius:12))
                                }
                            } else {
                                Text(_satirMetin(it)).font(.caption).foregroundStyle(.rvText).frame(maxWidth:.infinity,alignment:.leading).padding(12).glassEffect(.regular,in:.rect(cornerRadius:12))
                            }
                        }}.padding(16)
                    }
                }.refreshable { await yukle() } }
                if !islemMesaj.isEmpty { Text(islemMesaj).font(.caption).foregroundStyle(.green).padding(8) }
            }
        }
        .navigationTitle("Admin Panel").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Üye işlemi", isPresented: Binding(get:{seciliUye != nil}, set:{ if !$0 { seciliUye=nil } }), presenting: seciliUye) { u in
            Button("30 gün uzat") { Task { await uyeIslem(u, 30) } }
            Button("90 gün uzat") { Task { await uyeIslem(u, 90) } }
            Button("365 gün uzat") { Task { await uyeIslem(u, 365) } }
            Button("Erişimi kaldır", role:.destructive) { Task { await uyeIslem(u, 0) } }
            Button("Vazgeç", role:.cancel) {}
        } message: { u in Text("\(u["email"] ?? u["name"] ?? "")") }
        .task { await yukle() }
    }
    func uyeIslem(_ u:[String:Any], _ uzat:Int) async {
        let id = "\(u["id"] ?? "")"; let email = "\(u["email"] ?? "")"
        islemMesaj = "⏳ İşleniyor…"
        if uzat > 0 { _ = await api.uyeUzat(id:id, days:uzat); islemMesaj = "✅ \(email): \(uzat) gün uzatıldı" }
        else { _ = await api.uyeErisimKaldir(user:email); islemMesaj = "✅ \(email): erişim kaldırıldı" }
        seciliUye = nil; await yukle()
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

// MARK: - Native Abonelik / Erişim (müşteriye erişim ver / uzat) — WebView yok
struct AbonelikNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var email = ""
    @State private var plan = "premium"
    @State private var gun = 30
    @State private var sonuc = ""
    @State private var basari = false
    @State private var bekle = false
    private let planlar = ["premium","pro","basic","business"]
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            ScrollView { VStack(spacing:12){
                Text("Müşteriye erişim ver veya süre uzat (e-posta + plan + gün).").font(.caption).foregroundStyle(.rvMut).frame(maxWidth:.infinity,alignment:.leading)
                TextField("E-posta", text:$email).autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.emailAddress)
                    .foregroundStyle(.rvText).padding(14).glassEffect(.regular,in:.rect(cornerRadius:14))
                Picker("Plan", selection:$plan){ ForEach(planlar,id:\.self){ Text($0.capitalized).tag($0) } }
                    .pickerStyle(.menu).tint(tema.c1).frame(maxWidth:.infinity,alignment:.leading).padding(12).glassEffect(.regular,in:.rect(cornerRadius:14))
                Stepper("Süre: \(gun) gün", value:$gun, in:1...3650, step:30).foregroundStyle(.rvText).padding(12).glassEffect(.regular,in:.rect(cornerRadius:14))
                HStack(spacing:8){ ForEach([30,90,180,365],id:\.self){ g in
                    Button("\(g)g"){ gun=g }.font(.caption.bold()).foregroundStyle(gun==g ? .white : tema.c1)
                        .frame(maxWidth:.infinity).padding(.vertical,9).background(gun==g ? AnyShapeStyle(tema.grad):AnyShapeStyle(.clear),in:.capsule).overlay(Capsule().stroke(tema.c1.opacity(0.4)))
                }}
                Button { Task { await ver() } } label: {
                    HStack{ if bekle { ProgressView().tint(.white) }; Text("✅ Erişim Ver / Uzat").bold() }.foregroundStyle(.white).frame(maxWidth:.infinity).padding(.vertical,15).background(tema.grad,in:.rect(cornerRadius:14))
                }.disabled(bekle || !email.contains("@"))
                if !sonuc.isEmpty { Text(sonuc).font(.callout).foregroundStyle(basari ? .green : .orange).frame(maxWidth:.infinity,alignment:.leading).padding(12).glassEffect(.regular,in:.rect(cornerRadius:12)) }
            }.padding(16) }
        }
        .navigationTitle("🎫 Abonelik / Erişim").navigationBarTitleDisplayMode(.inline)
    }
    func ver() async {
        bekle = true; defer { bekle = false }; sonuc = ""
        let r = await api.grant(email: email.trimmingCharacters(in:.whitespaces), days: gun, plan: plan)
        if r?["ok"] as? Bool == true || r?["success"] as? Bool == true || r?["granted"] != nil {
            basari = true; sonuc = "✅ \(email) → \(plan) · \(gun) gün erişim verildi"
            email = ""
        } else { basari = false; sonuc = "⚠️ " + ((r?["mesaj"] as? String) ?? (r?["error"] as? String) ?? "Hata / kayıt bulunamadı") }
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
    @State private var zamanla = false
    @State private var tarih = Date().addingTimeInterval(3600)
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
                if islem != "gencodes" {
                    Toggle("⏰ Zamanla (ileri tarihe planla)", isOn:$zamanla).tint(tema.c1).foregroundStyle(.rvText).padding(.horizontal,4)
                    if zamanla {
                        DatePicker("Gönderim zamanı", selection:$tarih, in:Date()...).datePickerStyle(.compact).foregroundStyle(.rvText).padding(12).glassEffect(.regular,in:.rect(cornerRadius:14))
                    }
                }
                Button { Task { await gonder() } } label: {
                    HStack{ if bekle { ProgressView().tint(.white) }; Text(zamanla && islem != "gencodes" ? "Zamanla" : "Gönder").bold() }.foregroundStyle(.white).frame(maxWidth:.infinity).padding(.vertical,14).background(tema.grad,in:.rect(cornerRadius:14))
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
        if zamanla && islem != "gencodes" {
            body["when_ts"] = tarih.timeIntervalSince1970
            let r = await api.hubZamanla(body)
            if r?["ok"] as? Bool == true {
                basari = true; let df = DateFormatter(); df.dateFormat = "dd.MM HH:mm"
                sonuc = "✅ Zamanlandı: " + df.string(from: tarih); baslik=""; govde=""; link=""
            } else { basari = false; sonuc = "⚠️ " + ((r?["err"] as? String) ?? "Hata") }
            return
        }
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

// MARK: - Kontrol Merkezi Native
struct KontrolMerkeziNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var sekme = 0
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            VStack(spacing: 0) {
                Picker("", selection: $sekme) {
                    Text("📋 Görevler").tag(0)
                    Text("🤖 Claude").tag(1)
                    Text("⚙️ Servisler").tag(2)
                    Text("🚀 Git/CI").tag(3)
                }.pickerStyle(.segmented).padding(12)
                    .background(.ultraThinMaterial)
                Group {
                    if sekme == 0 { GorevlerTab(api: api) }
                    else if sekme == 1 { ClaudeTab(api: api) }
                    else if sekme == 2 { ServislerTab(api: api) }
                    else { GitTab(api: api) }
                }
            }
        }
        .navigationTitle("🎮 Kontrol Merkezi").navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Görevler
struct GorevlerTab: View {
    let api: PanelAPI
    @EnvironmentObject var tema: Tema
    @State private var gorevler: [[String:Any]] = []
    @State private var yeniBas = ""
    @State private var yeniOt = "server"
    @State private var yeniOnc = "orta"
    @State private var eklemeAc = false
    @State private var yukl = false
    let oturumlar = ["server","media","matrix","finans","developer","yedek1"]
    let onclikler = ["yuksek","orta","dusuk"]
    let durumlar = [("todo","📌"),("devam","⚡"),("bitti","✅"),("iptal","❌")]
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Yeni ekle
                Button { eklemeAc.toggle() } label: {
                    Label(eklemeAc ? "İptal" : "Yeni Görev", systemImage: eklemeAc ? "xmark" : "plus")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(12)
                        .background(tema.grad, in: .rect(cornerRadius: 12))
                }.padding(.horizontal)
                if eklemeAc {
                    VStack(spacing: 8) {
                        TextField("Görev başlığı", text: $yeniBas)
                            .textFieldStyle(.roundedBorder).autocorrectionDisabled()
                        HStack(spacing: 8) {
                            Picker("Oturum", selection: $yeniOt) {
                                ForEach(oturumlar, id: \.self) { Text($0).tag($0) }
                            }.pickerStyle(.menu).frame(maxWidth: .infinity)
                                .padding(8).background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
                            Picker("Öncelik", selection: $yeniOnc) {
                                ForEach(onclikler, id: \.self) { Text($0).tag($0) }
                            }.pickerStyle(.menu).frame(maxWidth: .infinity)
                                .padding(8).background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
                        }
                        Button("Ekle") { Task { await ekle() } }
                            .disabled(yeniBas.trimmingCharacters(in: .whitespaces).isEmpty)
                            .font(.subheadline.bold()).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(10)
                            .background(Color.blue, in: .rect(cornerRadius: 10))
                    }.padding(.horizontal)
                }
                if yukl { ProgressView().tint(tema.c1) }
                ForEach(durumlar, id: \.0) { (dur, ikon) in
                    let liste = gorevler.filter { ($0["durum"] as? String ?? "todo") == dur }
                    if !liste.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(ikon) \(dur.capitalized) (\(liste.count))")
                                .font(.caption.bold()).foregroundStyle(.secondary).padding(.horizontal)
                            ForEach(liste, id: { $0["id"] as? Int ?? 0 }) { g in
                                GorevSatir(g: g, api: api, yenile: { Task { await yukle() } })
                            }
                        }
                    }
                }
            }.padding(.vertical, 8)
        }
        .task { await yukle() }.refreshable { await yukle() }
    }
    func yukle() async { yukl = true; gorevler = await api.gorevler(); yukl = false }
    func ekle() async {
        let bas = yeniBas.trimmingCharacters(in: .whitespaces); guard !bas.isEmpty else { return }
        _ = await api.gorevEkle(["baslik":bas,"oturum":yeniOt,"oncelik":yeniOnc,"durum":"todo"])
        yeniBas = ""; eklemeAc = false; await yukle()
    }
}
struct GorevSatir: View {
    let g: [String:Any]; let api: PanelAPI; let yenile: () -> Void
    @EnvironmentObject var tema: Tema
    @State private var secDurum: String
    let durumlar = ["todo","devam","bitti","iptal"]
    let durRenk: [String: Color] = ["todo":.gray,"devam":.blue,"bitti":.green,"iptal":.red]
    init(g: [String:Any], api: PanelAPI, yenile: @escaping () -> Void) {
        self.g = g; self.api = api; self.yenile = yenile
        _secDurum = State(initialValue: g["durum"] as? String ?? "todo")
    }
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(durRenk[secDurum] ?? .gray).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(g["baslik"] as? String ?? "").font(.subheadline.bold()).foregroundStyle(.primary)
                if let ot = g["oturum"] as? String, !ot.isEmpty {
                    Text(ot).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Picker("", selection: $secDurum) {
                ForEach(durumlar, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.menu).onChange(of: secDurum) { _, yeni in
                Task { _ = await api.gorevGuncelle(["id":g["id"] as? Int ?? 0,"durum":yeni]); yenile() }
            }
            Button { Task { _ = await api.gorevSil(g["id"] as? Int ?? 0); yenile() } } label: {
                Image(systemName: "trash").foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: Claude Tab
struct ClaudeTab: View {
    let api: PanelAPI
    @EnvironmentObject var tema: Tema
    @State private var oturumlar: [[String:Any]] = []
    @State private var cmdOt = "server"
    @State private var cmdMetin = ""
    @State private var cmdMsg = ""
    @State private var ekranOt = "server"
    @State private var ekranIc = ""
    @State private var yukl = false
    let otList = ["server","media","matrix","finans","developer","yedek1"]
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Oturum durumu
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("🖥️ Oturumlar").font(.headline).foregroundStyle(.primary)
                        Spacer()
                        Button("Yenile") { Task { await yukle() } }.font(.caption).foregroundStyle(tema.c1)
                    }
                    if yukl { ProgressView().tint(tema.c1) }
                    ForEach(oturumlar, id: { $0["oturum"] as? String ?? "" }) { ot in
                        HStack(spacing: 8) {
                            Circle().fill((ot["aktif"] as? Bool == true) ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(ot["oturum"] as? String ?? "").font(.subheadline.bold()).frame(width: 70, alignment: .leading)
                            Text(ot["son"] as? String ?? "—").font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.tail)
                        }.padding(.vertical, 4)
                    }
                }.padding(14).background(.ultraThinMaterial, in: .rect(cornerRadius: 14)).padding(.horizontal)
                // Komut gönder
                VStack(alignment: .leading, spacing: 8) {
                    Text("📡 Komut Gönder").font(.headline).foregroundStyle(.primary)
                    Picker("Oturum", selection: $cmdOt) {
                        ForEach(otList, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                    TextEditor(text: $cmdMetin).frame(minHeight: 60)
                        .padding(8).background(Color(.systemBackground).opacity(0.3))
                        .clipShape(.rect(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius:10).stroke(.quaternary))
                    Button("Gönder →") { Task { await cmdGonder() } }
                        .disabled(cmdMetin.trimmingCharacters(in: .whitespaces).isEmpty)
                        .font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(10).background(Color.blue, in: .rect(cornerRadius: 10))
                    if !cmdMsg.isEmpty { Text(cmdMsg).font(.caption).foregroundStyle(cmdMsg.hasPrefix("✅") ? .green : .orange) }
                }.padding(14).background(.ultraThinMaterial, in: .rect(cornerRadius: 14)).padding(.horizontal)
                // Ekran görüntü
                VStack(alignment: .leading, spacing: 8) {
                    Text("📺 Oturum Ekranı").font(.headline).foregroundStyle(.primary)
                    HStack {
                        Picker("", selection: $ekranOt) {
                            ForEach(otList, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.menu)
                        Button("Göster") { Task { await ekranYukle() } }
                            .font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(tema.c1, in: .rect(cornerRadius: 8))
                    }
                    if !ekranIc.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(ekranIc).font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color.green).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 180).padding(8)
                        .background(Color.black.opacity(0.7), in: .rect(cornerRadius: 10))
                    }
                }.padding(14).background(.ultraThinMaterial, in: .rect(cornerRadius: 14)).padding(.horizontal)
            }.padding(.vertical, 8)
        }
        .task { await yukle() }.refreshable { await yukle() }
    }
    func yukle() async { yukl = true; oturumlar = await api.claudeOturumlar(); yukl = false }
    func cmdGonder() async {
        let m = cmdMetin.trimmingCharacters(in: .whitespaces); guard !m.isEmpty else { return }
        let ok = await api.claudeCmd(cmdOt, m)
        cmdMsg = ok ? "✅ Gönderildi" : "⚠️ Hata"
        if ok { cmdMetin = "" }
        try? await Task.sleep(nanoseconds: 3_000_000_000); cmdMsg = ""
    }
    func ekranYukle() async { ekranIc = await api.claudeEkran(ekranOt) }
}

// MARK: Servisler Tab
struct ServislerTab: View {
    let api: PanelAPI
    @EnvironmentObject var tema: Tema
    @State private var servisler: [[String:Any]] = []
    @State private var logServis = ""
    @State private var logIc = ""
    @State private var yukl = false
    @State private var mesaj = ""
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if yukl { ProgressView().tint(tema.c1).padding() }
                ForEach(servisler, id: { $0["servis"] as? String ?? "" }) { s in
                    let ad = s["servis"] as? String ?? ""
                    let aktif = (s["durum"] as? String ?? "") == "active"
                    HStack(spacing: 10) {
                        Circle().fill(aktif ? Color.green : Color.red).frame(width: 8, height: 8)
                        Text(ad).font(.caption.bold()).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                        Button("log") { Task { await logYukle(ad) } }.font(.caption2).foregroundStyle(.secondary)
                        Button { Task { await aksiyon(ad, "restart") } } label: {
                            Image(systemName: "arrow.clockwise").foregroundStyle(tema.c1)
                        }.font(.caption)
                        Button { Task { await aksiyon(ad, "stop") } } label: {
                            Image(systemName: "stop.fill").foregroundStyle(.red)
                        }.font(.caption)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
                    .padding(.horizontal)
                }
                if !mesaj.isEmpty { Text(mesaj).font(.caption).foregroundStyle(mesaj.hasPrefix("✅") ? .green : .orange).padding(.horizontal) }
                if !logIc.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("📄 \(logServis)").font(.caption.bold()).foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(logIc).font(.system(size: 9, design: .monospaced)).foregroundStyle(Color.cyan)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200).padding(8).background(Color.black.opacity(0.7), in: .rect(cornerRadius: 10))
                    }.padding(.horizontal)
                }
            }.padding(.vertical, 8)
        }
        .task { await yukle() }.refreshable { await yukle() }
    }
    func yukle() async { yukl = true; servisler = await api.servislerDetay(); yukl = false }
    func aksiyon(_ s: String, _ a: String) async {
        if a == "stop" { mesaj = "\(s) durduruluyor…" }
        let ok = await api.servisAksiyon(s, a)
        mesaj = ok ? "✅ \(a) ok" : "⚠️ Hata"
        await yukle()
        try? await Task.sleep(nanoseconds: 3_000_000_000); mesaj = ""
    }
    func logYukle(_ s: String) async {
        logServis = s; logIc = "Yükleniyor…"
        logIc = await api.servisLog(s)
    }
}

// MARK: Git/CI Tab
struct GitTab: View {
    let api: PanelAPI
    @EnvironmentObject var tema: Tema
    @State private var commitler: [String] = []
    @State private var ci: [[String:Any]] = []
    @State private var yukl = false
    let durRenk: [String: Color] = ["success": .green, "failure": .red, "in_progress": .blue, "cancelled": .gray]
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if yukl { ProgressView().tint(tema.c1) }
                VStack(alignment: .leading, spacing: 6) {
                    Text("📦 Son Commitler").font(.headline).foregroundStyle(.primary)
                    ForEach(commitler, id: \.self) { c in
                        let parts = c.split(separator: " ", maxSplits: 1).map(String.init)
                        HStack(alignment: .top, spacing: 8) {
                            Text(parts.first ?? "").font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary).frame(width: 55, alignment: .leading)
                            Text(parts.dropFirst().first ?? c).font(.caption).foregroundStyle(.primary)
                        }.padding(.vertical, 3)
                    }
                }.padding(14).background(.ultraThinMaterial, in: .rect(cornerRadius: 14)).padding(.horizontal)
                if !ci.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("🔄 CI/CD Durumu").font(.headline).foregroundStyle(.primary)
                        ForEach(ci, id: { $0["isim"] as? String ?? "" }) { r in
                            let sonuc = r["sonuc"] as? String ?? r["durum"] as? String ?? ""
                            HStack(spacing: 8) {
                                Circle().fill(durRenk[sonuc] ?? .gray).frame(width: 8, height: 8)
                                Text(r["isim"] as? String ?? "").font(.caption).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                                Text(r["tarih"] as? String ?? "").font(.caption2).foregroundStyle(.secondary)
                            }.padding(.vertical, 3)
                        }
                    }.padding(14).background(.ultraThinMaterial, in: .rect(cornerRadius: 14)).padding(.horizontal)
                }
            }.padding(.vertical, 8)
        }
        .task { await yukle() }.refreshable { await yukle() }
    }
    func yukle() async {
        yukl = true
        let d = await api.gitDurum()
        commitler = d["commitler"] as? [String] ?? []
        ci = d["ci"] as? [[String:Any]] ?? []
        yukl = false
    }
}

// MARK: - Meta Reklam Analiz

struct MetaAnalizNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var veri: [String:Any] = [:]
    @State private var yukl = true
    @State private var hata = ""
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    private var kampanyalar: [[String:Any]] { veri["kampanyalar"] as? [[String:Any]] ?? [] }

    var body: some View {
        ScrollView {
            if yukl {
                ProgressView("Reklam verisi yükleniyor…").padding(40)
            } else if !hata.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
                    Text(hata).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(30)
            } else {
                VStack(spacing: 12) {
                    // Hesap özet kartı
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Hesap Özeti — Bugün").font(.caption.bold()).foregroundStyle(.secondary)
                        HStack(spacing: 0) {
                            MetriKutu(ikon: "turkishlirasign.circle", baslik: "Harcama", deger: String(format: "₺%.0f", veri["bugun_harcama"] as? Double ?? 0), renk: .red)
                            MetriKutu(ikon: "eye", baslik: "Gösterim", deger: fmt(veri["bugun_gosterim"] as? Int ?? 0), renk: .blue)
                            MetriKutu(ikon: "cursorarrow.click", baslik: "Tıklama", deger: fmt(veri["bugun_tiklama"] as? Int ?? 0), renk: .green)
                            MetriKutu(ikon: "person.2", baslik: "Erişim", deger: fmt(veri["bugun_erisim"] as? Int ?? 0), renk: .purple)
                        }
                        Divider()
                        HStack {
                            Label(String(format: "Bakiye: ₺%d", veri["bakiye"] as? Int ?? 0), systemImage: "creditcard.fill").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Label(String(format: "Toplam: ₺%d", veri["toplam_harcama"] as? Int ?? 0), systemImage: "chart.bar.fill").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(14).background(.ultraThinMaterial, in: .rect(cornerRadius: 16)).padding(.horizontal)

                    // Kampanya listesi
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kampanyalar (\(kampanyalar.count))").font(.caption.bold()).foregroundStyle(.secondary).padding(.horizontal)
                        ForEach(Array(kampanyalar.enumerated()), id: \.offset) { _, k in
                            KampanyaSatir(k: k)
                        }
                    }
                }.padding(.vertical, 8)
            }
        }
        .navigationTitle("Meta Reklam")
        .navigationBarTitleDisplayMode(.large)
        .task { await yukle() }
        .refreshable { await yukle() }
    }
    private func fmt(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000) :
        n >= 1_000 ? String(format: "%.1fK", Double(n)/1_000) : "\(n)"
    }
    func yukle() async {
        yukl = true; hata = ""
        let d = await api.metaAnaliz()
        if d["ok"] as? Bool == false { hata = d["mesaj"] as? String ?? "Hata" }
        else { veri = d }
        yukl = false
    }
}

struct MetriKutu: View {
    let ikon: String; let baslik: String; let deger: String; let renk: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: ikon).font(.system(size: 18)).foregroundStyle(renk)
            Text(deger).font(.system(size: 14, weight: .bold))
            Text(baslik).font(.system(size: 10)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

struct KampanyaSatir: View {
    let k: [String:Any]
    @State private var acik = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { acik.toggle() } label: {
                HStack(spacing: 10) {
                    Circle().fill(statusRenk(k["durum"] as? String ?? "")).frame(width: 9, height: 9)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k["isim"] as? String ?? "").font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(1)
                        HStack(spacing: 6) {
                            Text(k["durum"] as? String ?? "").font(.caption2).foregroundStyle(.secondary)
                            Text("•").foregroundStyle(.tertiary)
                            Text(String(format: "₺%d/gün", k["gunluk_butce"] as? Int ?? 0)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: acik ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(.secondary)
                }.padding(.horizontal, 14).padding(.vertical, 12)
            }.buttonStyle(.plain)

            if acik {
                HStack(spacing: 0) {
                    MetriKutu(ikon: "turkishlirasign.circle", baslik: "Harcama", deger: String(format: "₺%.2f", k["harcama"] as? Double ?? 0), renk: .red)
                    MetriKutu(ikon: "eye", baslik: "Gösterim", deger: fmtN(k["gosterim"] as? Int ?? 0), renk: .blue)
                    MetriKutu(ikon: "cursorarrow.click", baslik: "CTR", deger: String(format: "%.2f%%", k["ctr"] as? Double ?? 0), renk: .green)
                    MetriKutu(ikon: "turkishlirasign", baslik: "TBM", deger: String(format: "₺%.2f", k["cpc"] as? Double ?? 0), renk: .orange)
                }.padding(.horizontal, 10).padding(.bottom, 10)
            }
        }.background(.ultraThinMaterial, in: .rect(cornerRadius: 12)).padding(.horizontal)
    }
    private func fmtN(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000) :
        n >= 1_000 ? String(format: "%.1fK", Double(n)/1_000) : "\(n)"
    }
    private func statusRenk(_ s: String) -> Color {
        switch s { case "ACTIVE": return .green; case "PAUSED": return .orange; default: return .gray }
    }
}

// MARK: - Satış & Gelir

struct SatisNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var veri: [String:Any] = [:]
    @State private var yukl = true
    @State private var hata = ""
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    private var sonOdemeler: [[String:Any]] { veri["son_odemeler"] as? [[String:Any]] ?? [] }

    var body: some View {
        ScrollView {
            if yukl {
                ProgressView("Satış verileri yükleniyor…").padding(40)
            } else if !hata.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
                    Text(hata).font(.caption).foregroundStyle(.secondary)
                }.padding(30)
            } else {
                VStack(spacing: 12) {
                    // Üye özet
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Üye Durumu").font(.caption.bold()).foregroundStyle(.secondary)
                        HStack(spacing: 0) {
                            MetriKutu(ikon: "person.fill.checkmark", baslik: "Aktif", deger: "\(veri["aktif_uye"] as? Int ?? 0)", renk: .green)
                            MetriKutu(ikon: "person.2.fill", baslik: "Toplam", deger: "\(veri["toplam_uye"] as? Int ?? 0)", renk: .blue)
                            MetriKutu(ikon: "creditcard.fill", baslik: "Ödeme", deger: "\(veri["toplam_odeme"] as? Int ?? 0)", renk: .purple)
                        }
                    }.padding(14).background(.ultraThinMaterial, in: .rect(cornerRadius: 16)).padding(.horizontal)

                    // Gelir özet
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Gelir Özeti").font(.caption.bold()).foregroundStyle(.secondary)
                        HStack(spacing: 0) {
                            MetriKutu(ikon: "sun.max.fill", baslik: "Bugün", deger: String(format: "$%.2f", veri["bugun_gelir"] as? Double ?? 0), renk: .yellow)
                            MetriKutu(ikon: "calendar.badge.checkmark", baslik: "7 Gün", deger: String(format: "$%.2f", veri["yedi_gelir"] as? Double ?? 0), renk: .orange)
                            MetriKutu(ikon: "chart.line.uptrend.xyaxis", baslik: "30 Gün", deger: String(format: "$%.2f", veri["otuz_gelir"] as? Double ?? 0), renk: .green)
                        }
                        HStack {
                            Label("Bugün \(veri["bugun_odeme"] as? Int ?? 0) işlem", systemImage: "checkmark.circle").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Label("7 günde \(veri["yedi_odeme"] as? Int ?? 0) işlem", systemImage: "calendar").font(.caption2).foregroundStyle(.secondary)
                        }
                    }.padding(14).background(.ultraThinMaterial, in: .rect(cornerRadius: 16)).padding(.horizontal)

                    // Son ödemeler
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Son Ödemeler").font(.caption.bold()).foregroundStyle(.secondary).padding(.horizontal)
                        ForEach(Array(sonOdemeler.enumerated()), id: \.offset) { _, o in
                            OdemeSatir(o: o)
                        }
                    }
                }.padding(.vertical, 8)
            }
        }
        .navigationTitle("Satış & Gelir")
        .navigationBarTitleDisplayMode(.large)
        .task { await yukle() }
        .refreshable { await yukle() }
    }
    func yukle() async {
        yukl = true; hata = ""
        let d = await api.satisOzet()
        if d["ok"] as? Bool == false { hata = d["mesaj"] as? String ?? "Hata" }
        else { veri = d }
        yukl = false
    }
}

struct OdemeSatir: View {
    let o: [String:Any]
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(o["email"] as? String ?? "-").font(.subheadline).lineLimit(1)
                HStack(spacing: 4) {
                    Text(o["plan"] as? String ?? "").font(.caption2).foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    Text(o["yontem"] as? String ?? "").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "$%.2f", o["tutar"] as? Double ?? 0)).font(.subheadline.bold()).foregroundStyle(.green)
                Text(o["tarih"] as? String ?? "").font(.caption2).foregroundStyle(.tertiary)
            }
        }.padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
        .padding(.horizontal)
    }
}

// MARK: - Tam Koordinasyon (tüm oturumlar + her iki sunucu)

struct KoordinasyonNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var veri: [String:Any] = [:]
    @State private var yukl = true
    @State private var sekme = 0   // 0=Oturumlar 1=Ana Sunucu 2=ND2 3=Özet
    @State private var komutOturum = ""
    @State private var komutMetin = ""
    @State private var komutSonuc = ""
    @State private var ekranOturum = ""
    @State private var ekranIcerik = ""
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sekme) {
                Text("Oturumlar").tag(0)
                Text("Ana Sunucu").tag(1)
                Text("ND2").tag(2)
                Text("Özet").tag(3)
            }.pickerStyle(.segmented).padding(.horizontal, 14).padding(.vertical, 8)

            if yukl {
                Spacer()
                ProgressView("Tüm sistem sorgulanıyor…\n(sıralı, ~10 sn)").multilineTextAlignment(.center).padding(40)
                Spacer()
            } else {
                ScrollView {
                    switch sekme {
                    case 0: OturumlarTab(veri: veri, komutOturum: $komutOturum, komutMetin: $komutMetin, komutSonuc: $komutSonuc, ekranOturum: $ekranOturum, ekranIcerik: $ekranIcerik, api: api)
                    case 1: AnaSunucuTab(veri: veri)
                    case 2: ND2Tab(veri: veri)
                    default: KoorOzetTab(veri: veri)
                    }
                }
            }
        }
        .navigationTitle("Tam Koordinasyon")
        .navigationBarTitleDisplayMode(.large)
        .task { await yukle() }
        .refreshable { await yukle() }
    }
    func yukle() async {
        yukl = true
        veri = await api.tamKoordinasyon()
        yukl = false
    }
}

// MARK: Koordinasyon alt görünümler

struct OturumlarTab: View {
    let veri: [String:Any]
    @Binding var komutOturum: String
    @Binding var komutMetin: String
    @Binding var komutSonuc: String
    @Binding var ekranOturum: String
    @Binding var ekranIcerik: String
    let api: PanelAPI

    private var oturumlar: [[String:Any]] { veri["oturumlar"] as? [[String:Any]] ?? [] }
    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(oturumlar.enumerated()), id: \.offset) { _, o in
                OturumSatirK(o: o, onCmd: { otur in komutOturum = otur },
                             onEkran: { otur in
                    Task {
                        ekranOturum = otur
                        ekranIcerik = await api.claudeEkran(otur)
                    }
                })
            }
            // Komut gönder
            VStack(alignment: .leading, spacing: 8) {
                Text("Komut Gönder").font(.caption.bold()).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(komutOturum.isEmpty ? "oturum seçin ↑" : komutOturum)
                        .font(.caption).padding(6).background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
                    Spacer()
                }
                TextField("Komut yaz…", text: $komutMetin).font(.caption).padding(8)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
                Button {
                    guard !komutOturum.isEmpty && !komutMetin.isEmpty else { return }
                    Task {
                        let ok = await api.claudeCmd(komutOturum, komutMetin)
                        komutSonuc = ok ? "✓ Gönderildi" : "✗ Hata"
                        komutMetin = ""
                    }
                } label: { Text("Gönder").font(.caption.bold()).frame(maxWidth: .infinity).padding(8)
                    .background(komutOturum.isEmpty ? Color.secondary.opacity(0.3) : Color.blue, in: .rect(cornerRadius: 10))
                    .foregroundStyle(.white) }
                .disabled(komutOturum.isEmpty)
                if !komutSonuc.isEmpty { Text(komutSonuc).font(.caption).foregroundStyle(.green) }
            }.padding(12).background(.ultraThinMaterial, in: .rect(cornerRadius: 14)).padding(.horizontal)
            // Ekran görüntüsü
            if !ekranIcerik.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Ekran: \(ekranOturum)").font(.caption.bold()).foregroundStyle(.secondary)
                        Spacer()
                        Button("Kapat") { ekranIcerik = "" }.font(.caption).foregroundStyle(.secondary)
                    }
                    ScrollView(.vertical) {
                        Text(ekranIcerik).font(.system(size: 10, design: .monospaced)).foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 200)
                }.padding(12).background(.ultraThinMaterial, in: .rect(cornerRadius: 14)).padding(.horizontal)
            }
        }.padding(.vertical, 8)
    }
}

struct OturumSatirK: View {
    let o: [String:Any]
    let onCmd: (String) -> Void
    let onEkran: (String) -> Void
    private var isim: String { o["isim"] as? String ?? "" }
    private var aktif: Bool { o["aktif"] as? Bool ?? false }
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(aktif ? Color.green : Color.red).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(isim).font(.subheadline.bold())
                Text(o["rol"] as? String ?? "").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                if let son = o["son"] as? String, !son.isEmpty {
                    Text(son).font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            Spacer()
            if aktif {
                HStack(spacing: 6) {
                    Button { onEkran(isim) } label: {
                        Image(systemName: "rectangle.on.rectangle").font(.caption2).foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                    Button { onCmd(isim) } label: {
                        Image(systemName: "chevron.right.square").font(.caption2).foregroundStyle(.blue)
                    }.buttonStyle(.plain)
                }
            }
        }.padding(.horizontal, 14).padding(.vertical, 9)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12)).padding(.horizontal)
    }
}

struct AnaSunucuTab: View {
    let veri: [String:Any]
    private var gruplar: [[String:Any]] { veri["ana_sunucu"] as? [[String:Any]] ?? [] }
    private var kaynak: [String:Any] { veri["ana_kaynak"] as? [String:Any] ?? [:] }
    var body: some View {
        VStack(spacing: 10) {
            // Kaynak özeti
            HStack(spacing: 0) {
                MetriKutu(ikon: "memorychip", baslik: "RAM", deger: kaynak["ram"] as? String ?? "?", renk: .blue)
                MetriKutu(ikon: "internaldrive", baslik: "/", deger: kaynak["disk"] as? String ?? "?", renk: .orange)
                MetriKutu(ikon: "externaldrive", baslik: "/opt", deger: kaynak["disk_opt"] as? String ?? "?", renk: .purple)
                MetriKutu(ikon: "cpu", baslik: "Load", deger: kaynak["load"] as? String ?? "?", renk: .green)
            }.padding(10).background(.ultraThinMaterial, in: .rect(cornerRadius: 14)).padding(.horizontal)
            // Servis grupları
            ForEach(Array(gruplar.enumerated()), id: \.offset) { _, g in
                let servisler = g["servisler"] as? [[String:Any]] ?? []
                VStack(alignment: .leading, spacing: 4) {
                    Text(g["grup"] as? String ?? "").font(.caption.bold()).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(Array(servisler.enumerated()), id: \.offset) { _, s in
                            HStack(spacing: 6) {
                                Circle().fill(servisDurum(s["durum"] as? String ?? "")).frame(width: 7, height: 7)
                                Text(servisKısa(s["isim"] as? String ?? "")).font(.system(size: 10)).lineLimit(1)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }.padding(10).background(.ultraThinMaterial, in: .rect(cornerRadius: 12)).padding(.horizontal)
            }
        }.padding(.vertical, 8)
    }
    private func servisDurum(_ d: String) -> Color { d == "active" ? .green : d == "inactive" ? .orange : .red }
    private func servisKısa(_ s: String) -> String { s.replacingOccurrences(of: ".service", with: "") }
}

struct ND2Tab: View {
    let veri: [String:Any]
    private var nd2: [String:Any] { veri["nd2"] as? [String:Any] ?? [:] }
    private var containers: [[String:Any]] { nd2["containers"] as? [[String:Any]] ?? [] }
    var body: some View {
        VStack(spacing: 10) {
            let erisim = nd2["erisim"] as? String ?? "?"
            HStack(spacing: 8) {
                Circle().fill(erisim == "ok" ? Color.green : Color.red).frame(width: 10, height: 10)
                Text("NickDegs2 (10.99.0.2)").font(.subheadline.bold())
                Spacer()
                Text(erisim == "ok" ? "Bağlı" : "Ulaşılamıyor").font(.caption).foregroundStyle(erisim == "ok" ? .green : .red)
            }.padding(12).background(.ultraThinMaterial, in: .rect(cornerRadius: 14)).padding(.horizontal)

            if erisim == "ok" {
                HStack(spacing: 0) {
                    MetriKutu(ikon: "memorychip", baslik: "RAM", deger: nd2["ram"] as? String ?? "?", renk: .blue)
                    MetriKutu(ikon: "cpu", baslik: "Load", deger: nd2["load"] as? String ?? "?", renk: .green)
                    MetriKutu(ikon: "shippingbox", baslik: "Cont.", deger: nd2["container"] as? String ?? "?", renk: .purple)
                    MetriKutu(ikon: "externaldrive", baslik: "/opt", deger: nd2["disk"] as? String ?? "?", renk: .orange)
                }.padding(10).background(.ultraThinMaterial, in: .rect(cornerRadius: 14)).padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Medya Container'ları").font(.caption.bold()).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                        ForEach(Array(containers.enumerated()), id: \.offset) { _, c in
                            HStack(spacing: 6) {
                                Circle().fill(nd2ContRenk(c["durum"] as? String ?? "")).frame(width: 7, height: 7)
                                Text(c["isim"] as? String ?? "").font(.system(size: 10)).lineLimit(1)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }.padding(10).background(.ultraThinMaterial, in: .rect(cornerRadius: 12)).padding(.horizontal)
            }
        }.padding(.vertical, 8)
    }
    private func nd2ContRenk(_ d: String) -> Color { d.hasPrefix("Up") ? .green : .red }
}

struct KoorOzetTab: View {
    let veri: [String:Any]
    private var odeme: [String:Any] { veri["odeme"] as? [String:Any] ?? [:] }
    private var meta: [String:Any] { veri["meta"] as? [String:Any] ?? [:] }
    private var oturumlar: [[String:Any]] { veri["oturumlar"] as? [[String:Any]] ?? [] }
    private var aktifOturum: Int { oturumlar.filter { $0["aktif"] as? Bool == true }.count }
    var body: some View {
        VStack(spacing: 12) {
            // Oturum özeti
            HStack(spacing: 0) {
                MetriKutu(ikon: "terminal.fill", baslik: "Aktif", deger: "\(aktifOturum)/\(oturumlar.count)", renk: .green)
                MetriKutu(ikon: "person.fill.checkmark", baslik: "Üye", deger: "\(odeme["aktif_uye"] as? Int ?? 0)", renk: .blue)
                MetriKutu(ikon: "turkishlirasign.circle", baslik: "Bugün", deger: String(format: "$%.2f", odeme["bugun_gelir"] as? Double ?? 0), renk: .orange)
                MetriKutu(ikon: "megaphone", baslik: "Meta ₺", deger: String(format: "%.0f", meta["harcama"] as? Double ?? 0), renk: .red)
            }.padding(10).background(.ultraThinMaterial, in: .rect(cornerRadius: 14)).padding(.horizontal)

            // Aktif Claude oturumları listesi
            let aktifler = oturumlar.filter { $0["aktif"] as? Bool == true }
            VStack(alignment: .leading, spacing: 6) {
                Text("Aktif Claude Oturumları (\(aktifler.count))").font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(Array(aktifler.enumerated()), id: \.offset) { _, o in
                    HStack(spacing: 8) {
                        Circle().fill(Color.green).frame(width: 7, height: 7)
                        Text(o["isim"] as? String ?? "").font(.caption.bold()).foregroundStyle(.primary)
                        Text(o["rol"] as? String ?? "").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }.padding(12).background(.ultraThinMaterial, in: .rect(cornerRadius: 12)).padding(.horizontal)

            // Meta özet
            if !(meta.isEmpty) {
                HStack(spacing: 0) {
                    MetriKutu(ikon: "eye", baslik: "Gösterim", deger: fmtN(meta["gosterim"] as? Int ?? 0), renk: .blue)
                    MetriKutu(ikon: "cursorarrow.click", baslik: "Tıklama", deger: fmtN(meta["tiklama"] as? Int ?? 0), renk: .green)
                    MetriKutu(ikon: "turkishlirasign.circle", baslik: "Harcama", deger: String(format: "₺%.0f", meta["harcama"] as? Double ?? 0), renk: .red)
                }.padding(10).background(.ultraThinMaterial, in: .rect(cornerRadius: 14)).padding(.horizontal)
            }
        }.padding(.vertical, 8)
    }
    private func fmtN(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000) :
        n >= 1_000 ? String(format: "%.1fK", Double(n)/1_000) : "\(n)"
    }
}

// MARK: - Satın Aldıklarım (işletme sahibi — panel + güvenlik + hush)

struct SatinAldiklarimNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var veri: [String:Any] = [:]
    @State private var yukl = true
    @State private var hata = ""
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ScrollView {
            if yukl { ProgressView("Yükleniyor…").padding(40) }
            else if !hata.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
                    Text(hata).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(30)
            } else {
                VStack(spacing: 14) {
                    Text("Satın aldığın hizmetlerin bağlantı bilgileri aşağıda. Ekran görüntüsü al veya kopyala.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .padding(.horizontal).padding(.top, 4)

                    // İşletme Paneli
                    if let isl = veri["isletme"] as? [String:Any], !isl.isEmpty {
                        PaketKarti(
                            ikon: "storefront.fill", baslik: "İşletme Paneli",
                            renk: .blue, aktif: isl["aktif"] as? Bool ?? false,
                            bitis: isl["bitis"] as? Int ?? 0
                        ) {
                            BilgiSatiri(etiket: "Panel Adresi", deger: isl["panel_url"] as? String ?? "")
                            BilgiSatiri(etiket: "Kullanıcı Adı", deger: isl["kadi"] as? String ?? "")
                            BilgiSatiri(etiket: "Şifre", deger: isl["sifre"] as? String ?? "", gizle: true)
                            BilgiSatiri(etiket: "Dashboard Kodu", deger: isl["dashboard_kod"] as? String ?? "")
                            BilgiSatiri(etiket: "Not", deger: "NickDegs Dashboard uygulamasına bu kodla ve SMS ile giriş yapabilirsin.")
                        }
                    } else {
                        BosPaket(ikon: "storefront", baslik: "İşletme Paneli", mesaj: "Henüz işletme paneli satın alınmadı")
                    }

                    // Güvenlik Paketi
                    if let guv = veri["guvenlik"] as? [String:Any], !guv.isEmpty {
                        PaketKarti(
                            ikon: "lock.shield.fill", baslik: "Güvenlik Paketi",
                            renk: .green, aktif: guv["aktif"] as? Bool ?? false,
                            bitis: guv["bitis"] as? Int ?? 0
                        ) {
                            BilgiSatiri(etiket: "Korunan Adres", deger: guv["guvenlik_url"] as? String ?? "")
                            BilgiSatiri(etiket: "Koruma", deger: "Cloudflare WAF + DDoS koruması aktif")
                        }
                    } else {
                        BosPaket(ikon: "lock.shield", baslik: "Güvenlik Paketi", mesaj: "Güvenlik paketi eklenmedi")
                    }

                    // Hush Chat
                    if let hsh = veri["hush"] as? [String:Any], !hsh.isEmpty {
                        PaketKarti(
                            ikon: "bubble.left.and.bubble.right.fill", baslik: "Hush Chat",
                            renk: .purple, aktif: hsh["aktif"] as? Bool ?? false,
                            bitis: hsh["bitis"] as? Int ?? 0
                        ) {
                            BilgiSatiri(etiket: "Sohbet Adresi", deger: hsh["hush_url"] as? String ?? "")
                            BilgiSatiri(etiket: "Kullanıcı ID", deger: hsh["hush_uid"] as? String ?? "")
                            BilgiSatiri(etiket: "Şifre", deger: hsh["sifre"] as? String ?? "", gizle: true)
                            BilgiSatiri(etiket: "Not", deger: "Hush uygulamasına bu bilgilerle giriş yap")
                        }
                    } else {
                        BosPaket(ikon: "bubble.left.and.bubble.right", baslik: "Hush Chat", mesaj: "Hush chat paketi eklenmedi")
                    }
                }.padding(.vertical, 8)
            }
        }
        .navigationTitle("Satın Aldıklarım")
        .navigationBarTitleDisplayMode(.large)
        .task { await yukle() }
        .refreshable { await yukle() }
    }
    func yukle() async {
        yukl = true; hata = ""
        let d = await api.satinAldiklarim()
        if d["ok"] as? Bool == false { hata = d["mesaj"] as? String ?? "Veri alınamadı" }
        else { veri = d }
        yukl = false
    }
}

struct PaketKarti<C: View>: View {
    let ikon: String; let baslik: String; let renk: Color
    let aktif: Bool; let bitis: Int
    @ViewBuilder let icerik: () -> C
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: ikon).font(.system(size: 20)).foregroundStyle(renk)
                Text(baslik).font(.subheadline.bold())
                Spacer()
                Label(aktif ? "Aktif" : "Süresi doldu", systemImage: aktif ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2.bold()).foregroundStyle(aktif ? .green : .red)
            }
            if bitis > 0 {
                Text("Bitiş: \(Date(timeIntervalSince1970: TimeInterval(bitis)), style: .date)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Divider()
            icerik()
        }.padding(14).background(.ultraThinMaterial, in: .rect(cornerRadius: 16)).padding(.horizontal)
    }
}

struct BilgiSatiri: View {
    let etiket: String; let deger: String; var gizle: Bool = false
    @State private var goster = false
    var body: some View {
        if deger.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(etiket).font(.caption2).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    if gizle && !goster {
                        Text(String(repeating: "•", count: min(deger.count, 12))).font(.subheadline.bold()).foregroundStyle(.primary)
                        Button { goster = true } label: {
                            Image(systemName: "eye").font(.caption).foregroundStyle(.secondary)
                        }.buttonStyle(.plain)
                    } else {
                        Text(deger).font(.subheadline.bold()).foregroundStyle(.primary).textSelection(.enabled)
                        if gizle {
                            Button { goster = false } label: {
                                Image(systemName: "eye.slash").font(.caption).foregroundStyle(.secondary)
                            }.buttonStyle(.plain)
                        }
                        Button {
                            UIPasteboard.general.string = deger
                        } label: {
                            Image(systemName: "doc.on.doc").font(.caption).foregroundStyle(.secondary)
                        }.buttonStyle(.plain)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct BosPaket: View {
    let ikon: String; let baslik: String; let mesaj: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: ikon).font(.system(size: 20)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(baslik).font(.subheadline.bold()).foregroundStyle(.secondary)
                Text(mesaj).font(.caption2).foregroundStyle(.tertiary)
            }
        }.padding(14).background(.ultraThinMaterial.opacity(0.5), in: .rect(cornerRadius: 14)).padding(.horizontal)
    }
}
