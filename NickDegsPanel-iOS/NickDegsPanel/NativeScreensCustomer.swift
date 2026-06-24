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
    @EnvironmentObject var tema: Tema
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

                    // Görünüm: Sistem / Koyu / Açık
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Görünüm").font(.headline).padding(.horizontal)
                        HStack(spacing: 10) {
                            ForEach([("sistem","Sistem","circle.lefthalf.filled"),("koyu","Koyu","moon.fill"),("acik","Açık","sun.max.fill")], id: \.0) { m in
                                Button { withAnimation(.snappy) { tema.mod = m.0 } } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: m.2).font(.title3)
                                        Text(m.1).font(.caption.bold())
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(tema.mod == m.0 ? AnyShapeStyle(tema.grad) : AnyShapeStyle(Color.secondary.opacity(0.10)), in: .rect(cornerRadius: 14))
                                    .foregroundStyle(tema.mod == m.0 ? Color.white : Color.primary)
                                }.buttonStyle(.plain)
                            }
                        }.padding(.horizontal)
                    }.padding(.top, 4)

                    Divider().padding(.horizontal)

                    HStack(spacing: 16) {
                        Link("Gizlilik Politikası", destination: URL(string: "https://nickdegs.com/legal/privacy")!)
                            .font(.caption).foregroundStyle(.purple)
                        Text("·").foregroundStyle(.secondary).font(.caption)
                        Link("Kullanım Koşulları", destination: URL(string: "https://nickdegs.com/legal/tos")!)
                            .font(.caption).foregroundStyle(.purple)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(tema.renkSemasi)   // ayar ekranı da canlı açık/koyu/sistem geçer
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
                #if IPTV_MODULE
                kisiselSatir("film.stack.fill", "Medya", "Emby · Plex · IPTV yönetim") { MedyaNative() }
                #endif
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

// MARK: - Müşteri İşletmeleri (master admin — sektöre göre gruplu liste)

struct IsletmeBizItem: Identifiable, Hashable {
    let id: String   // kod
    let data: [String:Any]
    init(_ d: [String:Any]) { self.id = d["kod"] as? String ?? UUID().uuidString; self.data = d }
    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct IsletmelerNative: View {
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var gruplar: [(sek: String, isletmeler: [IsletmeBizItem])] = []
    @State private var yukleniyor = true
    @State private var secili: IsletmeBizItem? = nil

    private let sektorSira = ["Restoran","Randevu / Klinik","Hukuk Bürosu","Kurumsal","Genel"]

    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            if yukleniyor {
                ProgressView().tint(tema.c1).scaleEffect(1.3)
            } else if gruplar.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "storefront").font(.system(size: 44)).foregroundStyle(tema.c2)
                    Text("Henüz müşteri işletme yok").foregroundStyle(.rvMut)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(gruplar, id: \.sek) { grup in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: sektorIkon(grup.sek)).font(.caption.bold()).foregroundStyle(tema.c1)
                                    Text(grup.sek.uppercased()).font(.caption.bold()).foregroundStyle(.rvMut)
                                    Spacer()
                                    Text("\(grup.isletmeler.count)").font(.caption2.bold()).foregroundStyle(tema.c1)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(tema.c1.opacity(0.15), in: .capsule)
                                }
                                .padding(.horizontal, 4)
                                ForEach(grup.isletmeler) { item in
                                    Button { secili = item } label: {
                                        isletmeSatir(item.data)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(16).padding(.bottom, 30)
                }
                .refreshable { await yukle() }
            }
        }
        .navigationTitle("Müşteriler")
        .navigationBarTitleDisplayMode(.large)
        .task { await yukle() }
        .navigationDestination(item: $secili) { item in
            BizDetayView(biz: item.data)
        }
    }

    func isletmeSatir(_ biz: [String:Any]) -> some View {
        let suspended = biz["suspended"] as? Bool ?? false
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(suspended ? Color.orange.opacity(0.2) : tema.c1.opacity(0.18)).frame(width: 44, height: 44)
                Image(systemName: suspended ? "pause.circle.fill" : "storefront.fill")
                    .foregroundStyle(suspended ? .orange : tema.c1).font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(biz["ad"] as? String ?? "—").font(.subheadline.bold()).foregroundStyle(.rvText)
                HStack(spacing: 6) {
                    if let tel = biz["tel"] as? String, !tel.isEmpty {
                        Text(tel).font(.caption2).foregroundStyle(.rvMut)
                    }
                    if suspended {
                        Text("Askıya Alındı").font(.caption2.bold()).foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.rvMut)
        }
        .padding(14)
        .background(Color.rvCard, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(suspended ? Color.orange.opacity(0.4) : Color.rvLine, lineWidth: 1))
    }

    func sektorIkon(_ sek: String) -> String {
        switch sek {
        case "Restoran": return "fork.knife"
        case "Randevu / Klinik": return "calendar"
        case "Hukuk Bürosu": return "building.columns.fill"
        case "Kurumsal": return "briefcase.fill"
        default: return "storefront.fill"
        }
    }

    func yukle() async {
        yukleniyor = true; defer { yukleniyor = false }
        let api = PanelAPI(host: oturum.host, token: oturum.token)
        guard let d = await api.isletmeler(), let raw = d["gruplar"] as? [String: Any] else { return }
        var dict: [String: [[String:Any]]] = [:]
        for (k, v) in raw {
            if let arr = v as? [[String:Any]] { dict[k] = arr }
        }
        gruplar = sektorSira.compactMap { s in
            guard let arr = dict[s], !arr.isEmpty else { return nil }
            return (sek: s, isletmeler: arr.map { IsletmeBizItem($0) })
        }
        for (k, arr) in dict where !sektorSira.contains(k) && !arr.isEmpty {
            gruplar.append((sek: k, isletmeler: arr.map { IsletmeBizItem($0) }))
        }
    }
}

// MARK: - İşletme Detay & Yönetim (master admin girişi)

struct BizDetayView: View {
    let biz: [String:Any]
    @EnvironmentObject var oturum: Oturum
    @EnvironmentObject var tema: Tema
    @State private var bizPanelAcik = false
    @State private var bizToken = ""
    @State private var bizTokenYukleniyor = false
    @State private var suspended: Bool
    @State private var aksiyonMesaj = ""
    @State private var aksiyonBekle = false
    @State private var bizVeri: [[String:Any]] = []
    @State private var veriYukleniyor = true

    init(biz: [String:Any]) {
        self.biz = biz
        _suspended = State(initialValue: biz["suspended"] as? Bool ?? false)
    }

    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }
    private var ad: String { biz["ad"] as? String ?? "İşletme" }
    private var sektor: String { biz["sektor"] as? String ?? "Genel" }
    private var tel: String { biz["tel"] as? String ?? "" }
    private var slug: String { biz["slug"] as? String ?? "" }
    private var kod: String { biz["kod"] as? String ?? "" }
    private var kindForSektor: String {
        switch sektor {
        case "Randevu / Klinik": return "appts"
        case "Hukuk Bürosu": return "davalar"
        default: return "orders"
        }
    }

    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Başlık
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16).fill(tema.c1.opacity(0.2)).frame(width: 60, height: 60)
                            Image(systemName: "storefront.fill").font(.system(size: 26)).foregroundStyle(tema.grad)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ad).font(.title3.bold()).foregroundStyle(.rvText)
                            Text(sektor).font(.caption.bold()).foregroundStyle(tema.c1)
                            if !tel.isEmpty { Text(tel).font(.caption).foregroundStyle(.rvMut) }
                        }
                        Spacer()
                        if suspended {
                            Text("Askıya Alındı").font(.caption2.bold()).foregroundStyle(.orange)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.orange.opacity(0.15), in: .capsule)
                        }
                    }
                    .padding(16).glassEffect(.regular, in: .rect(cornerRadius: 18))

                    // Bilgi satırları
                    if !slug.isEmpty {
                        bilgiSatir("Panel Adresi", "nickdegs.com/\(slug)", "link")
                    }
                    bilgiSatir("Sektör Sistemi", sektor, "building.2.fill")
                    bilgiSatir("Hesap Kodu", kod, "person.text.rectangle")

                    // Admin aksiyonları
                    HStack(spacing: 10) {
                        aksiyon(suspended ? "Aktifleştir" : "Askıya Al",
                                suspended ? "checkmark.circle.fill" : "pause.circle.fill",
                                suspended ? Color.green : Color.orange) {
                            await toggleSuspend()
                        }
                        aksiyon("Paneline Gir", "arrow.right.square.fill", tema.c1) {
                            await panelAc()
                        }
                    }

                    if !aksiyonMesaj.isEmpty {
                        Text(aksiyonMesaj).font(.caption).foregroundStyle(.rvMut)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    // Canlı veri önizleme
                    Text("Son Aktivite").font(.caption.bold()).foregroundStyle(.rvMut).padding(.top, 4)
                    if veriYukleniyor {
                        ProgressView().tint(tema.c1).frame(maxWidth: .infinity).padding()
                    } else if bizVeri.isEmpty {
                        Text("Kayıt yok").font(.caption).foregroundStyle(.rvMut).frame(maxWidth: .infinity, alignment: .center).padding()
                    } else {
                        ForEach(Array(bizVeri.prefix(5).enumerated()), id: \.offset) { _, item in
                            veriSatir(item)
                        }
                    }
                }
                .padding(16).padding(.bottom, 40)
            }
        }
        .navigationTitle(ad).navigationBarTitleDisplayMode(.inline)
        .task { await yukleVeri() }
        .navigationDestination(isPresented: $bizPanelAcik) {
            BizPanelInlineView(host: oturum.host, bizToken: bizToken, ad: ad, sektor: sektor)
        }
    }

    func bilgiSatir(_ k: String, _ v: String, _ ic: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ic).foregroundStyle(tema.c1).frame(width: 22)
            Text(k).font(.caption).foregroundStyle(.rvMut)
            Spacer()
            Text(v).font(.caption.bold()).foregroundStyle(.rvText).lineLimit(1)
        }
        .padding(12).glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    @ViewBuilder
    func aksiyon(_ baslik: String, _ ic: String, _ renk: Color, _ action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: ic).font(.system(size: 22)).foregroundStyle(renk)
                Text(baslik).font(.caption.bold()).foregroundStyle(.rvText)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(aksiyonBekle || bizTokenYukleniyor)
    }

    func veriSatir(_ it: [String:Any]) -> some View {
        HStack(spacing: 10) {
            Circle().fill(tema.c1.opacity(0.2)).frame(width: 8, height: 8)
            Text(it["name"] as? String ?? it["client"] as? String ?? it["aciklama"] as? String ?? "#\(it["id"] ?? "")")
                .font(.caption).foregroundStyle(.rvText).lineLimit(1)
            Spacer()
            if let t = it["total"] { Text("\(t)₺").font(.caption.bold()).foregroundStyle(.green) }
            else if let ts = it["created"] as? String { Text(ts).font(.system(size: 10)).foregroundStyle(.rvMut) }
        }
        .padding(10).background(Color.rvCard, in: .rect(cornerRadius: 10))
    }

    func toggleSuspend() async {
        aksiyonBekle = true; defer { aksiyonBekle = false }
        let yeni = suspended ? "unsuspend" : "suspend"
        let ok = await api.isletmelerAksiyon(biz: kod, aksiyon: yeni)
        if ok { suspended.toggle(); aksiyonMesaj = suspended ? "İşletme askıya alındı." : "İşletme aktifleştirildi." }
        else { aksiyonMesaj = "İşlem başarısız." }
    }

    func panelAc() async {
        guard bizToken.isEmpty else { bizPanelAcik = true; return }
        bizTokenYukleniyor = true; defer { bizTokenYukleniyor = false }
        if let tok = await api.isletmelerToken(biz: kod) {
            bizToken = tok; bizPanelAcik = true
        } else {
            aksiyonMesaj = "Token alınamadı."
        }
    }

    func yukleVeri() async {
        veriYukleniyor = true; defer { veriYukleniyor = false }
        guard let tok = await api.isletmelerToken(biz: kod) else { return }
        let bizApi = PanelAPI(host: oturum.host, token: tok)
        switch kindForSektor {
        case "appts":  bizVeri = await bizApi.bizVeri("appts")
        case "davalar": bizVeri = await bizApi.bizHukukDavalar()
        default:       bizVeri = await bizApi.bizVeri("orders")
        }
    }
}

// MARK: - İşletme Paneli İçe Gömülü (master admin — biz token ile)

struct BizPanelInlineView: View {
    let host: String
    let bizToken: String
    let ad: String
    let sektor: String
    @EnvironmentObject var tema: Tema
    @State private var gruplar: [HubGrup] = []
    @State private var yukleniyor = true
    @State private var hedef: HubKart? = nil

    private var api: PanelAPI { PanelAPI(host: host, token: bizToken) }
    private var kolonlar: [GridItem] { [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)] }

    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            if yukleniyor {
                ProgressView().tint(tema.c1).scaleEffect(1.3)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(gruplar) { g in
                            VStack(alignment: .leading, spacing: 8) {
                                Label(g.ad, systemImage: g.ikon).font(.caption.bold()).foregroundStyle(.rvMut).padding(.horizontal, 4)
                                LazyVGrid(columns: kolonlar, spacing: 10) {
                                    ForEach(g.kartlar) { k in
                                        Button { hedef = k } label: {
                                            bizKart(k)
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16).padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("\(ad) Paneli").navigationBarTitleDisplayMode(.inline)
        .task { await yukle() }
        .navigationDestination(item: $hedef) { k in
            BizPanelSectionView(host: host, bizToken: bizToken, kart: k)
        }
    }

    func bizKart(_ k: HubKart) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: k.ic).font(.system(size: 22, weight: .semibold)).foregroundStyle(tema.grad)
            Text(k.baslik).font(.caption.bold()).foregroundStyle(.rvText).lineLimit(2)
            Text(k.alt).font(.system(size: 10)).foregroundStyle(.rvMut).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .padding(12)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    func yukle() async {
        yukleniyor = true; defer { yukleniyor = false }
        guard let url = URL(string: (host.hasPrefix("http") ? host : "https://\(host)") + "/api/panel/hub?t=\(bizToken)") else { return }
        guard let (d, _) = try? await URLSession.shared.data(from: url) else { return }
        struct Y: Decodable { let ok: Bool; let gruplar: [HubGrup]? }
        if let y = try? JSONDecoder().decode(Y.self, from: d), y.ok { gruplar = y.gruplar ?? [] }
    }
}

// Sektör paneli içinde bir bölümü izleme (biz token kullanır)
struct BizPanelSectionView: View {
    let host: String
    let bizToken: String
    let kart: HubKart
    @EnvironmentObject var tema: Tema
    @State private var liste: [[String:Any]] = []
    @State private var yukleniyor = true

    private var api: PanelAPI { PanelAPI(host: host, token: bizToken) }

    var body: some View {
        ZStack {
            AnimatedArka(c1: tema.c1, c2: tema.c2)
            if yukleniyor { ProgressView().tint(tema.c1).scaleEffect(1.3) }
            else if liste.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: kart.ic).font(.system(size: 40)).foregroundStyle(tema.c2)
                    Text("Kayıt yok").foregroundStyle(.rvMut)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(liste.enumerated()), id: \.offset) { _, it in
                            satir(it)
                        }
                    }.padding(16)
                }.refreshable { await yukle() }
            }
        }
        .navigationTitle(kart.baslik).navigationBarTitleDisplayMode(.inline)
        .task { await yukle() }
    }

    func satir(_ it: [String:Any]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(it["name"] as? String ?? it["table_no"] as? String
                     ?? it["client"] as? String ?? it["aciklama"] as? String
                     ?? "#\(it["id"] ?? "")").font(.subheadline.bold()).foregroundStyle(.rvText)
                Spacer()
                if let t = it["total"] { Text("\(t)₺").font(.subheadline.bold()).foregroundStyle(.green) }
                else if let p = it["price"] { Text("\(p)₺").font(.subheadline.bold()).foregroundStyle(tema.c2) }
            }
            if let items = it["items"] as? [[String:Any]] {
                Text(items.map { "\($0["qty"] ?? 1)× \($0["name"] ?? "")" }.joined(separator: ", "))
                    .font(.caption2).foregroundStyle(.rvMut).lineLimit(2)
            } else if let c = it["category"] as? String { Text(c).font(.caption2).foregroundStyle(.rvMut) }
            if let cr = it["created"] as? String { Text(cr).font(.caption2).foregroundStyle(.rvMut) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    func yukle() async {
        yukleniyor = true; defer { yukleniyor = false }
        switch kart.s {
        case "siparis": liste = await api.bizVeri("orders")
        case "stok":    liste = await api.bizVeri("menu")
        case "randevu","musteriler": liste = await api.bizVeri("appts")
        case "ozet","raporlar":      liste = await api.bizVeri("stats")
        case "davalar": liste = await api.bizHukukDavalar()
        case "sureler": liste = await api.bizHukukSureler()
        default:        liste = await api.bizVeri(kart.s)
        }
    }
}
