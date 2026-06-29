import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import UniformTypeIdentifiers

struct ToolView: View {
    let arac: Arac
    @EnvironmentObject var api: API
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel

    @State private var girdi = ""
    @State private var hedefDil = "en"
    @State private var sahne = "beyaz"
    @State private var platform = "instagram"
    @State private var kalite = "kaliteli"
    @State private var oran = "kare"
    @State private var secilenFoto: PhotosPickerItem?
    @State private var gorselData: Data?
    @State private var secilenFoto2: PhotosPickerItem?
    @State private var gorselData2: Data?
    @State private var pdfData: Data?
    @State private var pdfImport = false
    @State private var secilenVideo: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var klipAdet = 3
    @State private var klipFormat = "dikey"
    @State private var klipAltyazi = "klasik"
    @State private var klipMuzik = ""
    @State private var sonuc: UretimSonuc? = nil
    @State private var sesData: Data? = nil
    @State private var hata = ""
    @State private var kotaUyari = false
    @State private var calar: AVAudioPlayer?
    @State private var urlCalar: AVPlayer?

    let diller = ["tr":"Türkçe","en":"English","de":"Deutsch","fr":"Français","es":"Español","ar":"العربية","ru":"Русский"]
    let sahneler = [("beyaz","Beyaz stüdyo"),("mermer","Mermer (lüks)"),("ahsap","Ahşap masa"),("yaprak","Doğal yaprak"),("gradyan","Renkli gradyan"),("mutfak","Mutfak tezgâhı"),("siyah","Siyah (dramatik)"),("pastel","Pastel minimal")]
    let platformlar = [("instagram","Instagram"),("facebook","Facebook"),("tiktok","TikTok"),("linkedin","LinkedIn"),("x","X (Twitter)")]
    let kaliteler = [("kaliteli","💎 Kaliteli (çok kredi)"),("dandik","⚡ Hızlı / Ekonomik (az kredi)")]
    let oranlar = [("kare","⬛ Kare 1:1"),("dikey","📱 Dikey 9:16"),("yatay","🖥️ Yatay 16:9")]
    let kaliteAraclar = ["gorsel","logo","urunfoto","icerik","donustur"]
    let oranAraclar = ["gorsel","logo","icerik"]

    private var gorselGerek: Bool { arac.kind == .gorselYukle || arac.kind == .gorselArti || arac.kind == .urunfoto }
    private var ikiGorsel: Bool { arac.kind == .faceswap }
    private var pdfGerek: Bool { arac.kind == .pdf }
    private var videoGerek: Bool { arac.kind == .video }

    let klipFormatlar = [("dikey","📱 Dikey 9:16 (Reels/TikTok)"),("yatay","🖥️ Yatay 16:9 (YouTube)")]
    let klipAltyazilar = [("klasik","💬 Klasik altyazı"),("karaoke","🎤 Karaoke (kelime kelime)"),("kapali","🚫 Altyazısız")]
    let klipMuzikler = [("","🔇 Müziksiz"),("sakin","🌙 Sakin"),("enerjik","⚡ Enerjik"),("dramatik","🎬 Dramatik")]
    private var metinGerek: Bool { arac.kind == .prompt || arac.kind == .metin || arac.kind == .ceviri || arac.kind == .gorselArti || arac.kind == .icerik || arac.kind == .url }
    private var hazir: Bool {
        if videoGerek { return videoURL != nil }
        if ikiGorsel { return gorselData != nil && gorselData2 != nil }
        if pdfGerek { return pdfData != nil }
        if gorselGerek && gorselData == nil { return false }
        if metinGerek && girdi.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        return true
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.rvBg, .rvBg2, .rvBg], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(yerel.aracMetin(arac.id,"slogan")).font(.subheadline).foregroundStyle(.rvMut)
                        .fixedSize(horizontal: false, vertical: true)

                    if gorselGerek { gorselSecici }
                    if ikiGorsel { ikiGorselSecici }
                    if pdfGerek { pdfSecici }
                    if videoGerek { videoSecici; klipSecenekler }
                    if metinGerek { metinAlani }
                    if arac.kind == .ceviri { dilSecici }
                    if arac.kind == .urunfoto { secici(yerel.t("sahne"), sahneler, $sahne) }
                    if arac.kind == .icerik { secici(yerel.t("platform"), platformlar, $platform) }
                    if kaliteAraclar.contains(arac.id) { secici("Kalite", kaliteler, $kalite) }
                    if oranAraclar.contains(arac.id) { secici("En / boy", oranlar, $oran) }

                    uretButonu

                    if kotaUyari { kotaKutu }
                    else if !hata.isEmpty { hataKutu }

                    if let s = sonuc { sonucGorunum(s) }
                    if sesData != nil { sesGorunum }
                }
                .padding(20)
            }
        }
        .navigationTitle(yerel.aracMetin(arac.id,"ad"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: secilenFoto) { _, yeni in
            Task { if let d = try? await yeni?.loadTransferable(type: Data.self) { gorselData = d } }
        }
        .onChange(of: secilenFoto2) { _, yeni in
            Task { if let d = try? await yeni?.loadTransferable(type: Data.self) { gorselData2 = d } }
        }
        .onChange(of: secilenVideo) { _, yeni in
            Task {
                guard let d = try? await yeni?.loadTransferable(type: Data.self) else { return }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("rv-klip-\(UUID().uuidString).mp4")
                try? d.write(to: url)
                videoURL = url
            }
        }
    }

    // MARK: video seçici — oto-klip kaynağı
    var videoSecici: some View {
        PhotosPicker(selection: $secilenVideo, matching: .videos) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color.rvCard)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rvLine, style: StrokeStyle(lineWidth: 1, dash: [6])))
                VStack(spacing: 8) {
                    Image(systemName: videoURL != nil ? "checkmark.circle.fill" : "video.badge.plus")
                        .font(.system(size: 34)).foregroundStyle(tema.grad)
                    Text(videoURL != nil ? yerel.t("videoSecildi") : yerel.t("videoSec")).font(.subheadline.bold()).foregroundStyle(.rvText)
                    Text(yerel.t("videoSecAlt")).font(.caption).foregroundStyle(.rvMut).multilineTextAlignment(.center)
                }.padding(.vertical, 30)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
        }
    }

    var klipSecenekler: some View {
        VStack(spacing: 12) {
            HStack {
                Text(yerel.t("klipAdet")).foregroundStyle(.rvMut)
                Spacer()
                Stepper("\(klipAdet)", value: $klipAdet, in: 1...6).fixedSize().tint(tema.c1)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Color.rvCard, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rvLine, lineWidth: 1))
            secici(yerel.t("klipFormat"), klipFormatlar, $klipFormat)
            secici(yerel.t("klipAltyazi"), klipAltyazilar, $klipAltyazi)
            secici(yerel.t("klipMuzik"), klipMuzikler, $klipMuzik)
        }
    }

    // MARK: faceswap — iki görsel (kaynak yüz + hedef)
    var ikiGorselSecici: some View {
        HStack(spacing: 12) {
            tekGorsel(arac.id == "tryon" ? yerel.t("tryonKisi") : yerel.t("kaynakYuz"), $secilenFoto, gorselData)
            tekGorsel(arac.id == "tryon" ? yerel.t("tryonKiyafet") : yerel.t("hedefGorsel"), $secilenFoto2, gorselData2)
        }
    }
    func tekGorsel(_ baslik: String, _ sec: Binding<PhotosPickerItem?>, _ veri: Data?) -> some View {
        VStack(spacing: 6) {
            Text(baslik).font(.caption.bold()).foregroundStyle(.rvMut)
            PhotosPicker(selection: sec, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.rvCard)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rvLine, style: StrokeStyle(lineWidth: 1, dash: [6])))
                    if let d = veri, let ui = UIImage(data: d) {
                        Image(uiImage: ui).resizable().scaledToFit().frame(maxHeight: 150).clipShape(.rect(cornerRadius: 14))
                    } else {
                        Image(systemName: "photo.badge.plus").font(.system(size: 28)).foregroundStyle(tema.grad).padding(.vertical, 36)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
    }

    // MARK: pdf — dosya seçici
    var pdfSecici: some View {
        Button { pdfImport = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color.rvCard)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rvLine, style: StrokeStyle(lineWidth: 1, dash: [6])))
                VStack(spacing: 8) {
                    Image(systemName: pdfData != nil ? "doc.fill" : "doc.badge.plus").font(.system(size: 34)).foregroundStyle(tema.grad)
                    Text(pdfData != nil ? yerel.t("pdfSecildi") : yerel.t("pdfSec")).font(.subheadline.bold()).foregroundStyle(.rvText)
                }.padding(.vertical, 30)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
        }
        .fileImporter(isPresented: $pdfImport, allowedContentTypes: [.pdf]) { res in
            if case .success(let url) = res, url.startAccessingSecurityScopedResource() {
                pdfData = try? Data(contentsOf: url)
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    // MARK: görsel seçici
    var gorselSecici: some View {
        PhotosPicker(selection: $secilenFoto, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color.rvCard)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rvLine, style: StrokeStyle(lineWidth: 1, dash: [6])))
                if let d = gorselData, let ui = UIImage(data: d) {
                    Image(uiImage: ui).resizable().scaledToFit().frame(maxHeight: 220).clipShape(.rect(cornerRadius: 16))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus").font(.system(size: 34)).foregroundStyle(tema.grad)
                        Text(yerel.t("gorselSec")).font(.subheadline.bold()).foregroundStyle(.rvText)
                        Text(yerel.t("gorselSecAlt")).font(.caption).foregroundStyle(.rvMut)
                    }.padding(.vertical, 30)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130)
        }
    }

    var metinAlani: some View {
        TextField(ipucu, text: $girdi, axis: .vertical)
            .lineLimit(3...10).padding().foregroundStyle(.rvText)
            .background(Color.rvCard, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rvLine, lineWidth: 1))
    }

    var dilSecici: some View {
        HStack {
            Text(yerel.t("hedefDil")).foregroundStyle(.rvMut)
            Spacer()
            Picker("", selection: $hedefDil) {
                ForEach(diller.sorted(by: {$0.value < $1.value}), id: \.key) { Text($0.value).tag($0.key) }
            }.tint(tema.c1)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Color.rvCard, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rvLine, lineWidth: 1))
    }

    func secici(_ ad: String, _ secenek: [(String,String)], _ bag: Binding<String>) -> some View {
        HStack {
            Text(ad).foregroundStyle(.rvMut)
            Spacer()
            Picker("", selection: bag) {
                ForEach(secenek, id: \.0) { Text($0.1).tag($0.0) }
            }.tint(tema.c1)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Color.rvCard, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rvLine, lineWidth: 1))
    }

    var uretButonu: some View {
        Button { Task { await uret() } } label: {
            HStack(spacing: 8) {
                if api.yukleniyor { ProgressView().tint(.white) }
                Image(systemName: api.yukleniyor ? "hourglass" : "wand.and.sparkles")
                Text(api.yukleniyor ? yerel.t("uretiliyor") : yerel.t("uret")).font(.headline.bold())
                Text("⚡\(arac.kredi)").opacity(0.85)
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(hazir ? AnyShapeStyle(tema.grad) : AnyShapeStyle(Color.gray.opacity(0.4)), in: .rect(cornerRadius: 16))
            .shadow(color: hazir ? tema.c1.opacity(0.35) : .clear, radius: 12, y: 5)
        }
        .disabled(api.yukleniyor || !hazir)
    }

    var kotaKutu: some View {
        VStack(spacing: 10) {
            Text(yerel.t("kotaBitti")).font(.subheadline.bold()).foregroundStyle(.rvText)
            Text(yerel.t("kotaAlt")).font(.caption).foregroundStyle(.rvMut).multilineTextAlignment(.center)
            NavigationLink { KrediView() } label: {
                Text(yerel.t("krediAl")).font(.subheadline.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(tema.grad, in: .rect(cornerRadius: 13))
            }
        }
        .padding(16).frame(maxWidth: .infinity)
        .background(Color.rvCard, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rvLine, lineWidth: 1))
    }

    var hataKutu: some View {
        Text(hata).font(.subheadline).foregroundStyle(.orange)
            .padding().frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.rvCard, in: .rect(cornerRadius: 14))
    }

    func sonucGorunum(_ s: UretimSonuc) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let klipler = s.klipler, !klipler.isEmpty {
                Text(yerel.t("klipHazir")).font(.headline.bold()).foregroundStyle(.rvText)
                ForEach(klipler) { k in klipKart(k) }
            }
            // fal.ai video (text→video / image→video)
            if let v = s.videoURL, let u = URL(string: v) {
                VideoPlayer(player: AVPlayer(url: u)).frame(height: 280).clipShape(.rect(cornerRadius: 18))
                ShareLink(item: u) { paylasEtiket(yerel.t("paylasKaydet"), "square.and.arrow.up") }
            }
            // fal.ai müzik (text→music)
            if let a = s.audioURL, let u = URL(string: a) {
                Button { calar?.stop(); urlSesOynat(u) } label: { paylasEtiket(yerel.t("sesiOynat"), "play.circle.fill") }
                ShareLink(item: u) { paylasEtiket(yerel.t("paylasKaydet"), "square.and.arrow.up") }
            }
            // fal.ai try-on (URL görsel)
            if let g = s.gorselURL, let u = URL(string: g) {
                AsyncImage(url: u) { img in img.resizable().scaledToFit() } placeholder: { ProgressView() }
                    .clipShape(.rect(cornerRadius: 18))
                ShareLink(item: u) { paylasEtiket(yerel.t("paylasKaydet"), "square.and.arrow.up") }
            }
            if let d = s.gorselData, let ui = UIImage(data: d) {
                Image(uiImage: ui).resizable().scaledToFit().clipShape(.rect(cornerRadius: 18))
                ShareLink(item: Image(uiImage: ui), preview: SharePreview("RealVirtuality AI", image: Image(uiImage: ui))) {
                    paylasEtiket(yerel.t("paylasKaydet"), "square.and.arrow.up")
                }
            }
            if let m = s.metin, !m.isEmpty {
                Text(m).textSelection(.enabled).font(.callout).foregroundStyle(.rvText)
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.rvCard, in: .rect(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rvLine, lineWidth: 1))
                ShareLink(item: m) { paylasEtiket(yerel.t("kopyalaPaylas"), "doc.on.doc") }
            }
        }
    }

    func klipKart(_ k: Klip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(k.emoji)
                Text(k.baslik).font(.subheadline.bold()).foregroundStyle(.rvText).lineLimit(2)
            }
            if let u = URL(string: k.url) {
                VideoPlayer(player: AVPlayer(url: u))
                    .frame(height: klipFormat == "dikey" ? 300 : 190)
                    .clipShape(.rect(cornerRadius: 14))
                ShareLink(item: u) { paylasEtiket(yerel.t("paylasKaydet"), "square.and.arrow.up") }
            }
        }
        .padding(12)
        .background(Color.rvCard, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rvLine, lineWidth: 1))
    }

    var sesGorunum: some View {
        Button { sesOynat() } label: { paylasEtiket(yerel.t("sesiOynat"), "play.circle.fill") }
    }

    func paylasEtiket(_ t: String, _ ik: String) -> some View {
        Label(t, systemImage: ik).font(.subheadline.bold()).foregroundStyle(.rvText)
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(Color.rvCard, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rvLine, lineWidth: 1))
    }

    var ipucu: String {
        if arac.id == "avatar" { return yerel.t("ip_avatar") }
        if arac.id == "duzenle" { return yerel.t("ip_duzenle") }
        if arac.id == "bgreplace" { return yerel.t("ip_bgreplace") }
        switch arac.kind {
        case .prompt: return yerel.t("ip_prompt")
        case .ceviri: return yerel.t("ip_ceviri")
        case .gorselArti: return yerel.t("ip_gorselArti")
        case .icerik: return yerel.t("ip_icerik")
        case .url: return yerel.t("ip_url")
        default: return yerel.t("ip_default")
        }
    }

    // MARK: üretim
    func uret() async {
        hata = ""; kotaUyari = false; sonuc = nil; sesData = nil
        let b64: String? = gorselData.map { "data:image/jpeg;base64," + $0.base64EncodedString() }

        // TTS — ses döndürür
        if arac.id == "tts" {
            let (d, e) = await api.sesUret(girdi)
            if let e = e { e == "kota_doldu" ? (kotaUyari = true) : (hata = e) } else { sesData = d; sesOynat() }
            return
        }

        // Video oto-klip — multipart upload + iş kuyruğu, ayrı akış
        if arac.kind == .video {
            guard let vurl = videoURL else { return }
            let (s, e) = await api.klipUret(vurl, adet: klipAdet, format: klipFormat, altyazi: klipAltyazi, muzik: klipMuzik)
            if let e = e { e == "kota_doldu" ? (kotaUyari = true) : (hata = e) } else { sonuc = s }
            return
        }

        var body: [String: Any] = ["lang": Locale.current.language.languageCode?.identifier ?? "tr"]
        switch arac.kind {
        case .prompt, .metin: body["prompt"] = girdi; body["text"] = girdi
        case .ceviri: body["text"] = girdi; body["hedef"] = hedefDil
        case .url: body["audio_url"] = girdi
        case .gorselYukle: body["image"] = b64
        case .gorselArti: body["image"] = b64; body["prompt"] = girdi
        case .urunfoto: body["image"] = b64; body["sahne"] = sahne
        case .icerik: body["prompt"] = girdi; body["platform"] = platform
        case .ses: body["text"] = girdi
        case .faceswap: body["source"] = gorselData?.base64EncodedString(); body["target"] = gorselData2?.base64EncodedString()
        case .pdf: body["pdf"] = pdfData?.base64EncodedString()
        case .video: break   // video ayrı akışta (yukarıda) işlenir
        }
        if kaliteAraclar.contains(arac.id) { body["kalite"] = kalite }
        if oranAraclar.contains(arac.id) { body["oran"] = oran }
        let (s, e) = await api.calistir("/api/\(arac.id)", body)
        if let e = e { e == "kota_doldu" ? (kotaUyari = true) : (hata = e) } else { sonuc = s }
    }

    func sesOynat() {
        guard let d = sesData else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        calar = try? AVAudioPlayer(data: d); calar?.play()
    }
    func urlSesOynat(_ u: URL) {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        urlCalar = AVPlayer(url: u); urlCalar?.play()
    }
}
