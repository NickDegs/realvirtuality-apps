import SwiftUI

// WhatsApp tarzı ülke kodu seçici (bayrak + isim + +kod, aranabilir liste)
struct UlkeKod: Identifiable, Hashable {
    let id: String      // ISO kodu
    let bayrak: String  // bayrak emoji
    let ad: String      // ülke adı
    let kod: String     // arama kodu (+ olmadan)
}

let ULKE_KODLARI: [UlkeKod] = [
    .init(id:"TR",bayrak:"🇹🇷",ad:"Türkiye",kod:"90"),
    .init(id:"US",bayrak:"🇺🇸",ad:"United States",kod:"1"),
    .init(id:"GB",bayrak:"🇬🇧",ad:"United Kingdom",kod:"44"),
    .init(id:"DE",bayrak:"🇩🇪",ad:"Deutschland",kod:"49"),
    .init(id:"FR",bayrak:"🇫🇷",ad:"France",kod:"33"),
    .init(id:"NL",bayrak:"🇳🇱",ad:"Nederland",kod:"31"),
    .init(id:"BE",bayrak:"🇧🇪",ad:"Belgique",kod:"32"),
    .init(id:"AT",bayrak:"🇦🇹",ad:"Österreich",kod:"43"),
    .init(id:"CH",bayrak:"🇨🇭",ad:"Schweiz",kod:"41"),
    .init(id:"ES",bayrak:"🇪🇸",ad:"España",kod:"34"),
    .init(id:"IT",bayrak:"🇮🇹",ad:"Italia",kod:"39"),
    .init(id:"PT",bayrak:"🇵🇹",ad:"Portugal",kod:"351"),
    .init(id:"SE",bayrak:"🇸🇪",ad:"Sverige",kod:"46"),
    .init(id:"NO",bayrak:"🇳🇴",ad:"Norge",kod:"47"),
    .init(id:"DK",bayrak:"🇩🇰",ad:"Danmark",kod:"45"),
    .init(id:"FI",bayrak:"🇫🇮",ad:"Suomi",kod:"358"),
    .init(id:"PL",bayrak:"🇵🇱",ad:"Polska",kod:"48"),
    .init(id:"CZ",bayrak:"🇨🇿",ad:"Česko",kod:"420"),
    .init(id:"RU",bayrak:"🇷🇺",ad:"Россия",kod:"7"),
    .init(id:"UA",bayrak:"🇺🇦",ad:"Україна",kod:"380"),
    .init(id:"AZ",bayrak:"🇦🇿",ad:"Azərbaycan",kod:"994"),
    .init(id:"AE",bayrak:"🇦🇪",ad:"الإمارات",kod:"971"),
    .init(id:"SA",bayrak:"🇸🇦",ad:"السعودية",kod:"966"),
    .init(id:"QA",bayrak:"🇶🇦",ad:"قطر",kod:"974"),
    .init(id:"KW",bayrak:"🇰🇼",ad:"الكويت",kod:"965"),
    .init(id:"BH",bayrak:"🇧🇭",ad:"البحرين",kod:"973"),
    .init(id:"OM",bayrak:"🇴🇲",ad:"عُمان",kod:"968"),
    .init(id:"JO",bayrak:"🇯🇴",ad:"الأردن",kod:"962"),
    .init(id:"LB",bayrak:"🇱🇧",ad:"لبنان",kod:"961"),
    .init(id:"EG",bayrak:"🇪🇬",ad:"مصر",kod:"20"),
    .init(id:"MA",bayrak:"🇲🇦",ad:"المغرب",kod:"212"),
    .init(id:"DZ",bayrak:"🇩🇿",ad:"الجزائر",kod:"213"),
    .init(id:"TN",bayrak:"🇹🇳",ad:"تونس",kod:"216"),
    .init(id:"IQ",bayrak:"🇮🇶",ad:"العراق",kod:"964"),
    .init(id:"CA",bayrak:"🇨🇦",ad:"Canada",kod:"1"),
    .init(id:"AU",bayrak:"🇦🇺",ad:"Australia",kod:"61"),
    .init(id:"IN",bayrak:"🇮🇳",ad:"India",kod:"91"),
    .init(id:"PK",bayrak:"🇵🇰",ad:"Pakistan",kod:"92"),
    .init(id:"BR",bayrak:"🇧🇷",ad:"Brasil",kod:"55"),
    .init(id:"MX",bayrak:"🇲🇽",ad:"México",kod:"52"),
    .init(id:"GR",bayrak:"🇬🇷",ad:"Ελλάδα",kod:"30"),
    .init(id:"BG",bayrak:"🇧🇬",ad:"България",kod:"359"),
    .init(id:"RO",bayrak:"🇷🇴",ad:"România",kod:"40"),
    .init(id:"CY",bayrak:"🇨🇾",ad:"Κύπρος",kod:"357"),
    .init(id:"JP",bayrak:"🇯🇵",ad:"日本",kod:"81"),
    .init(id:"KR",bayrak:"🇰🇷",ad:"한국",kod:"82"),
    .init(id:"CN",bayrak:"🇨🇳",ad:"中国",kod:"86"),
]

let ULKE_VARSAYILAN: UlkeKod = ULKE_KODLARI.first(where: { $0.id == "TR" }) ?? ULKE_KODLARI[0]

// ülke kodu + yerel numara → +905xx... (baştaki 0'ları atar, sadece rakam)
func tamNumara(_ kod: String, _ yerel: String) -> String {
    let d = String(yerel.filter { $0.isNumber }.drop(while: { $0 == "0" }))
    return "+\(kod)\(d)"
}

struct UlkeKodSecici: View {
    @Binding var secili: UlkeKod
    @State private var acik = false
    @State private var ara = ""
    var body: some View {
        Button { acik = true } label: {
            HStack(spacing: 5) {
                Text(secili.bayrak)
                Text("+\(secili.kod)").font(.body).foregroundStyle(.primary)
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $acik) {
            NavigationStack {
                List(ULKE_KODLARI.filter { ara.isEmpty || $0.ad.localizedCaseInsensitiveContains(ara) || $0.kod.contains(ara) }) { u in
                    Button {
                        secili = u; acik = false; ara = ""
                    } label: {
                        HStack {
                            Text(u.bayrak)
                            Text(u.ad).foregroundStyle(.primary)
                            Spacer()
                            Text("+\(u.kod)").foregroundStyle(.secondary)
                        }
                    }
                }
                .searchable(text: $ara, prompt: "Ülke ara / search")
                .navigationTitle("Ülke kodu").navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
