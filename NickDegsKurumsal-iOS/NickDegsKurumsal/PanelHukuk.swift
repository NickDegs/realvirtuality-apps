import SwiftUI

// MARK: - Hukuk Bürosu paneli (hukuk-sistem) — dava/süre/duruşma/müvekkil/belge
struct HukukPanel: View {
    @ObservedObject var api: PanelAPI
    @EnvironmentObject var tema: Tema
    @State private var sekme = 0

    @State private var sDava = 0, sMuvekkil = 0, sAcil = 0, sDurusma = 0
    @State private var davalar: [[String: Any]] = []
    @State private var sureler: [[String: Any]] = []
    @State private var durusmalar: [[String: Any]] = []
    @State private var muvekkiller: [[String: Any]] = []
    @State private var belgeler: [[String: Any]] = []
    // formlar
    @State private var dBaslik = "", dKarsi = "", dMahkeme = "", dTur = ""
    @State private var suTur = "", suSon = ""
    @State private var duTarih = "", duSaat = "", duSalon = ""
    @State private var mvAd = "", mvTel = "", mvEmail = ""

    static let asamalar = ["Açıldı", "Devam ediyor", "Karar aşaması", "Kapandı"]
    static func seviyeRenk(_ s: String) -> Color {
        switch s { case "kirmizi": return .red; case "turuncu": return .orange
        case "sari": return .yellow; case "yesil": return .green; default: return .gray }
    }
    let sekmeler = [("Özet", "chart.bar.fill"), ("Davalar", "folder.fill"), ("Süreler", "alarm.fill"),
                    ("Duruşmalar", "building.columns.fill"), ("Müvekkiller", "person.crop.circle"),
                    ("Belgeler", "doc.fill"), ("Personel", "person.2.fill"), ("Ayar", "gearshape.fill")]

    var body: some View {
        VStack(spacing: 0) {
            PanelChips(sekmeler: sekmeler, secili: $sekme, tema: tema)
            switch sekme {
            case 0: ozet
            case 1: davaTab
            case 2: sureTab
            case 3: durusmaTab
            case 4: muvekkilTab
            case 5: belgeTab
            case 6: PersonelSekmesi(api: api, tema: tema)
            default: AyarSekmesi(api: api, tema: tema)
            }
        }.task { await yenile() }
    }

    func yenile() async {
        let s = await api.getObj("stats")
        sDava = s["dava"] as? Int ?? 0; sMuvekkil = s["muvekkil"] as? Int ?? 0
        sAcil = s["acil"] as? Int ?? 0; sDurusma = s["durusma"] as? Int ?? 0
        davalar = await api.getArr("davalar")
        sureler = await api.getArr("sureler")
        durusmalar = await api.getArr("durusmalar")
        muvekkiller = await api.getArr("muvekkiller")
        belgeler = await api.getArr("belgeler")
    }

    var ozet: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    panelKpi("Açık Dava", "\(sDava)", "folder.fill", .blue)
                    panelKpi("Müvekkil", "\(sMuvekkil)", "person.2.fill", .green)
                }
                HStack(spacing: 12) {
                    panelKpi("Acil Süre", "\(sAcil)", "alarm.fill", .red)
                    panelKpi("Duruşma", "\(sDurusma)", "building.columns.fill", .purple)
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    var davaTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text("Dava Ekle").font(.subheadline.bold()).foregroundStyle(.rvText)
                    TextField("Dava başlığı", text: $dBaslik).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    HStack {
                        TextField("Karşı taraf", text: $dKarsi).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                        TextField("Tür", text: $dTur).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    }
                    TextField("Mahkeme", text: $dMahkeme).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    Button { Task { _ = await api.post("dava", ["baslik": dBaslik, "karsi": dKarsi, "mahkeme": dMahkeme, "tur": dTur]); dBaslik = ""; dKarsi = ""; dMahkeme = ""; dTur = ""; await yenile() } } label: {
                        Text("Ekle").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                    }.disabled(dBaslik.isEmpty)
                }
                ForEach(Array(davalar.enumerated()), id: \.offset) { _, d in
                    let id = d["id"] as? Int ?? 0
                    let asama = d["asama"] as? String ?? ""
                    panelKart {
                        Text(d["baslik"] as? String ?? "-").font(.subheadline.bold()).foregroundStyle(.rvText)
                        Text("\(d["muvekkil"] as? String ?? "") · \(d["mahkeme"] as? String ?? "")").font(.caption2).foregroundStyle(.rvMut)
                        HStack {
                            Menu {
                                ForEach(Self.asamalar, id: \.self) { a in
                                    Button(a) { Task { _ = await api.post("dava/\(id)/asama", ["asama": a]); await yenile() } }
                                }
                            } label: {
                                Text(asama.isEmpty ? "Aşama seç" : asama).font(.caption.bold()).foregroundStyle(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 6).background(tema.grad, in: .capsule)
                            }
                            Spacer()
                            Button { Task { _ = await api.post("dava/\(id)/delete"); await yenile() } } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    var sureTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text("Süre / Termin Ekle").font(.subheadline.bold()).foregroundStyle(.rvText)
                    HStack {
                        TextField("Tür (ör. Cevap Dilekçesi)", text: $suTur).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                        TextField("2026-07-15", text: $suSon).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    }
                    Button { Task { _ = await api.post("sure", ["tur": suTur, "son": suSon]); suTur = ""; suSon = ""; await yenile() } } label: {
                        Text("Ekle").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                    }.disabled(suTur.isEmpty || suSon.isEmpty)
                }
                ForEach(Array(sureler.enumerated()), id: \.offset) { _, s in
                    let id = s["id"] as? Int ?? 0
                    let seviye = s["seviye"] as? String ?? "yesil"
                    let kalan = s["kalan"] as? Int ?? 0
                    let bitti = (s["durum"] as? String ?? "") == "Tamamlandı"
                    panelKart {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s["tur"] as? String ?? "-").font(.subheadline.bold()).foregroundStyle(.rvText)
                                Text("\(s["son"] as? String ?? "") · \(s["dava"] as? String ?? "")").font(.caption2).foregroundStyle(.rvMut)
                            }
                            Spacer()
                            if bitti {
                                Text("✔️").font(.caption)
                            } else {
                                Text(kalan < 0 ? "\(-kalan)g geçti" : "\(kalan)g").font(.caption.bold())
                                    .foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 5)
                                    .background(Self.seviyeRenk(seviye), in: .capsule)
                            }
                        }
                        if !bitti {
                            Button { Task { _ = await api.post("sure/\(id)/tamam"); await yenile() } } label: {
                                Text("Tamamlandı işaretle").font(.caption.bold()).foregroundStyle(.green)
                                    .frame(maxWidth: .infinity).padding(.vertical, 7).background(Color.green.opacity(0.12), in: .rect(cornerRadius: 9))
                            }
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    var durusmaTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text("Duruşma Ekle").font(.subheadline.bold()).foregroundStyle(.rvText)
                    HStack {
                        TextField("2026-07-20", text: $duTarih).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                        TextField("10:30", text: $duSaat).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    }
                    TextField("Salon / mahkeme", text: $duSalon).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    Button { Task { _ = await api.post("durusma", ["tarih": duTarih, "saat": duSaat, "salon": duSalon]); duTarih = ""; duSaat = ""; duSalon = ""; await yenile() } } label: {
                        Text("Ekle").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                    }.disabled(duTarih.isEmpty)
                }
                ForEach(Array(durusmalar.enumerated()), id: \.offset) { _, d in
                    let id = d["id"] as? Int ?? 0
                    panelKart {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(d["tarih"] as? String ?? "") \(d["saat"] as? String ?? "")").font(.subheadline.bold()).foregroundStyle(.rvText)
                                Text("\(d["salon"] as? String ?? "") · \(d["dava"] as? String ?? "")").font(.caption2).foregroundStyle(.rvMut)
                            }
                            Spacer()
                            Button { Task { _ = await api.post("durusma/\(id)/delete"); await yenile() } } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    var muvekkilTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                panelKart {
                    Text("Müvekkil Ekle").font(.subheadline.bold()).foregroundStyle(.rvText)
                    TextField("Ad soyad", text: $mvAd).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    HStack {
                        TextField("Telefon", text: $mvTel).keyboardType(.phonePad).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                        TextField("E-posta", text: $mvEmail).keyboardType(.emailAddress).textInputAutocapitalization(.never).padding(8).background(Color.rvBg, in: .rect(cornerRadius: 9))
                    }
                    Button { Task { _ = await api.post("muvekkil", ["ad": mvAd, "telefon": mvTel, "email": mvEmail]); mvAd = ""; mvTel = ""; mvEmail = ""; await yenile() } } label: {
                        Text("Ekle").font(.caption.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 9).background(tema.grad, in: .rect(cornerRadius: 10))
                    }.disabled(mvAd.isEmpty)
                }
                ForEach(Array(muvekkiller.enumerated()), id: \.offset) { _, m in
                    let id = m["id"] as? Int ?? 0
                    panelKart {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m["ad"] as? String ?? "-").font(.subheadline.bold()).foregroundStyle(.rvText)
                                Text(m["telefon"] as? String ?? "").font(.caption2).foregroundStyle(.rvMut)
                            }
                            Spacer()
                            Button { Task { _ = await api.post("muvekkil/\(id)/delete"); await yenile() } } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }

    var belgeTab: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Şifreli belge kasası — yüklemek için web panelini kullanın.").font(.caption2).foregroundStyle(.rvMut).padding(.top, 4)
                if belgeler.isEmpty { Text("Belge yok").foregroundStyle(.rvMut).padding(.top, 30) }
                ForEach(Array(belgeler.enumerated()), id: \.offset) { _, b in
                    panelKart {
                        HStack {
                            Image(systemName: "doc.fill").foregroundStyle(tema.c1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b["ad"] as? String ?? "-").font(.subheadline.bold()).foregroundStyle(.rvText)
                                Text("\(b["tur"] as? String ?? "") · \(b["dava"] as? String ?? "")").font(.caption2).foregroundStyle(.rvMut)
                            }
                            Spacer()
                        }
                    }
                }
            }.padding()
        }.refreshable { await yenile() }
    }
}
