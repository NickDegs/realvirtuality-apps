import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - QR Kod Üretici (CoreImage — ağ bağlantısı yok)
struct QRNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var metin = ""
    @State private var qrUI: UIImage? = nil
    @State private var yukl = true
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let img = qrUI {
                    Image(uiImage: img)
                        .interpolation(.none).resizable().scaledToFit()
                        .frame(width: 240, height: 240)
                        .padding(12).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16)).shadow(radius: 6)
                    ShareLink(item: Image(uiImage: img), preview: SharePreview("QR Kod", image: Image(uiImage: img))) {
                        Label("Paylaş / Kaydet", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    RoundedRectangle(cornerRadius: 16).fill(Color.secondary.opacity(0.12))
                        .frame(width: 240, height: 240)
                        .overlay {
                            if yukl { ProgressView() }
                            else { Image(systemName: "qrcode").font(.system(size: 60)).foregroundStyle(.secondary) }
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("QR Bağlantısı").font(.caption).foregroundStyle(.secondary)
                    TextField("URL veya metin girin", text: $metin, axis: .vertical)
                        .textFieldStyle(.roundedBorder).textContentType(.URL)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .onChange(of: metin) { _, _ in uret() }
                    HStack {
                        Spacer()
                        Button("Temizle") { metin = ""; qrUI = nil }.font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 24)
        }
        .navigationTitle("QR Kod")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let info = await api.bizInfo(), let site = info["site_url"] as? String, !site.isEmpty {
                metin = site; uret()
            }
            yukl = false
        }
    }

    func uret() {
        guard !metin.trimmingCharacters(in: .whitespaces).isEmpty else { qrUI = nil; return }
        let ctx = CIContext()
        let f = CIFilter.qrCodeGenerator()
        f.setValue(Data(metin.utf8), forKey: "inputMessage")
        f.setValue("M", forKey: "inputCorrectionLevel")
        guard let ci = f.outputImage else { return }
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return }
        qrUI = UIImage(cgImage: cg)
    }
}

// MARK: - Görevlerim (çalışan / işletme görev listesi — GorevlerTab'ı sarıp gösterir)
struct GorevlerimNative: View {
    @EnvironmentObject var oturum: Oturum
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    var body: some View {
        GorevlerTab(api: api)
            .navigationTitle("Görevlerim")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sayfam (işletme web sitesi)
struct SitemNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var siteURL = ""
    @State private var ad = ""
    @State private var yukl = true
    @State private var kopyalandi = false
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    private func qrImage(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.correctionLevel = "M"
        filter.message = Data(text.utf8)
        guard let ci = filter.outputImage else { return nil }
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        return UIImage(ciImage: scaled)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if yukl {
                    ProgressView().padding(60)
                } else {
                    Image(systemName: "globe").font(.system(size: 48)).foregroundStyle(.blue).padding(.top, 8)
                    Text(ad.isEmpty ? "İşletme Sayfanız" : ad).font(.title2.bold())

                    if siteURL.isEmpty {
                        Text("Henüz işletme sayfanız bağlanmamış.\nYönetici ile iletişime geçin.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
                    } else {
                        VStack(spacing: 16) {
                            // Native QR Kod
                            if let img = qrImage(siteURL) {
                                Image(uiImage: img).interpolation(.none).resizable()
                                    .scaledToFit().frame(width: 200, height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(8).background(Color.white, in: .rect(cornerRadius: 16))
                            }

                            Text(siteURL).font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).textSelection(.enabled).padding(.horizontal)

                            Button {
                                UIPasteboard.general.string = siteURL
                                kopyalandi = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { kopyalandi = false }
                            } label: {
                                Label(kopyalandi ? "Kopyalandı!" : "URL'yi Kopyala", systemImage: kopyalandi ? "checkmark" : "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).padding(.horizontal)

                            Text("QR kodu ekrana gösterin veya URL'yi paylaşın.\nMüşterileriniz doğrudan sitenize ulaşır.")
                                .font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center).padding(.horizontal)
                        }
                        .padding().background(Color.secondary.opacity(0.07), in: .rect(cornerRadius: 16)).padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Sayfam")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let info = await api.bizInfo() {
                siteURL = info["site_url"] as? String ?? ""
                ad = info["ad"] as? String ?? ""
            }
            yukl = false
        }
    }
}

// MARK: - İşletme Ayarları
struct AyarlarNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var info: [String:Any] = [:]
    @State private var yukl = true
    @State private var kopyalandi = false
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if yukl {
                    ProgressView().padding(60)
                } else {
                    Image(systemName: "gearshape.2.fill").font(.system(size: 44)).foregroundStyle(.purple).padding(.top, 8)
                    Text("İşletme Bilgileri").font(.title2.bold())

                    VStack(spacing: 0) {
                        if let v = info["ad"] as? String, !v.isEmpty { satir("İşletme Adı", v) }
                        if let v = info["slug"] as? String, !v.isEmpty { satir("Slug", v) }
                        if let v = info["sektor"] as? String, !v.isEmpty { satir("Sektör", v) }
                        if let v = info["site_url"] as? String, !v.isEmpty { satir("Site URL", v) }
                        if let v = info["did"] as? String, !v.isEmpty { satir("Tenant ID", v) }
                    }
                    .background(Color.secondary.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    Text("Gelişmiş ayarlar için sektör panelinizi veya yöneticinizi kullanın.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)

                    Divider().padding(.horizontal)

                    HStack(spacing: 16) {
                        Link("Gizlilik Politikası", destination: URL(string: "https://nickdegs.com/legal/privacy")!)
                            .font(.caption).foregroundStyle(.purple)
                        Text("·").foregroundStyle(.secondary).font(.caption)
                        Link("Kullanım Koşulları", destination: URL(string: "https://nickdegs.com/kosullar")!)
                            .font(.caption).foregroundStyle(.purple)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        .task { info = (await api.bizInfo()) ?? [:]; yukl = false }
    }

    func satir(_ etiket: String, _ deger: String) -> some View {
        HStack(spacing: 10) {
            Text(etiket).font(.subheadline).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
            Text(deger).font(.subheadline).foregroundStyle(.primary).lineLimit(1)
            Spacer()
            Button { UIPasteboard.general.string = deger } label: {
                Image(systemName: "doc.on.doc").foregroundStyle(.secondary).font(.caption)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .overlay(Divider(), alignment: .bottom)
    }
}

// MARK: - Kampanya / Kuponlar
struct KampanyaNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var kuponlar: [[String:Any]] = []
    @State private var yukl = true
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if yukl {
                    ProgressView().padding(60)
                } else if kuponlar.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tag.slash").font(.system(size: 44)).foregroundStyle(.orange).padding(.top, 20)
                        Text("Aktif Kampanya Yok").font(.title3.bold())
                        Text("Sistem genelindeki kuponlar ve kampanyalar burada görünür.\nYeni kampanya oluşturmak için yönetici ile iletişime geçin.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    }
                } else {
                    ForEach(Array(kuponlar.enumerated()), id: \.offset) { _, k in
                        kuponSatiri(k)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Kampanyalar")
        .navigationBarTitleDisplayMode(.inline)
        .task { kuponlar = await api.getArr("/dash/aapi/coupons"); yukl = false }
    }

    func kuponSatiri(_ k: [String:Any]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "tag.fill").font(.title2).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(k["kod"] as? String ?? "—").font(.subheadline.bold().monospaced())
                HStack(spacing: 6) {
                    if let tip = k["tip"] as? String, let val = k["deger"] as? Int {
                        Text(tip == "yuzde" ? "% \(val) indirim" : "₺\(val) indirim")
                            .font(.caption).foregroundStyle(.green)
                    }
                    if let n = k["kullanim_sayisi"] as? Int { Text("· \(n) kullanım").font(.caption).foregroundStyle(.secondary) }
                }
            }
            Spacer()
            Button { UIPasteboard.general.string = k["kod"] as? String ?? "" } label: {
                Image(systemName: "doc.on.doc").foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Kanıt / Denetim Kaydı
struct KanitNative: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "shield.checkered").font(.system(size: 52)).foregroundStyle(.teal).padding(.top, 20)
                Text("Denetim Kaydı").font(.title2.bold())
                Text("İşletmenizin tüm işlemleri kanunen geçerli denetim kaydı olarak saklanır.\n\nKayıtlar; 15 dakikada bir hash zinciriyle imzalanır, değiştirilemez ve mahkemelerde delil olarak kullanılabilir.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)

                VStack(spacing: 10) {
                    ozet("lock.doc.fill", "Tamper-Evident Ledger", "Ed25519 imzalı JSONL zinciri", .teal)
                    ozet("clock.badge.checkmark", "Zaman Çıpası", "Her 15 dk otomatik imza", .blue)
                    ozet("doc.plaintext.fill", "PDF Rapor", "Talep üzerine resmi rapor", .purple)
                    ozet("bubble.left.and.bubble.right.fill", "Telegram Bildirim", "Her kayıt anında iletilir", .orange)
                }
                .padding(.horizontal)

                Text("Tam denetim raporu için yöneticinize başvurun.")
                    .font(.caption).foregroundStyle(.tertiary).padding(.top, 4)
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Kanıt Kaydı")
        .navigationBarTitleDisplayMode(.inline)
    }

    func ozet(_ ikon: String, _ baslik: String, _ alt: String, _ renk: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ikon).foregroundStyle(renk).font(.title3).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(baslik).font(.subheadline.bold())
                Text(alt).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Destek (Hush Şifreli Sohbet)
struct DestekNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var hushURL = ""
    @State private var matrixKullanici = ""
    @State private var aktif = false
    @State private var yukl = true
    @State private var kopyalandi = false
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "bubble.left.and.lock.fill").font(.system(size: 52)).foregroundStyle(.purple).padding(.top, 8)
                Text("Şifreli Destek").font(.title2.bold())
                Text("Hush — uçtan uca şifreli mesajlaşma altyapısı üzerinde çalışır.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)

                if yukl {
                    ProgressView()
                } else if hushURL.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.slash").foregroundStyle(.orange).font(.title)
                        Text("Destek sohbeti bu hesapta aktif değil.\nYöneticinizden etkinleştirmesini isteyin.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.padding()
                } else {
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: aktif ? "checkmark.circle.fill" : "clock.circle")
                                .foregroundStyle(aktif ? .green : .orange)
                            Text(aktif ? "Hush aktif" : "Abonelik doğrulanamadı").font(.subheadline)
                        }
                        .frame(maxWidth: .infinity).padding(12)
                        .background(Color.secondary.opacity(0.07), in: .rect(cornerRadius: 12))

                        if !matrixKullanici.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Matrix / Element Kullanıcı Adı").font(.caption2).foregroundStyle(.secondary)
                                Text(matrixKullanici).font(.subheadline.monospaced()).foregroundStyle(.primary).textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            .background(Color.secondary.opacity(0.07), in: .rect(cornerRadius: 12))
                        }

                        Button {
                            UIPasteboard.general.string = hushURL
                            kopyalandi = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { kopyalandi = false }
                        } label: {
                            Label(kopyalandi ? "Kopyalandı!" : "Destek Bağlantısını Kopyala", systemImage: kopyalandi ? "checkmark" : "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).padding(.horizontal)

                        Text("Kopyaladığınız linki Element uygulamasında veya web tarayıcınızda açın.")
                            .font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center).padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Destek")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let veri = await api.satinAldiklarim()
            if let hush = veri["hush"] as? [String:Any] {
                hushURL = hush["hush_url"] as? String ?? ""
                matrixKullanici = hush["uid"] as? String ?? ""
                aktif = hush["aktif"] as? Bool ?? false
            }
            yukl = false
        }
    }
}

// MARK: - Bağlan (çalışan paneli bağlantısı)
struct BaglanNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var link = ""
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "link.badge.plus").font(.system(size: 52)).foregroundStyle(.cyan)
            Text("Panel Bağlantısı").font(.title2.bold())
            Text("Bu özellik üzerinde çalışılıyor.\nYöneticinizden davet bağlantısı talep edebilirsiniz.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)

            if !link.isEmpty {
                VStack(spacing: 8) {
                    Text(link).font(.caption.monospaced()).foregroundStyle(.blue)
                    Button { UIPasteboard.general.string = link } label: {
                        Label("Kopyala", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.secondary.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            Spacer()
        }
        .navigationTitle("Bağlan")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Kişisel Hizmetler (süper admin) — tümü native ekrana yönlendirir
struct KisiselNative: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                kisiselSatir("person.crop.circle.fill", "Kişisel Panel", "Satın aldıklarım · abonelik durumu") { SatinAldiklarimNative() }
                kisiselSatir("film.stack.fill", "Medya", "Emby · Plex · IPTV yönetim") { MedyaNative() }
                kisiselSatir("waveform", "Seslendir (Piper)", "Türkçe TTS — metni sese çevir") { SeslendirNative() }
                kisiselSatir("photo.fill.on.rectangle.fill", "AI Görsel (FLUX)", "Yazıdan görsel üret") { GorselNative() }
                kisiselSatir("doc.text.magnifyingglass", "Hukuk Bürosu", "Dava takibi · şifreli belge kasası") { HukukNative() }
                kisiselSatir("bubble.left.and.bubble.right.fill", "Chat Logları", "Hush şifreli sohbet kayıtları") { ChatNative() }
                kisiselSatir("sparkles", "AI Stüdyo", "RealVirtuality yönetim / istatistik") { AistudioNative() }
                kisiselSatir("location.fill", "Traccar Konum", "Canlı araç/kişi takibi") { TraccarNative() }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Kişisel")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    func kisiselSatir<D: View>(_ ikon: String, _ ad: String, _ aciklama: String, @ViewBuilder hedef: () -> D) -> some View {
        NavigationLink(destination: hedef()) {
            HStack(spacing: 14) {
                Image(systemName: ikon).font(.title2).foregroundStyle(.purple).frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ad).font(.subheadline.bold()).foregroundStyle(.primary)
                    Text(aciklama).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.footnote)
            }
            .padding(14)
            .background(Color.secondary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }
}

// MARK: - Kurulu İşletmeler (süper admin)
struct IsNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var uyeler: [[String:Any]] = []
    @State private var ara = ""
    @State private var yukl = true
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    private var isletmeler: [[String:Any]] {
        let hepsi = uyeler.filter { ($0["rol"] as? String) == "business" }
        guard !ara.isEmpty else { return hepsi }
        let q = ara.lowercased()
        return hepsi.filter {
            ($0["ad"] as? String ?? "").lowercased().contains(q) ||
            ($0["slug"] as? String ?? "").lowercased().contains(q) ||
            ($0["tel"] as? String ?? "").contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("İşletme ara…", text: $ara).autocorrectionDisabled().textInputAutocapitalization(.never)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal).padding(.vertical, 8)

            if yukl {
                Spacer(); ProgressView(); Spacer()
            } else if isletmeler.isEmpty {
                Spacer()
                Text(ara.isEmpty ? "Kayıtlı işletme yok." : "Sonuç bulunamadı.").foregroundStyle(.secondary)
                Spacer()
            } else {
                List(Array(isletmeler.enumerated()), id: \.offset) { _, u in
                    islSatiri(u)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Kurulu İşletmeler (\(isletmeler.count))")
        .navigationBarTitleDisplayMode(.inline)
        .task { uyeler = await api.adminListe("members"); yukl = false }
    }

    func islSatiri(_ u: [String:Any]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "storefront.fill").font(.title3).foregroundStyle(.blue).frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(u["ad"] as? String ?? u["kod"] as? String ?? "İşletme").font(.subheadline.bold())
                HStack(spacing: 6) {
                    if let tel = u["tel"] as? String { Text(tel).font(.caption2).foregroundStyle(.secondary) }
                    if let slug = u["slug"] as? String, !slug.isEmpty {
                        Text("·").foregroundStyle(.secondary)
                        Text(slug).font(.caption2.monospaced()).foregroundStyle(.blue)
                    }
                }
            }
            Spacer()
            Image(systemName: (u["suspended"] as? Int ?? 0) == 1 ? "pause.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle((u["suspended"] as? Int ?? 0) == 1 ? .orange : .green)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Hukuk Bürosu (business kullanıcısı — kendi tenant verisi)
struct BizHukukNative: View {
    let kind: String   // "davalar" | "sureler" | "belgeler"
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var davalar: [[String:Any]] = []
    @State private var sureler: [[String:Any]] = []
    @State private var yukl = true
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var baslik: String {
        switch kind {
        case "sureler": return "Süre Takibi"
        case "belgeler": return "Belge Kasası"
        default: return "Dava Takibi"
        }
    }

    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            if yukl {
                ProgressView().tint(tema.c1).scaleEffect(1.3)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if kind == "belgeler" {
                            VStack(spacing: 14) {
                                Image(systemName: "lock.doc.fill").font(.system(size: 48)).foregroundStyle(tema.grad).padding(.top, 30)
                                Text("Belge Kasası").font(.title3.bold()).foregroundStyle(.rvText)
                                Text("Şifreli belgelerinize hukuk yönetim sisteminizden erişebilirsiniz.").font(.subheadline).foregroundStyle(.rvMut).multilineTextAlignment(.center).padding(.horizontal)
                            }.frame(maxWidth: .infinity).padding(.top, 40)
                        } else if kind == "sureler" {
                            if sureler.isEmpty {
                                bosEkran("calendar.badge.checkmark", "Yaklaşan süre yok")
                            } else {
                                ForEach(Array(sureler.enumerated()), id: \.offset) { _, s in sureSatiri(s) }
                            }
                        } else {
                            if davalar.isEmpty {
                                bosEkran("doc.text.fill", "Dava kaydı yok")
                            } else {
                                ForEach(Array(davalar.enumerated()), id: \.offset) { _, d in davaSatiri(d) }
                            }
                        }
                    }.padding(16)
                }.refreshable { await yukle() }
            }
        }
        .navigationTitle(baslik).navigationBarTitleDisplayMode(.inline)
        .task { await yukle() }
    }

    func yukle() async {
        yukl = true
        async let d = api.bizHukukDavalar()
        async let s = api.bizHukukSureler()
        (davalar, sureler) = await (d, s)
        yukl = false
    }

    func bosEkran(_ ikon: String, _ metin: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: ikon).font(.system(size: 44)).foregroundStyle(tema.c2).padding(.top, 30)
            Text(metin).font(.subheadline).foregroundStyle(.rvMut)
        }.frame(maxWidth: .infinity).padding(.top, 40)
    }

    func davaSatiri(_ d: [String:Any]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill").foregroundStyle(.teal).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(d["baslik"] as? String ?? "Dava").font(.subheadline.bold()).foregroundStyle(.rvText).lineLimit(2)
                HStack(spacing: 6) {
                    if let mv = d["muvekkil"] as? String { Text(mv).font(.caption2).foregroundStyle(.rvMut) }
                    if let a = d["asama"] as? String {
                        Text("·").foregroundStyle(.rvMut)
                        Text(a).font(.caption2.bold()).foregroundStyle(.teal)
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    func sureSatiri(_ s: [String:Any]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark.fill").foregroundStyle(.orange).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(s["aciklama"] as? String ?? s["tur"] as? String ?? "Süre").font(.subheadline.bold()).foregroundStyle(.rvText).lineLimit(2)
                if let tarih = s["tarih"] as? String { Text(tarih).font(.caption2).foregroundStyle(.rvMut) }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}
