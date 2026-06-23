import SwiftUI
import AVFoundation

// MARK: - Seslendir (Piper TTS — native audio)
struct SeslendirNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var metin = ""
    @State private var hiz: Double = 1.0
    @State private var yukleniyor = false
    @State private var hata = ""
    @State private var player: AVAudioPlayer?
    @State private var caliniyor = false
    @State private var sonMetin = ""
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "waveform").font(.system(size: 44)).foregroundStyle(.indigo).padding(.top, 8)
                Text("Türkçe Seslendir").font(.title2.bold())

                VStack(alignment: .leading, spacing: 8) {
                    Text("Metin").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $metin)
                        .frame(minHeight: 120)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3)))
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Konuşma Hızı: \(hiz, specifier: "%.1f")x").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $hiz, in: 0.5...2.0, step: 0.1)
                }
                .padding(.horizontal)

                Button {
                    Task { await seslendirAksiyon() }
                } label: {
                    if yukleniyor {
                        ProgressView().tint(.white)
                    } else {
                        Label("Seslendır", systemImage: "waveform.badge.plus")
                    }
                }
                .buttonStyle(.borderedProminent).disabled(metin.trimmingCharacters(in: .whitespaces).isEmpty || yukleniyor)
                .padding(.horizontal)

                if !hata.isEmpty {
                    Text(hata).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }

                if player != nil {
                    VStack(spacing: 10) {
                        if !sonMetin.isEmpty {
                            Text("« \(sonMetin.prefix(60))… »")
                                .font(.caption).foregroundStyle(.secondary).italic().padding(.horizontal)
                        }
                        HStack(spacing: 20) {
                            Button {
                                if caliniyor { player?.pause(); caliniyor = false }
                                else { player?.play(); caliniyor = true }
                            } label: {
                                Image(systemName: caliniyor ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 44)).foregroundStyle(.indigo)
                            }
                            Button {
                                player?.stop(); player?.currentTime = 0; caliniyor = false
                            } label: {
                                Image(systemName: "stop.circle.fill").font(.system(size: 44)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Seslendir")
        .navigationBarTitleDisplayMode(.inline)
    }

    func seslendirAksiyon() async {
        let t = metin.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        yukleniyor = true; hata = ""
        guard let sonuc = await api.seslendirTTS(metin: t, hiz: hiz) else {
            hata = "Bağlantı hatası"; yukleniyor = false; return
        }
        if let ok = sonuc["ok"] as? Bool, ok,
           let b64 = sonuc["audio"] as? String,
           let data = Data(base64Encoded: b64) {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                player = try AVAudioPlayer(data: data)
                player?.play(); caliniyor = true; sonMetin = t
            } catch {
                hata = "Ses oynatılamadı: \(error.localizedDescription)"
            }
        } else {
            hata = sonuc["mesaj"] as? String ?? sonuc["err"] as? String ?? "Bilinmeyen hata"
        }
        yukleniyor = false
    }
}

// MARK: - AI Görsel (FLUX — native image generation)
struct GorselNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var prompt = ""
    @State private var kalite = "normal"
    @State private var yukleniyor = false
    @State private var hata = ""
    @State private var gorsel: UIImage? = nil
    @State private var ozet: [String:Any] = [:]
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    let kaliteler = [("hizli","Hızlı"), ("normal","Normal"), ("kaliteli","Kaliteli")]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let img = gorsel {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(radius: 8)
                        .padding(.horizontal)
                    ShareLink(item: Image(uiImage: img), preview: SharePreview("AI Görsel", image: Image(uiImage: img))) {
                        Label("Kaydet / Paylaş", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                } else {
                    RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.1))
                        .frame(height: 220)
                        .overlay {
                            if yukleniyor { VStack(spacing: 10) { ProgressView(); Text("Görsel oluşturuluyor…").font(.caption).foregroundStyle(.secondary) } }
                            else { Image(systemName: "photo.fill.on.rectangle.fill").font(.system(size: 44)).foregroundStyle(.secondary) }
                        }
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Açıklama (Türkçe veya İngilizce)").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $prompt).frame(minHeight: 80)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3)))
                }
                .padding(.horizontal)

                Picker("Kalite", selection: $kalite) {
                    ForEach(kaliteler, id: \.0) { Text($1).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal)

                Button {
                    Task { await gorselUret() }
                } label: {
                    if yukleniyor { ProgressView().tint(.white) }
                    else { Label("Görsel Üret", systemImage: "sparkles") }
                }
                .buttonStyle(.borderedProminent).disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || yukleniyor)
                .padding(.horizontal)

                if !hata.isEmpty {
                    Text(hata).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }

                // İstatistikler
                if let n = ozet["toplam_islem"] as? Int {
                    Divider().padding(.horizontal)
                    HStack(spacing: 16) {
                        ozetKutu("Toplam İşlem", "\(n)")
                        if let k = ozet["kullanici"] as? Int { ozetKutu("Kullanıcı", "\(k)") }
                        if let s = ozet["satis_adet"] as? Int { ozetKutu("Satış", "\(s)") }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("AI Görsel (FLUX)")
        .navigationBarTitleDisplayMode(.inline)
        .task { ozet = await api.gorselOzet() }
    }

    func gorselUret() async {
        let p = prompt.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty else { return }
        yukleniyor = true; hata = ""; gorsel = nil
        guard let sonuc = await api.gorselUret(prompt: p, kalite: kalite) else {
            hata = "Bağlantı hatası"; yukleniyor = false; return
        }
        if let ok = sonuc["ok"] as? Bool, ok,
           var b64 = sonuc["image"] as? String {
            if b64.hasPrefix("data:") { b64 = String(b64.split(separator: ",", maxSplits: 1).last ?? "") }
            if let data = Data(base64Encoded: b64), let img = UIImage(data: data) {
                gorsel = img
            } else { hata = "Görsel çözümlenemedi" }
        } else {
            hata = sonuc["err"] as? String ?? sonuc["mesaj"] as? String ?? "Hata"
        }
        yukleniyor = false
    }

    func ozetKutu(_ etiket: String, _ deger: String) -> some View {
        VStack(spacing: 4) {
            Text(deger).font(.title3.bold()).foregroundStyle(.primary)
            Text(etiket).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Hukuk Bürosu (native)
struct HukukNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var instances: [[String:Any]] = []
    @State private var secilenDid = ""
    @State private var davalar: [[String:Any]] = []
    @State private var sureler: [[String:Any]] = []
    @State private var yukl = true
    @State private var dYukl = false
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if yukl {
                    ProgressView().padding(60)
                } else if instances.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text.magnifyingglass").font(.system(size: 44)).foregroundStyle(.teal).padding(.top, 20)
                        Text("Hukuk bürosu kaydı bulunamadı.").foregroundStyle(.secondary)
                    }
                } else {
                    // Büro seçici
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(instances, id: { $0["id"] as? String ?? "" }) { inst in
                                let did = inst["id"] as? String ?? ""
                                Button {
                                    secilenDid = did
                                    Task { await davalarYukle() }
                                } label: {
                                    Text(inst["brand"] as? String ?? did)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(secilenDid == did ? Color.teal : Color.secondary.opacity(0.12))
                                        .foregroundStyle(secilenDid == did ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if dYukl {
                        ProgressView().padding(20)
                    } else if !secilenDid.isEmpty {
                        // Yaklaşan süreler
                        if !sureler.isEmpty {
                            bolumBaslik("Yaklaşan Süreler (\(sureler.count))", renk: .orange)
                            ForEach(Array(sureler.prefix(5).enumerated()), id: \.offset) { _, s in
                                sureSatiri(s)
                            }
                        }
                        // Davalar
                        bolumBaslik("Davalar (\(davalar.count))", renk: .teal)
                        if davalar.isEmpty {
                            Text("Bu büroya ait dava yok.").font(.caption).foregroundStyle(.secondary).padding()
                        } else {
                            ForEach(Array(davalar.enumerated()), id: \.offset) { _, d in
                                davaSatiri(d)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 14)
        }
        .navigationTitle("Hukuk Bürosu")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            instances = await api.hukukInstances()
            if let first = instances.first, let did = first["id"] as? String {
                secilenDid = did
                await davalarYukle()
            }
            yukl = false
        }
    }

    func davalarYukle() async {
        guard !secilenDid.isEmpty else { return }
        dYukl = true
        async let d = api.hukukDavalar(secilenDid)
        async let s = api.hukukSureler(secilenDid)
        (davalar, sureler) = await (d, s)
        dYukl = false
    }

    func bolumBaslik(_ baslik: String, renk: Color) -> some View {
        HStack {
            Text(baslik).font(.subheadline.bold()).foregroundStyle(renk)
            Spacer()
        }
        .padding(.horizontal).padding(.top, 6)
    }

    func sureSatiri(_ s: [String:Any]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(s["aciklama"] as? String ?? s["tur"] as? String ?? "Süre").font(.subheadline.bold()).lineLimit(1)
                if let tarih = s["tarih"] as? String { Text(tarih).font(.caption2).foregroundStyle(.secondary) }
            }
            Spacer()
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    func davaSatiri(_ d: [String:Any]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.fill").foregroundStyle(.teal).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(d["baslik"] as? String ?? "Dava").font(.subheadline.bold()).lineLimit(2)
                HStack(spacing: 6) {
                    if let mv = d["muvekkil"] as? String { Text(mv).font(.caption2).foregroundStyle(.secondary) }
                    if let asama = d["asama"] as? String {
                        Text("·").foregroundStyle(.secondary)
                        Text(asama).font(.caption2.bold()).foregroundStyle(.teal)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

// MARK: - AI Stüdyo (RealVirtuality) — istatistikler
struct AistudioNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var veri: [String:Any] = [:]
    @State private var yukl = true
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if yukl {
                    ProgressView().padding(60)
                } else {
                    Image(systemName: "sparkles.rectangle.stack.fill").font(.system(size: 44)).foregroundStyle(.purple).padding(.top, 8)
                    Text("AI Stüdyo").font(.title2.bold())

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        if let n = veri["kullanici"] as? Int { metrikKutu("Kullanıcı", "\(n)", "person.2.fill", .blue) }
                        if let n = veri["toplam_islem"] as? Int { metrikKutu("İşlem", "\(n)", "sparkles", .purple) }
                        if let n = veri["satis_adet"] as? Int { metrikKutu("Satış", "\(n)", "creditcard.fill", .green) }
                        if let t = veri["satis_try"] as? Double { metrikKutu("Ciro", "₺\(Int(t))", "turkishlira.circle.fill", .orange) }
                    }
                    .padding(.horizontal)

                    if let son = veri["son_islemler"] as? [[String:Any]], !son.isEmpty {
                        Divider().padding(.horizontal)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Son İşlemler").font(.subheadline.bold()).foregroundStyle(.secondary).padding(.horizontal)
                            ForEach(Array(son.prefix(8).enumerated()), id: \.offset) { _, i in
                                HStack {
                                    Text(i["islem"] as? String ?? "?").font(.caption.bold()).foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(i["kredi"] as? Int ?? 0) kr").font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(.horizontal).padding(.vertical, 4)
                            }
                        }
                    }

                    if let pop = veri["populer"] as? [[String:Any]], !pop.isEmpty {
                        Divider().padding(.horizontal)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Popüler Araçlar").font(.subheadline.bold()).foregroundStyle(.secondary).padding(.horizontal)
                            ForEach(Array(pop.enumerated()), id: \.offset) { idx, p in
                                HStack {
                                    Text("\(idx+1). \(p["islem"] as? String ?? "?")").font(.caption)
                                    Spacer()
                                    Text("\(p["n"] as? Int ?? 0) kez").font(.caption2).foregroundStyle(.purple)
                                }
                                .padding(.horizontal).padding(.vertical, 3)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("AI Stüdyo")
        .navigationBarTitleDisplayMode(.inline)
        .task { veri = await api.gorselOzet(); yukl = false }
    }

    func metrikKutu(_ etiket: String, _ deger: String, _ ikon: String, _ renk: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: ikon).font(.title2).foregroundStyle(renk)
            Text(deger).font(.title3.bold())
            Text(etiket).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(14)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Traccar Konum (placeholder — credentials bekleniyor)
struct TraccarNative: View {
    @Environment(\.openURL) var openURL

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "location.fill").font(.system(size: 52)).foregroundStyle(.blue)
            Text("Traccar Konum").font(.title2.bold())
            Text("Canlı araç/kişi konumu ND2 sunucusunda çalışıyor.\nTraccar kimlik bilgileri yapılandırılınca burada native harita görünecek.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            if let u = URL(string: "https://gps.nickdegs.duckdns.org") {
                Link(destination: u) {
                    Label("Web Arayüzü", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .navigationTitle("Traccar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Chat Logları (Hush / Matrix)
struct ChatNative: View {
    @EnvironmentObject var oturum: Oturum
    @State private var odalar: [[String:Any]] = []
    @State private var yukl = true
    private var api: PanelAPI { PanelAPI(host: oturum.host, token: oturum.token) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if yukl {
                    ProgressView().padding(60)
                } else if odalar.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 44)).foregroundStyle(.purple).padding(.top, 20)
                        Text("Sohbet Odaları").font(.title3.bold())
                        Text("Matrix/Hush sohbet logları.\nOda verisi şu an yüklenemiyor.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    }
                } else {
                    ForEach(Array(odalar.enumerated()), id: \.offset) { _, oda in
                        odaSatiri(oda)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Chat Logları")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Matrix admin API — /api/panel/matrix-odalar henüz yok, placeholder
            yukl = false
        }
    }

    func odaSatiri(_ oda: [String:Any]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.fill").font(.title3).foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text(oda["name"] as? String ?? "Oda").font(.subheadline.bold())
                if let n = oda["joined_members"] as? Int { Text("\(n) üye").font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

// MARK: - Komuta Merkezi (→ KontrolMerkeziNative ile aynı işlev)
struct KomutaNative: View {
    var body: some View {
        KontrolMerkeziNative()
    }
}
