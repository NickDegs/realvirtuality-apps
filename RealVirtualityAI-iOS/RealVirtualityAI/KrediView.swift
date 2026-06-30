import SwiftUI
import StoreKit

struct KrediView: View {
    @EnvironmentObject var api: API
    @EnvironmentObject var yerel: Yerel
    @StateObject private var store = Store()
    @Environment(\.dismiss) var dismiss
    @State private var gunMesaj = ""
    @State private var gunAliniyor = false
    @State private var davet: DavetBilgi?
    @State private var davetKod = ""
    @State private var davetMesaj = ""

    struct DavetBilgi { let kod: String; let link: String; let sayi: Int; let kazanilan: Int }

    var body: some View {
        ZStack {
            Color.rvBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Text(yerel.t("krediBaslik")).font(.title2.bold())
                        Spacer()
                        Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.title2) }
                    }
                    Text("⚡ \(api.kredi) " + yerel.t("krediVar")).foregroundStyle(.rvCyan).frame(maxWidth: .infinity, alignment: .leading)

                    // GÜNLÜK ÜCRETSİZ KREDİ (paywall screenshot modunda gizli — IAP review'ı ilgilendirmez, paketler öne çıksın)
                    if !RVShot.paywallModu {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            Task {
                                gunAliniyor = true
                                let r = await api.gunlukKrediAl()
                                gunMesaj = r.ok ? "🎁 +\(r.miktar) " + yerel.t("krediVar") + " · \(r.seri)🔥" + (r.bonus ? " BONUS!" : "") : r.mesaj
                                gunAliniyor = false
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "gift.fill").foregroundStyle(.yellow)
                                Text(yerel.t("gunlukKrediAl")).font(.headline).foregroundStyle(.white)
                                Spacer()
                                if gunAliniyor { ProgressView() } else { Image(systemName: "chevron.right").foregroundStyle(.secondary) }
                            }.padding().frame(maxWidth: .infinity).rvGlass(16, interactive: true)
                        }.disabled(gunAliniyor)
                        if !gunMesaj.isEmpty { Text(gunMesaj).font(.caption).foregroundStyle(gunMesaj.hasPrefix("🎁") ? .green : .orange) }
                    }

                    // DAVET ET → KREDİ KAZAN
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) { Image(systemName: "person.2.fill").foregroundStyle(.rvViolet); Text(yerel.t("davetEt")).font(.headline) }
                        Text(yerel.t("davetAciklama")).font(.caption).foregroundStyle(.secondary)
                        if let d = davet {
                            HStack {
                                Text(d.kod).font(.title3.bold().monospaced()).foregroundStyle(.rvCyan)
                                Spacer()
                                ShareLink(item: URL(string: d.link) ?? URL(string: "https://realvirtuality.app")!) {
                                    Label(yerel.t("paylas"), systemImage: "square.and.arrow.up").font(.subheadline.bold())
                                }
                            }
                            if d.sayi > 0 { Text("👥 \(d.sayi) · ⚡ \(d.kazanilan)").font(.caption2).foregroundStyle(.rvMut) }
                        }
                        HStack {
                            TextField(yerel.t("davetKodGir"), text: $davetKod).textInputAutocapitalization(.never).autocorrectionDisabled()
                                .padding(10).background(Color.rvCard, in: .rect(cornerRadius: 10))
                            Button { Task { davetMesaj = await api.davetKullan(davetKod) ?? "✓"; if davetMesaj == "✓" { if let b = await api.davetBilgi() { davet = DavetBilgi(kod: b.kod, link: b.link, sayi: b.davetSayisi, kazanilan: b.kazanilan) } } } } label: {
                                Text(yerel.t("kullan")).font(.subheadline.bold()).foregroundStyle(.white)
                                    .padding(.horizontal, 16).padding(.vertical, 10).background(Color.rvViolet, in: .rect(cornerRadius: 10))
                            }.disabled(davetKod.isEmpty)
                        }
                        if !davetMesaj.isEmpty { Text(davetMesaj == "✓" ? "✓ " + yerel.t("krediVar") : davetMesaj).font(.caption).foregroundStyle(davetMesaj == "✓" ? .green : .orange) }
                    }
                    .padding().frame(maxWidth: .infinity, alignment: .leading).rvGlass(16)
                    .task { if let b = await api.davetBilgi() { davet = DavetBilgi(kod: b.kod, link: b.link, sayi: b.davetSayisi, kazanilan: b.kazanilan) } }
                    }  // /if !RVShot.paywallModu

                    if RVShot.aktif {
                        // Screenshot modu: StoreKit simülatörde ürün döndürmez → gerçek paywall UI'ı mock paketle render
                        ForEach(RVShot.paketler) { p in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(p.ad).font(.headline)
                                    Text(p.aciklama).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Text(p.fiyat).font(.headline.bold()).foregroundStyle(.rvCyan)
                            }
                            .padding().frame(maxWidth: .infinity)
                            .rvGlass(16, interactive: true)
                            .foregroundStyle(.white)
                        }
                    } else if store.urunler.isEmpty {
                        ProgressView().padding(.top, 40)
                    } else {
                        ForEach(store.urunler, id: \.id) { p in
                            Button { Task { await store.satinAl(p, api: api) } } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(p.displayName).font(.headline)
                                        Text(p.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    if store.aliniyor == p.id { ProgressView() }
                                    else { Text(p.displayPrice).font(.headline.bold()).foregroundStyle(.rvCyan) }
                                }
                                .padding().frame(maxWidth: .infinity)
                                .rvGlass(16, interactive: true)
                            }
                            .foregroundStyle(.white).disabled(store.aliniyor != nil)
                        }
                    }

                    if !store.mesaj.isEmpty {
                        Text(store.mesaj).font(.subheadline).foregroundStyle(store.mesaj.hasPrefix("✓") ? .green : .orange)
                    }
                    Text(yerel.t("krediNotu"))
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 6)
                }
                .padding(20)
            }
        }
        .task { await store.yukle() }
        .onChange(of: store.mesaj) { _, yeni in
            if yeni.hasPrefix("✓") { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() } }
        }
    }
}
