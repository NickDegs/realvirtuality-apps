import SwiftUI
import UniformTypeIdentifiers

struct PaylasURL: Identifiable { let id = UUID(); let url: URL }
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Hukuk Bürosu paneli (hukuk-sistem) — dava/süre/duruşma/müvekkil/belge
struct HukukPanel: View {
    @ObservedObject var api: PanelAPI
    @EnvironmentObject var tema: Tema
    @State private var sekme = 0

    @State private var sDava = 0
    @State private var sMuvekkil = 0
    @State private var sAcil = 0
    @State private var sDurusma = 0
    @State private var davalar: [[String: Any]] = []
    @State private var sureler: [[String: Any]] = []
    @State private var durusmalar: [[String: Any]] = []
    @State private var muvekkiller: [[String: Any]] = []
    @State private var belgeler: [[String: Any]] = []
    // formlar
    @State private var dBaslik = ""
    @State private var dKarsi = ""
    @State private var dMahkeme = ""
    @State private var dTur = ""
    @State private var suTur = ""
    @State private var suSon = ""
    @State private var duTarih = ""
    @State private var duSaat = ""
    @State private var duSalon = ""
    @State private var mvAd = ""
    @State private var mvTel = ""
    @State private var mvEmail = ""
    // bağlama seçimleri
    @State private var dMuvekkilId = 0
    @State private var dMuvekkilAd = ""
    @State private var suDavaId = 0
    @State private var suDavaAd = ""
    @State private var duDavaId = 0
    @State private var duDavaAd = ""
    @State private var bDavaId = 0
    @State private var bDavaAd = ""
    @State private var belgeImport = false
    @State private var paylas: PaylasURL?

    static let asamalar = ["Açıldı", "Devam ediyor", "Karar aşaması", "Kapandı"]
    static func seviyeRenk(_ s: String) -> Color {
        switch s { case "kirmizi": return .red; case "turuncu": return .orange
        case "sari": return .yellow; case "yesil": return .green; default: return .gray }
    }
    let sekmeler = [("Özet", "chart.bar.fill"), ("Davalar", "folder.fill"), ("Süreler", "alarm.fill"),
                    ("Duruşmalar", "building.columns.fill"), ("Müvekkiller", "person.crop.circle"),
                    ("Belgeler", "doc.fill"), ("Personel", "person.2.fill"), ("Ayar", "gearshape.fill")]

    var body: some View {
        VStack(spacing: 0) {
            PanelChips(sekmeler: sekmeler, secili: $sekme, tema: tema)
            switch sekme {
            case 0: ozet
            case 1: davaTab
            case 2: sureTab
            case 3: durusmaTab
            case 4: muvekkilTab
            case 5: belgeTab
            case 6: PersonelSekmesi(api: api, tema: tema)
            default: AyarSekmesi(api: api, tema: tema)
            }
        }.task { await yenile(); while !Task.isCancelled { try? await Task.sleep(nanoseconds: 25_000_000_000); await yenile() } }
    }

    func yenile() async {
        let s = await api.getObj("stats")
        sDava = s["dava"] as? Int ?? 0; sMuvekkil = s["muvekkil"] as? Int ?? 0
        sAcil = s["acil"] as? Int ?? 0; sDurusma = s["durusma"] as? Int ?? 0
        davalar = await api.getArr("davalar")
        sureler = await api.getArr("sureler")
        durusmalar = await api.getArr("durusmalar")
        muvekkiller = await api.getArr("muvekkiller")
        belgeler = await api.getArr("belgeler")
    }

    func muvekkilSecici(_ secId: Binding<Int>, _ secAd: Binding<String>) -> some View {
        Menu {
            Button("(Müvekkil bağlama yok)") { secId.wrappedValue = 0; secAd.wrappedValue = "" }
            ForEach(Array(muvekkiller.enumerated()), id: \.offset) { _, m in
                Button(m["ad"] as? String ?? "-") { secId.wrappedValue = m["id"] as? Int ?? 0; secAd.wrappedValue = m["ad"] as? String ?? "" }
            }
        } label: { secLabel(secAd.wrappedValue, "Müvekkil bağla (ops.)") }
    }
    func davaSecici(_ secId: Binding<Int>, _ secAd: Binding<String>) -> some View {
        Menu {
            Button("(Dava bağlama yok)") { secId.wrappedValue = 0; secAd.wrappedValue = "" }
            ForEach(Array(davalar.enumerated()), id: \.offset) { _, d in
                Button(d["baslik"] as? String ?? "-") { secId.wrappedValue = d["id"] as? Int ?? 0; secAd.wrappedValue = d["baslik"] as? String ?? "" }
            }
        } label: { secLabel(secAd.wrappedValue, "Dava bağla (ops.)") }
    }
    func secLabel(_ ad: String, _ bos: String) -> some View {
        HStack {
            Image(systemName: "link"); Text(ad.isEmpty ? bos : ad).lineLimit(1)
            Spacer(); Image(systemName: "chevron.down")
        }.font(.caption).foregroundStyle(.rvMut).padding(8).frame(maxWidth: .infinity).background(Color.rvBg, in: .rect(cornerRadius: 9))
    }

    var ozet: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    panelKpi("Açık Dava", "\(sDava)", "folder.fill", .blue)
                    panelKpi("Müvekkil", "\(sMuvekkil)", "person.2.fill", .green)
                }
                HStack(spacing: 12) {
                    panelKpi("Acil Süre", "\(sAcil)", "alarm.fill", .red)
                    panelKpi("Duruşma", "\(sDurusma)", "building.columns.fill", .purple)
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    var davaTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text("Dava Ekle").font(.subheadline.bold()).foregroundStyle(.rvText)
                    TextField("Dava başlığı", text: $dBaslik).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    HStack {
                        TextField("Karşı taraf", text: $dKarsi).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                        TextField("Tür", text: $dTur).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    }
                    TextField("Mahkeme", text: $dMahkeme).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    muvekkilSecici($dMuvekkilId, $dMuvekkilAd)
                    Button { Task { await davaEkle() } } label: {
                        Text("Ekle").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                    }.disabled(dBaslik.isEmpty)
                }
                ForEach(Array(davalar.enumerated()), id: \.offset) { _, d in
                    let id = d["id"] as? Int ?? 0
                    let asama = d["asama"] as? String ?? ""
                    panelKart {
                        Text(d["baslik"] as? String ?? "-").font(.subheadline.bold()).foregroundStyle(.rvText)
                        Text("\(d["muvekkil"] as? String ?? "") · \(d["mahkeme"] as? String ?? "")").font(.caption2).foregroundStyle(.rvMut)
                        HStack {
                            Menu {
                                ForEach(Self.asamalar, id: \.self) { a in
                                    Button(a) { Task { _ = await api.post("dava/\(id)/asama", ["asama": a]); await yenile() } }
                                }
                            } label: {
                                Text(asama.isEmpty ? "Aşama seç" : asama).font(.caption.bold()).foregroundStyle(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 6).background(tema.grad, in: .capsule)
                            }
                            Spacer()
                            Button { Task { _ = await api.post("dava/\(id)/delete"); await yenile() } } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    var sureTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text("Süre / Termin Ekle").font(.subheadline.bold()).foregroundStyle(.rvText)
                    HStack {
                        TextField("Tür (ör. Cevap Dilekçesi)", text: $suTur).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                        TextField("2026-07-15", text: $suSon).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    }
                    davaSecici($suDavaId, $suDavaAd)
                    Button { Task { await sureEkle() } } label: {
                        Text("Ekle").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                    }.disabled(suTur.isEmpty || suSon.isEmpty)
                }
                ForEach(Array(sureler.enumerated()), id: \.offset) { _, s in
                    let id = s["id"] as? Int ?? 0
                    let seviye = s["seviye"] as? String ?? "yesil"
                    let kalan = s["kalan"] as? Int ?? 0
                    let bitti = (s["durum"] as? String ?? "") == "Tamamlandı"
                    panelKart {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s["tur"] as? String ?? "-").font(.subheadline.bold()).foregroundStyle(.rvText)
                                Text("\(s["son"] as? String ?? "") · \(s["dava"] as? String ?? "")").font(.caption2).foregroundStyle(.rvMut)
                            }
                            Spacer()
                            if bitti {
                                Text("✔️").font(.caption)
                            } else {
                                Text(kalan < 0 ? "\(-kalan)g geçti" : "\(kalan)g").font(.caption.bold())
                                    .foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 5)
                                    .background(Self.seviyeRenk(seviye), in: .capsule)
                            }
                        }
                        if !bitti {
                            Button { Task { _ = await api.post("sure/\(id)/tamam"); await yenile() } } label: {
                                Text("Tamamlandı işaretle").font(.caption.bold()).foregroundStyle(.green)
                                    .frame(maxWidth: .infinity).padding(.vertical, 7).background(Color.green.opacity(0.12), in: .rect(cornerRadius: 9))
                            }
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    var durusmaTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text("Duruşma Ekle").font(.subheadline.bold()).foregroundStyle(.rvText)
                    HStack {
                        TextField("2026-07-20", text: $duTarih).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                        TextField("10:30", text: $duSaat).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    }
                    TextField("Salon / mahkeme", text: $duSalon).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    davaSecici($duDavaId, $duDavaAd)
                    Button { Task { await durusmaEkle() } } label: {
                        Text("Ekle").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                    }.disabled(duTarih.isEmpty)
                }
                ForEach(Array(durusmalar.enumerated()), id: \.offset) { _, d in
                    let id = d["id"] as? Int ?? 0
                    panelKart {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(d["tarih"] as? String ?? "") \(d["saat"] as? String ?? "")").font(.subheadline.bold()).foregroundStyle(.rvText)
                                Text("\(d["salon"] as? String ?? "") · \(d["dava"] as? String ?? "")").font(.caption2).foregroundStyle(.rvMut)
                            }
                            Spacer()
                            Button { Task { _ = await api.post("durusma/\(id)/delete"); await yenile() } } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    var muvekkilTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text("Müvekkil Ekle").font(.subheadline.bold()).foregroundStyle(.rvText)
                    TextField("Ad soyad", text: $mvAd).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    HStack {
                        TextField("Telefon", text: $mvTel).keyboardType(.phonePad).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                        TextField("E-posta", text: $mvEmail).keyboardType(.emailAddress).textInputAutocapitalization(.never).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    }
                    Button { Task { _ = await api.post("muvekkil", ["ad": mvAd, "telefon": mvTel, "email": mvEmail]); mvAd = ""; mvTel = ""; mvEmail = ""; await yenile() } } label: {
                        Text("Ekle").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                    }.disabled(mvAd.isEmpty)
                }
                ForEach(Array(muvekkiller.enumerated()), id: \.offset) { _, m in
                    let id = m["id"] as? Int ?? 0
                    panelKart {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m["ad"] as? String ?? "-").font(.subheadline.bold()).foregroundStyle(.rvText)
                                Text(m["telefon"] as? String ?? "").font(.caption2).foregroundStyle(.rvMut)
                            }
                            Spacer()
                            Button { Task { _ = await api.post("muvekkil/\(id)/delete"); await yenile() } } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    var belgeTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text("Belge Yükle (şifreli kasa)").font(.subheadline.bold()).foregroundStyle(.rvText)
                    davaSecici($bDavaId, $bDavaAd)
                    Button { belgeImport = true } label: {
                        Label("Dosya Seç & Yükle", systemImage: "doc.badge.plus").font(.caption.bold()).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                    }
                    Text("Dosyalar AES ile şifreli saklanır. Dokununca indirip paylaşabilirsin.").font(.caption2).foregroundStyle(.rvMut)
                }
                if belgeler.isEmpty { Text("Belge yok").foregroundStyle(.rvMut).padding(.top, 20) }
                ForEach(Array(belgeler.enumerated()), id: \.offset) { _, b in
                    let id = b["id"] as? Int ?? 0
                    let ad = b["ad"] as? String ?? "belge"
                    Button { Task { if let u = await api.indir("belge/\(id)/indir", adKaydet: ad) { paylas = PaylasURL(url: u) } } } label: {
                        panelKart {
                            HStack {
                                Image(systemName: "doc.fill").foregroundStyle(tema.c1)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ad).font(.subheadline.bold()).foregroundStyle(.rvText)
                                    Text("\(b["tur"] as? String ?? "") · \(b["dava"] as? String ?? "")").font(.caption2).foregroundStyle(.rvMut)
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.down").foregroundStyle(.rvMut)
                            }
                        }
                    }
                }
            }.padding()
        }
        .refreshable { await yenile() }
        .fileImporter(isPresented: $belgeImport, allowedContentTypes: [.pdf, .image, .plainText, .data]) { res in
            if case .success(let url) = res { Task { await belgeYukle(url) } }
        }
        .sheet(item: $paylas) { p in ActivityView(items: [p.url]) }
    }

    func davaEkle() async {
        var body: [String: Any] = ["baslik": dBaslik, "karsi": dKarsi, "mahkeme": dMahkeme, "tur": dTur]
        if dMuvekkilId > 0 { body["muvekkil_id"] = dMuvekkilId }
        _ = await api.post("dava", body)
        dBaslik = ""; dKarsi = ""; dMahkeme = ""; dTur = ""; dMuvekkilId = 0; dMuvekkilAd = ""
        await yenile()
    }
    func sureEkle() async {
        var body: [String: Any] = ["tur": suTur, "son": suSon]
        if suDavaId > 0 { body["dava_id"] = suDavaId }
        _ = await api.post("sure", body)
        suTur = ""; suSon = ""; suDavaId = 0; suDavaAd = ""
        await yenile()
    }
    func durusmaEkle() async {
        var body: [String: Any] = ["tarih": duTarih, "saat": duSaat, "salon": duSalon]
        if duDavaId > 0 { body["dava_id"] = duDavaId }
        _ = await api.post("durusma", body)
        duTarih = ""; duSaat = ""; duSalon = ""; duDavaId = 0; duDavaAd = ""
        await yenile()
    }
    func belgeYukle(_ url: URL) async {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let d = try? Data(contentsOf: url) else { return }
        var extra: [String: String] = ["tur": "Belge"]
        if bDavaId > 0 { extra["dava_id"] = String(bDavaId) }
        let mime = url.pathExtension.lowercased() == "pdf" ? "application/pdf" : "application/octet-stream"
        _ = await api.upload("belge", field: "file", filename: url.lastPathComponent, mime: mime, fileData: d, extra: extra)
        bDavaId = 0; bDavaAd = ""
        await yenile()
    }
}
