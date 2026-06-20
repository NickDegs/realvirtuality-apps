import SwiftUI

struct ToolView: View {
    let arac: Arac
    @EnvironmentObject var api: API
    @Environment(\.dismiss) var dismiss
    @State private var girdi = ""
    @State private var hedefDil = "en"
    @State private var sonuc: UretimSonuc? = nil
    @State private var hata = ""

    let diller = ["tr":"Türkçe","en":"English","de":"Deutsch","fr":"Français","es":"Español","ar":"العربية","ru":"Русский"]

    var body: some View {
        ZStack {
            Color.rvBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: arac.ikon).font(.title2)
                            .foregroundStyle(.linearGradient(colors: [.rvViolet, .rvCyan], startPoint: .top, endPoint: .bottom))
                        Text(arac.ad).font(.title2.bold())
                        Spacer()
                        Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.title2) }
                    }

                    TextField(ipucu, text: $girdi, axis: .vertical)
                        .lineLimit(4...10).padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))

                    if arac.kind == .ceviri {
                        Picker("Hedef dil", selection: $hedefDil) {
                            ForEach(diller.sorted(by: {$0.value < $1.value}), id: \.key) { Text($0.value).tag($0.key) }
                        }.pickerStyle(.menu).tint(.rvCyan)
                    }

                    Button { Task { await uret() } } label: {
                        HStack {
                            if api.yukleniyor { ProgressView().tint(.rvBg) }
                            Text(api.yukleniyor ? "Üretiliyor…" : "Üret  ⚡\(arac.kredi)")
                        }
                        .font(.headline.bold()).foregroundStyle(.rvBg)
                        .frame(maxWidth: .infinity).padding()
                        .background(.linearGradient(colors: [.rvViolet, .rvCyan], startPoint: .leading, endPoint: .trailing))
                        .clipShape(.rect(cornerRadius: 16))
                    }.disabled(api.yukleniyor || girdi.isEmpty)

                    if !hata.isEmpty {
                        Text(hata).font(.subheadline).foregroundStyle(.orange)
                            .padding().frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    }

                    if let s = sonuc {
                        if let d = s.gorselData, let ui = UIImage(data: d) {
                            Image(uiImage: ui).resizable().scaledToFit().clipShape(.rect(cornerRadius: 18))
                            ShareLink(item: Image(uiImage: ui), preview: SharePreview("RealVirtuality AI", image: Image(uiImage: ui))) {
                                Label("Paylaş / Kaydet", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity).padding()
                                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                            }
                        } else if let m = s.metin {
                            Text(m).textSelection(.enabled).padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                            ShareLink(item: m) {
                                Label("Kopyala / Paylaş", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity).padding()
                                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    var ipucu: String {
        switch arac.kind {
        case .prompt: return "Ne üretmek istersin? (örn: minimal kahve logosu)"
        case .ceviri: return "Çevrilecek metni yaz"
        default: return "Ne yapmamı istersin?"
        }
    }

    func uret() async {
        hata = ""; sonuc = nil
        let (s, e): (UretimSonuc?, String?)
        switch arac.id {
        case "gorsel", "logo": (s, e) = await api.gorselUret(girdi)
        case "ceviri": (s, e) = await api.metinUret("/api/ceviri", ["text": girdi, "hedef": hedefDil])
        case "seo", "sohbet": (s, e) = await api.metinUret("/api/\(arac.id)", arac.id == "sohbet" ? ["text": girdi] : ["prompt": girdi])
        default: (s, e) = await api.metinUret("/api/\(arac.id)", ["prompt": girdi])
        }
        if let e = e { hata = e } else { sonuc = s }
    }
}
