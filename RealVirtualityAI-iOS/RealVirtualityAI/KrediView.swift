import SwiftUI
import StoreKit

struct KrediView: View {
    @EnvironmentObject var api: API
    @EnvironmentObject var yerel: Yerel
    @StateObject private var store = Store()
    @Environment(\.dismiss) var dismiss

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

                    if store.urunler.isEmpty {
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
