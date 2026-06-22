import SwiftUI
import PhotosUI
import AVFoundation

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
    @State private var sonuc: UretimSonuc? = nil
    @State private var sesData: Data? = nil
    @State private var hata = ""
    @State private var kotaUyari = false
    @State private var calar: AVAudioPlayer?

    let diller = ["tr":"Türkçe","en":"English","de":"Deutsch","fr":"Français","es":"Español","ar":"العربية","ru":"Русский"]
    let sahneler = [("beyaz","Beyaz stüdyo"),("mermer","Mermer (lüks)"),("ahsap","Ahşap masa"),("yaprak","Doğal yaprak"),("gradyan","Renkli gradyan"),("mutfak","Mutfak tezgâhı"),("siyah","Siyah (dramatik)"),("pastel","Pastel minimal")]
    let platformlar = [("instagram","Instagram"),("facebook","Facebook"),("tiktok","TikTok"),("linkedin","LinkedIn"),("x","X (Twitter)")]
    let kaliteler = [("kaliteli","💎 Kaliteli (çok kredi)"),("dandik","⚡ Hızlı / Ekonomik (az kredi)")]
    let oranlar = [("kare","⬛ Kare 1:1"),("dikey","📱 Dikey 9:16"),("yatay","🖥️ Yatay 16:9")]
    let kaliteAraclar = ["gorsel","logo","urunfoto","icerik","donustur"]
    let oranAraclar = ["gorsel","logo","icerik"]

    private var gorselGerek: Bool { arac.kind == .gorselYukle || arac.kind == .gorselArti || arac.kind == .urunfoto }
    private var metinGerek: Bool { arac.kind == .prompt || arac.kind == .metin || arac.kind == .ceviri || arac.kind == .gorselArti || arac.kind == .icerik || arac.kind == .url }
    private var hazir: Bool {
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
}
