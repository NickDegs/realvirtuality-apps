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
    @Environment(\.openURL) var openURL
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if yukl {
                    ProgressView().padding(60)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "globe").font(.system(size: 48)).foregroundStyle(.blue)
                        Text(ad.isEmpty ? "İşletme Sayfanız" : ad).font(.title2.bold())
                    }
                    .padding(.top, 8)

                    if siteURL.isEmpty {
                        Text("Henüz işletme sayfanız bağlanmamış.\nYönetici ile iletişime geçin.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding()
                    } else {
                        VStack(spacing: 14) {
                            Text(siteURL).font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).padding(.horizontal)

                            HStack(spacing: 14) {
                                Button {
                                    UIPasteboard.general.string = siteURL
                                } label: {
                                    Label("Kopyala", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)

                                if let u = URL(string: siteURL) {
                                    Link(destination: u) {
                                        Label("Sayfayı Aç", systemImage: "arrow.up.right.square")
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }

                            Text("Sayfanızı müşterilerinizle paylaşın.\nURL'i kopyalayın veya QR Kod ekranından QR üretin.")
                                .font(.caption2).foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center).padding(.horizontal)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
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
    @State private var aktif = false
    @State private var yukl = true
    @Environment(\.openURL) var openURL
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "bubble.left.and.lock.fill").font(.system(size: 52)).foregroundStyle(.purple).padding(.top, 8)
                Text("Şifreli Destek").font(.title2.bold())
                Text("Hush — uçtan uca şifreli mesajlaşma altyapısı üzerinde çalışır.\nMesajlar sunucuda saklanmaz, kayıt tutulmaz.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)

                if yukl {
                    ProgressView()
                } else if hushURL.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.slash").foregroundStyle(.orange).font(.title)
                        Text("Destek sohbeti bu hesapta aktif değil.\nYöneticinizden etkinleştirmesini isteyin.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: aktif ? "checkmark.circle.fill" : "clock.circle").foregroundStyle(aktif ? .green : .orange)
                            Text(aktif ? "Aktif Abonelik" : "Abonelik kontrolü yapılamadı").font(.subheadline)
                        }
                        if let u = URL(string: hushURL) {
                            Link(destination: u) {
                                Label("Sohbeti Başlat", systemImage: "arrow.up.right.square")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).padding(.horizontal)
                        }
                        Text(hushURL).font(.caption2).foregroundStyle(.tertiary)
                            .onTapGesture { UIPasteboard.general.string = hushURL }
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

// MARK: - Kişisel Hizmetler (süper admin)
struct KisiselNative: View {
    @Environment(\.openURL) var openURL

    private let hizmetler: [(ikon: String, ad: String, aciklama: String, url: String)] = [
        ("person.crop.circle.fill", "Kişisel Panel", "kasam.nickdegs.com — kendi servisleriniz", "https://kasam.nickdegs.com"),
        ("location.fill", "Traccar Konum", "Canlı araç/kişi takibi", "https://traccar.nickdegs.com"),
        ("film.stack.fill", "Medya Sunucusu", "Emby · Plex · IPTV arşiv", "https://media.nickdegs.com"),
        ("waveform", "Seslendir (Piper)", "Ücretsiz Türkçe TTS servisi", "https://nickdegs.com/seslendir"),
        ("photo.fill.on.rectangle.fill", "AI Görsel (FLUX)", "Yazıdan görsel üretimi", "https://realvirtuality.app"),
        ("doc.text.magnifyingglass", "Hukuk Bürosu", "Dava takibi · şifreli belge kasası", "https://nickdegs.com/hukuk"),
        ("bubble.left.and.bubble.right.fill", "Chat Logları", "Hush sohbet kayıtları", "https://nickdegs.com/hush/chat"),
        ("sparkles", "AI Stüdyo", "RealVirtuality yönetim paneli", "https://realvirtuality.app/yonet?token=0f469b1395332561075187fe"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(hizmetler, id: \.ad) { h in
                    if let u = URL(string: h.url) {
                        Link(destination: u) {
                            HStack(spacing: 14) {
                                Image(systemName: h.ikon).font(.title2).foregroundStyle(.purple).frame(width: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(h.ad).font(.subheadline.bold()).foregroundStyle(.primary)
                                    Text(h.aciklama).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").foregroundStyle(.secondary).font(.footnote)
                            }
                            .padding(14)
                            .background(Color.secondary.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Kişisel")
        .navigationBarTitleDisplayMode(.inline)
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
