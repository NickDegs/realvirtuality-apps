import SwiftUI

// MARK: - Sektör çözüm modeli (her işletme tipi için konu-uygun arayüz)
struct IsletmeSektor: Identifiable {
    let id: String
    let ad: String
    let slogan: String
    let ikon: String
    let renk1: Color
    let renk2: Color
    let altSektorler: [String]   // bu kategorinin kapsadığı işletme tipleri
    let ozellikler: [String]
    let demo: String?            // nickdegs.com/<path> canlı demo
    var grad: LinearGradient { LinearGradient(colors: [renk1, renk2], startPoint: .topLeading, endPoint: .bottomTrailing) }
}

let ISLETME_SEKTORLER: [IsletmeSektor] = [
    IsletmeSektor(
        id: "restoran", ad: "Restoran & Kafe", slogan: "Komisyonsuz sipariş · QR menü · mutfak ekranı",
        ikon: "fork.knife", renk1: Color(red: 1.0, green: 0.55, blue: 0.16), renk2: Color(red: 0.96, green: 0.26, blue: 0.21),
        altSektorler: ["Restoran", "Lokanta", "Kafe", "Pastane", "Fast-food"],
        ozellikler: ["QR menü & masadan sipariş", "Komisyonsuz online sipariş", "Canlı mutfak ekranı", "WhatsApp sipariş", "Stok & menü yönetimi"],
        demo: "/komisyonsuz"),
    IsletmeSektor(
        id: "randevu", ad: "Randevu İşletmeleri", slogan: "Online takvim · SMS hatırlatma · müşteri kartı",
        ikon: "calendar.badge.clock", renk1: Color(red: 0.13, green: 0.78, blue: 0.74), renk2: Color(red: 0.16, green: 0.50, blue: 0.86),
        altSektorler: ["Kuaför & Güzellik", "Klinik", "Spor Salonu", "Estetik & Spa", "Veteriner"],
        ozellikler: ["Online randevu takvimi", "Otomatik SMS hatırlatma", "Müşteri kartı & geçmiş", "Personel & hizmet yönetimi", "No-show azaltma"],
        demo: "/randevu"),
    IsletmeSektor(
        id: "egitim", ad: "Öğretmen & Eğitim", slogan: "Özel ders · materyal · ödeme takibi",
        ikon: "graduationcap.fill", renk1: Color(red: 0.49, green: 0.36, blue: 1.0), renk2: Color(red: 0.30, green: 0.42, blue: 1.0),
        altSektorler: ["Özel öğretmen", "Etüt merkezi", "Kurs", "Online eğitmen"],
        ozellikler: ["Özel ders randevusu", "Materyal paylaşımı", "Öğrenci & veli takibi", "Ödeme & devam takibi", "Online/yüz yüze ders"],
        demo: "/ogretmen"),
    IsletmeSektor(
        id: "hukuk", ad: "Hukuk Bürosu", slogan: "Dava & süre takibi · şifreli belge kasası",
        ikon: "building.columns.fill", renk1: Color(red: 0.16, green: 0.24, blue: 0.44), renk2: Color(red: 0.74, green: 0.61, blue: 0.30),
        altSektorler: ["Avukat", "Hukuk bürosu", "Danışmanlık"],
        ozellikler: ["Dava & duruşma takibi", "Süre/zamanaşımı uyarısı", "Şifreli belge kasası", "Müvekkil yönetimi", "Audit log & cihaz kilidi"],
        demo: "/hukuk"),
    IsletmeSektor(
        id: "genel", ad: "Diğer İşletmeler", slogan: "Market, otel, kurumsal ve daha fazlası",
        ikon: "briefcase.fill", renk1: Color(red: 0.36, green: 0.40, blue: 0.52), renk2: Color(red: 0.20, green: 0.24, blue: 0.36),
        altSektorler: ["Market & Mağaza", "Otel & Pansiyon", "Kurumsal", "Genel işletme"],
        ozellikler: ["Stok & satış yönetimi", "Personel & rütbe", "QR & dijital kart", "Raporlama", "White-label subdomain"],
        demo: nil),
]

// MARK: - İşletmeler sekmesi (sektörlere ayrılmış ferah katalog)
struct IsletmelerView: View {
    @EnvironmentObject var tema: Tema
    @State private var secilen: IsletmeSektor? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedArka(c1: tema.c1, c2: tema.c2)
                LensFlare(c1: tema.c1, c2: tema.c2).opacity(0.5)
                ScrollView {
                    VStack(spacing: 18) {
                        baslik
                        ForEach(ISLETME_SEKTORLER) { s in
                            BasilabilirKart { secilen = s } content: { SektorKart(sektor: s) }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("İşletmeler").navigationBarTitleDisplayMode(.large)
            .sheet(item: $secilen) { s in SektorDetay(sektor: s) }
        }
        .tint(tema.c1)
    }

    var baslik: some View {
        VStack(spacing: 6) {
            Text("Sektörüne özel çözüm").font(.title3.bold()).foregroundStyle(.rvText)
            Text("İşletme tipini seç, sana uygun sistemi keşfet ve canlı demoyu dene.")
                .font(.subheadline).foregroundStyle(.rvMut).multilineTextAlignment(.center)
        }.padding(.top, 4).padding(.bottom, 2)
    }
}

// MARK: - Sektör kartı (konu-renginde ferah)
struct SektorKart: View {
    let sektor: IsletmeSektor
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gradyan başlık
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(.white.opacity(0.22)).frame(width: 56, height: 56)
                    Image(systemName: sektor.ikon).font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(sektor.ad).font(.title3.bold()).foregroundStyle(.white)
                    Text(sektor.slogan).font(.caption).foregroundStyle(.white.opacity(0.92)).lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline.bold()).foregroundStyle(.white.opacity(0.85))
            }
            .padding(18)
            .background(sektor.grad)

            // Alt sektör çipleri
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sektor.altSektorler, id: \.self) { a in
                        Text(a).font(.caption2.bold()).foregroundStyle(.rvText)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(sektor.renk1.opacity(0.14), in: .capsule)
                    }
                }.padding(.horizontal, 16).padding(.vertical, 13)
            }
        }
        .background(Color.rvCard)
        .clipShape(.rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.rvLine, lineWidth: 1))
        .shadow(color: sektor.renk1.opacity(0.20), radius: 14, y: 7)
    }
}

// MARK: - Sektör detayı (özellikler + canlı demo + CTA)
struct SektorDetay: View {
    let sektor: IsletmeSektor
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    var body: some View {
        NavigationStack {
            ZStack {
                Color.rvBg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Hero
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(.white.opacity(0.22)).frame(width: 60, height: 60)
                                    Image(systemName: sektor.ikon).font(.system(size: 28, weight: .semibold)).foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sektor.ad).font(.title.bold()).foregroundStyle(.white)
                                    Text(sektor.slogan).font(.subheadline).foregroundStyle(.white.opacity(0.92))
                                }
                            }
                        }
                        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(sektor.grad).clipShape(.rect(cornerRadius: 24))

                        // Kimler için
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Kimler için").font(.headline).foregroundStyle(.rvText)
                            FlowChips(items: sektor.altSektorler, renk: sektor.renk1)
                        }

                        // Özellikler
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Neler yapabilirsin").font(.headline).foregroundStyle(.rvText)
                            ForEach(sektor.ozellikler, id: \.self) { o in
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(sektor.renk1)
                                    Text(o).font(.subheadline).foregroundStyle(.rvText)
                                    Spacer()
                                }
                            }
                        }
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.rvCard, in: .rect(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.rvLine, lineWidth: 1))

                        // Canlı demo
                        if let demo = sektor.demo, let url = URL(string: "https://nickdegs.com" + demo) {
                            Button { openURL(url) } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.rectangle.fill")
                                    Text("Canlı Demoyu Aç")
                                }
                                .font(.headline.bold()).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(sektor.grad, in: .rect(cornerRadius: 16))
                            }
                        }

                        Text("Aboneliği Hesabım sekmesinden başlatabilir, kurulum sonrası paneline anında erişebilirsin.")
                            .font(.caption).foregroundStyle(.rvMut).multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity).padding(.top, 2)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Çözüm").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(sektor.renk1) } }
        }
    }
}

// Basit sarmalayan çip dizisi
struct FlowChips: View {
    let items: [String]; let renk: Color
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { a in
                    Text(a).font(.caption.bold()).foregroundStyle(.rvText)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(renk.opacity(0.15), in: .capsule)
                }
            }
        }
    }
}
