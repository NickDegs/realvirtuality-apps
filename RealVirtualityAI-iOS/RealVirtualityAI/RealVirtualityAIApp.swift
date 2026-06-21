import SwiftUI

// MARK: - Marka renkleri (Dark + Light uyumlu / adaptif)
extension Color {
    static let rvViolet = Color(red: 0.486, green: 0.361, blue: 1.0)   // #7c5cff (her iki temada aynı)
    static let rvCyan   = Color(red: 0.133, green: 0.827, blue: 0.933) // #22d3ee

    // Arka plan — dark: koyu lacivert, light: çok açık gri-mavi
    static let rvBg = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.039, green: 0.043, blue: 0.078, alpha: 1)
            : UIColor(red: 0.957, green: 0.969, blue: 1.0, alpha: 1) })
    // İkincil arka plan (hero/section)
    static let rvBg2 = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.05, blue: 0.18, alpha: 1)
            : UIColor(red: 0.91, green: 0.93, blue: 1.0, alpha: 1) })
    // Kart yüzeyi
    static let rvCard = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.078, green: 0.090, blue: 0.149, alpha: 1)
            : UIColor(red: 1, green: 1, blue: 1, alpha: 1) })
    // Kart kenarlığı
    static let rvLine = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.09)
            : UIColor(red: 0.83, green: 0.86, blue: 0.95, alpha: 1) })
    // Ana metin
    static let rvText = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.96, alpha: 1) : UIColor(red: 0.06, green: 0.07, blue: 0.13, alpha: 1) })
    // İkincil metin
    static let rvMut = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(red: 0.66, green: 0.70, blue: 0.80, alpha: 1) : UIColor(red: 0.42, green: 0.46, blue: 0.56, alpha: 1) })
}
extension ShapeStyle where Self == Color {
    static var rvViolet: Color { .rvViolet }
    static var rvCyan: Color { .rvCyan }
    static var rvBg: Color { .rvBg }
    static var rvCard: Color { .rvCard }
    static var rvText: Color { .rvText }
    static var rvMut: Color { .rvMut }
}
// Marka gradyanı kısayolu
extension LinearGradient {
    static let marka = LinearGradient(colors: [.rvViolet, .rvCyan], startPoint: .leading, endPoint: .trailing)
}

// MARK: - Araç giriş türleri
enum AracKind { case prompt, metin, ceviri, gorselYukle, gorselArti, urunfoto, icerik, url, ses }

// MARK: - Kategori
enum Kategori: String, CaseIterable, Identifiable {
    case gorsel = "Görsel & Tasarım"
    case icerik = "İçerik & Yazı"
    case sesvideo = "Ses & Video"
    case analiz  = "Görsel Zekâ & Belge"
    var id: String { rawValue }
    var ikon: String {
        switch self {
        case .gorsel: return "paintbrush.pointed.fill"
        case .icerik: return "text.word.spacing"
        case .sesvideo: return "waveform"
        case .analiz: return "doc.viewfinder"
        }
    }
}

// MARK: - Araç tanımı (detay sayfası için zengin alanlar)
struct Arac: Identifiable {
    let id: String
    let ikon: String
    let ad: String
    let aciklama: String       // kısa (kart)
    let slogan: String         // detay başlık altı
    let detay: String          // uzun açıklama
    let ozellikler: [String]
    let kullanim: [String]
    let kind: AracKind
    let kredi: Int
    let kategori: Kategori
    var oneCikan: Bool = false  // vitrinde öne çıkar
}

let ARACLAR: [Arac] = [
    // ── Görsel & Tasarım ──
    Arac(id: "urunfoto", ikon: "camera.aperture", ad: "Ürün Fotoğrafı Stüdyosu",
         aciklama: "Telefon fotoğrafı → pro stüdyo çekimi",
         slogan: "Sıradan ürün fotoğrafını saniyede profesyonel stüdyo çekimine dönüştür.",
         detay: "Ürününün fotoğrafını yükle; yapay zekâ arka planı temizleyip ürünü mermer, ahşap, beyaz stüdyo, doğal yaprak gibi profesyonel sahnelere yerleştirsin. Ürün birebir aynı kalır, sadece sahne ve ışık pro olur. Shopier, Instagram ve web mağazan için stüdyo masrafı olmadan vitrin kalitesi.",
         ozellikler: ["Otomatik arka plan temizleme", "8 profesyonel stüdyo sahnesi", "Ürün birebir korunur", "Vitrin/katalog kalitesi"],
         kullanim: ["E-ticaret & pazaryeri", "Instagram & sosyal medya", "Katalog & menü görseli", "Reklam görseli"],
         kind: .urunfoto, kredi: 6, kategori: .gorsel, oneCikan: true),
    Arac(id: "gorsel", ikon: "photo.artframe", ad: "AI Görsel Üret",
         aciklama: "Yazdığını profesyonel görsele çevir",
         slogan: "Aklındaki her şeyi saniyede yüksek kaliteli görsele dönüştür.",
         detay: "FLUX.1-dev ile metinden 1024px profesyonel görseller üret. Sosyal medya görseli, ürün konsepti, illüstrasyon, afiş — ne istersen yaz, saniyeler içinde gelsin.",
         ozellikler: ["FLUX.1-dev — en kaliteli açık model", "1024px yüksek çözünürlük", "~10 saniyede sonuç", "Sınırsız stil"],
         kullanim: ["Sosyal medya görselleri", "Ürün/konsept görselleri", "Afiş & kapak", "İllüstrasyon"],
         kind: .prompt, kredi: 6, kategori: .gorsel, oneCikan: true),
    Arac(id: "logo", ikon: "seal.fill", ad: "AI Logo Üreteci",
         aciklama: "Markana profesyonel logo",
         slogan: "Markana saniyede modern, profesyonel logo üret.",
         detay: "Marka adını ve konseptini yaz; modern, minimal, profesyonel logo/ikon üretsin. Kafe, marka, uygulama, işletme için — sınırsız dene, beğendiğini indir.",
         ozellikler: ["Modern minimal tasarım", "Marka kimliği", "Sınırsız varyasyon", "Yüksek çözünürlük"],
         kullanim: ["İşletme/marka logosu", "Uygulama ikonu", "Sosyal avatar", "Sticker & rozet"],
         kind: .prompt, kredi: 6, kategori: .gorsel),
    Arac(id: "donustur", ikon: "wand.and.stars", ad: "Görsel Stil Dönüştür",
         aciklama: "Görseli yeni stile çevir (img2img)",
         slogan: "Bir görseli yükle, tarif ettiğin yeni stile dönüştür.",
         detay: "Mevcut görselini referans alıp tarif ettiğin stile dönüştür (FLUX img2img). Eskiz→render, fotoğraf→sanat, ürün→konsept varyasyonu için.",
         ozellikler: ["FLUX img2img", "Referansı korur", "Stil/konsept değişimi", "1024px çıktı"],
         kullanim: ["Eskiz → render", "Fotoğraf → sanat", "Konsept varyasyonu", "Stil aktarımı"],
         kind: .gorselArti, kredi: 6, kategori: .gorsel),
    Arac(id: "upscale", ikon: "arrow.up.left.and.arrow.down.right", ad: "Görsel Büyüt (Upscale)",
         aciklama: "Bulanık görseli 4x netleştir",
         slogan: "Küçük/bulanık görselleri 4x büyüt, netleştir.",
         detay: "Real-ESRGAN ile düşük çözünürlüklü görselleri kalite kaybı olmadan 4 katına çıkar. Eski fotoğraflar, ürün görselleri, ekran görüntüleri için ideal.",
         ozellikler: ["Real-ESRGAN AI", "4x büyütme", "Detay & keskinlik", "Saniyeler içinde"],
         kullanim: ["Eski/düşük çözünürlük foto", "Ürün görseli iyileştirme", "Baskı için büyütme", "Logo netleştirme"],
         kind: .gorselYukle, kredi: 3, kategori: .gorsel),
    Arac(id: "bgremove", ikon: "scissors", ad: "Arka Plan Sil",
         aciklama: "Tek tıkla şeffaf PNG",
         slogan: "Arka planı tek tıkla sil, şeffaf PNG indir.",
         detay: "Görselin arka planını yapay zekâ ile saniyede temizle, şeffaf PNG olarak al. Ürün fotoğrafı, profil, logo için ideal — remove.bg alternatifi.",
         ozellikler: ["AI nesne/insan algılama", "Şeffaf PNG", "~1 saniyede", "Temiz kenarlar"],
         kullanim: ["E-ticaret ürün foto", "Profil/vesikalık", "Logo & sticker", "Tasarım kesme"],
         kind: .gorselYukle, kredi: 2, kategori: .gorsel),

    // ── İçerik & Yazı ──
    Arac(id: "icerik", ikon: "sparkles.rectangle.stack", ad: "Sosyal Medya İçerik Paketi",
         aciklama: "Görsel + caption + hashtag tek tıkla",
         slogan: "İşletmeni yaz; paylaşıma hazır görsel + metin + hashtag tek tıkla gelsin.",
         detay: "İşletmeni/konunu yaz, platformu seç; yapay zekâ dikkat çeken bir görsel + güçlü açılışlı caption + ilgili hashtag'leri kendi dilinde tek seferde üretsin. Her gün ne paylaşacağını düşünme, ajans parası verme. Aylık içerik aboneliği için ideal.",
         ozellikler: ["Görsel + caption + hashtag", "5 platforma uygun ton", "Çok dilli", "Abonelik dostu"],
         kullanim: ["Günlük sosyal medya", "Kampanya & duyuru", "Ürün tanıtımı", "Ajansa alternatif"],
         kind: .icerik, kredi: 6, kategori: .icerik, oneCikan: true),
    Arac(id: "pro", ikon: "brain.head.profile", ad: "AI Pro Asistan",
         aciklama: "gpt-oss 120B — güçlü akıl yürütme",
         slogan: "En zorlu sorular için üst seviye akıl yürüten AI.",
         detay: "120 milyar parametreli gpt-oss modeliyle adım adım akıl yürütme: derin analiz, strateji, planlama, matematik, araştırma ve karmaşık problem çözümü. Standart sohbetin bir üst ligi.",
         ozellikler: ["gpt-oss-120B model", "Derin analiz & strateji", "Matematik & teknik", "Yapılandırılmış cevap"],
         kullanim: ["İş/strateji analizi", "Araştırma & rapor", "Teknik çözüm", "Karar desteği"],
         kind: .metin, kredi: 3, kategori: .icerik, oneCikan: true),
    Arac(id: "yazi", ikon: "pencil.and.scribble", ad: "AI Yazı Asistanı",
         aciklama: "Metin yaz / özetle / yeniden yaz",
         slogan: "Aklındaki her metni saniyede profesyonelce yazdır.",
         detay: "Sosyal medya paylaşımı, ürün açıklaması, e-posta, reklam metni, blog, özet veya yeniden yazım — kendi dilinde hazır metni saniyede al.",
         ozellikler: ["Llama 3.3 70B", "Çok dilli", "Yaz/özetle/yeniden yaz", "Anında hazır metin"],
         kullanim: ["Sosyal & reklam metni", "Ürün açıklaması", "E-posta & resmi yazı", "Blog & özet"],
         kind: .metin, kredi: 2, kategori: .icerik),
    Arac(id: "ceviri", ikon: "character.bubble.fill", ad: "AI Çeviri",
         aciklama: "Anlamı koruyarak 7+ dile çevir",
         slogan: "Metinlerini anlamı koruyarak akıcı şekilde çevir.",
         detay: "Herhangi bir metni 7+ dile, anlamı ve tonu koruyarak profesyonelce çevir. Makine çevirisinden daha doğal sonuç.",
         ozellikler: ["7+ dil", "Anlam & ton korunur", "Akıcı sonuç", "Uzun metin"],
         kullanim: ["Ticari yazışma", "Ürün açıklaması", "Web & içerik", "Altyazı & doküman"],
         kind: .ceviri, kredi: 1, kategori: .icerik),
    Arac(id: "seo", ikon: "magnifyingglass", ad: "SEO & Anahtar Kelime",
         aciklama: "Başlık + meta + anahtar kelime",
         slogan: "Ürün/konuna SEO başlık, meta açıklama ve anahtar kelime üret.",
         detay: "Ürün veya konunu yaz; tıklanan SEO başlığı, meta açıklama ve hedef anahtar kelimeleri kendi dilinde üretsin. Arama sıralamanı yükselt.",
         ozellikler: ["SEO başlık + meta", "12 hedef kelime", "Çok dilli", "E-ticaret & blog"],
         kullanim: ["Ürün sayfası SEO", "İçerik optimizasyonu", "Reklam kelimeleri", "Pazaryeri listeleme"],
         kind: .metin, kredi: 2, kategori: .icerik),
    Arac(id: "sohbet", ikon: "bubble.left.and.bubble.right.fill", ad: "AI Sohbet",
         aciklama: "Her şeyi sor, akıllı cevap al",
         slogan: "Aklındaki her soruyu sor, anında akıllı cevap al.",
         detay: "Soru-cevap, fikir üretme, planlama, kod, açıklama — kendi dilinde akıllı bir asistanla sohbet et.",
         ozellikler: ["Llama 3.3 70B", "Çok dilli", "Her konuda yardım", "Hızlı"],
         kullanim: ["Soru-cevap", "Fikir üretme", "Planlama", "Açıklama"],
         kind: .metin, kredi: 1, kategori: .icerik),
    Arac(id: "kod", ikon: "chevron.left.forwardslash.chevron.right", ad: "AI Kod Asistanı",
         aciklama: "Kod yaz / açıkla / düzelt",
         slogan: "Kod yaz, açıkla, hatasını bul — saniyede.",
         detay: "İstediğin işi tarif et; temiz çalışır kod yazsın, mevcut kodunu açıklasın veya hatanı bulsun. Python, JS, SQL, HTML ve daha fazlası.",
         ozellikler: ["Yaz / açıkla / düzelt", "Tüm popüler diller", "Açıklama kendi dilinde", "Llama 3.3 70B"],
         kullanim: ["Fonksiyon/script", "Hata ayıklama", "Kod öğrenme", "SQL/regex"],
         kind: .metin, kredi: 2, kategori: .icerik),

    // ── Ses & Video ──
    Arac(id: "tts", ikon: "speaker.wave.3.fill", ad: "Metni Seslendir",
         aciklama: "Metni doğal sese çevir",
         slogan: "Yazdığını doğal, akıcı sese dönüştür.",
         detay: "Yazdığın metni doğal sese çevir. Video dış sesi, podcast, sesli kitap, IVR için saniyeler içinde ses dosyası.",
         ozellikler: ["Doğal ses", "Anında ses dosyası", "Sınırsız uzunluk", "İndir & kullan"],
         kullanim: ["Video voiceover", "Sesli kitap/podcast", "Sosyal anlatım", "IVR anonsu"],
         kind: .metin, kredi: 2, kategori: .sesvideo),
    Arac(id: "transkript", ikon: "waveform.and.mic", ad: "Sesi Yazıya Çevir",
         aciklama: "Ses/video → metin + altyazı",
         slogan: "Ses ve videolarını dakikalar içinde metne çevir.",
         detay: "Whisper large-v3 ile ses/video URL'ini metne çevir, zaman damgalı altyazı çıkar. 90+ dil desteği.",
         ozellikler: ["Whisper large-v3", "90+ dil", "Zaman damgalı altyazı", "Toplantı/podcast/video"],
         kullanim: ["Video altyazısı", "Toplantı notu", "Podcast → blog", "Ders metni"],
         kind: .url, kredi: 3, kategori: .sesvideo),

    // ── Görsel Zekâ & Belge ──
    Arac(id: "aciklama", ikon: "text.below.photo.fill", ad: "Görsel Açıklama (Vision)",
         aciklama: "Görseli AI anlatsın",
         slogan: "Bir görsel yükle, yapay zekâ ne olduğunu kendi dilinde anlatsın.",
         detay: "Görseli yükle; AI içeriğini, nesneleri ve sahneyi detaylıca açıklasın — kendi dilinde. Erişilebilirlik, katalog açıklaması, içerik etiketleme için ideal.",
         ozellikler: ["Llava vision modeli", "Kendi dilinde", "Detaylı analiz", "Alt-metin/SEO dostu"],
         kullanim: ["Erişilebilirlik alt-metni", "Ürün açıklaması", "İçerik etiketleme", "Görsel analiz"],
         kind: .gorselYukle, kredi: 2, kategori: .analiz),
    Arac(id: "vsoru", ikon: "questionmark.bubble.fill", ad: "Görsele Soru Sor",
         aciklama: "Görsel yükle, hakkında sor",
         slogan: "Bir görsel yükle, hakkında istediğini sor.",
         detay: "Görseli yükle ve serbestçe soru sor: 'bu ne markası?', 'kaç kişi var?', 'bu yemeğin tarifi ne?'. AI görseli analiz edip kendi dilinde cevaplar.",
         ozellikler: ["Serbest soru-cevap", "Görsel analizi", "Kendi dilinde", "Llava vision"],
         kullanim: ["Ürün/marka tanıma", "Belge/tablo okuma", "Sahne sorgusu", "Eğitim"],
         kind: .gorselArti, kredi: 2, kategori: .analiz),
    Arac(id: "ocr", ikon: "doc.text.viewfinder", ad: "OCR — Görselden Metin",
         aciklama: "Fotoğraftaki yazıyı metne çevir",
         slogan: "Fotoğraftaki/taranan yazıyı düzenlenebilir metne çevir.",
         detay: "Fatura, fiş, belge, ekran görüntüsü veya tabela fotoğrafındaki yazıyı metne dönüştür (Türkçe + İngilizce). Kopyala, düzenle, kullan.",
         ozellikler: ["Türkçe + İngilizce", "Fatura/fiş/belge/ekran", "Saniyeler içinde", "Kopyalanabilir"],
         kullanim: ["Fatura dijitalleştirme", "Belge → metin", "Ekrandan kopya", "Kartvizit/tabela"],
         kind: .gorselYukle, kredi: 2, kategori: .analiz),
]

// MARK: - App
@main
struct RealVirtualityAIApp: App {
    @StateObject private var api = API()
    @StateObject private var tema = Tema()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(api)
                .environmentObject(tema)
                .preferredColorScheme(tema.renkSemasi)
                .tint(tema.c1)
                .task { await api.durumYukle() }
        }
    }
}
