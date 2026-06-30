import SwiftUI
import UIKit

// MARK: - Kütüphane: kullanıcının ürettiği tüm çıktılar (kalıcı, tekrar yüklenebilir)
struct KutuphaneView: View {
    @EnvironmentObject var api: API
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @Environment(\.horizontalSizeClass) var hsc
    @State private var items: [KutuphaneItem] = []
    @State private var yukleniyor = true
    @State private var secilenArac: String = "hepsi"
    @State private var detay: KutuphaneItem? = nil

    private var kolonlar: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 18), count: hsc == .regular ? 3 : 2) }
    private var araclar: [String] { ["hepsi"] + Array(Set(items.map { $0.arac })).sorted() }
    private var gosterilen: [KutuphaneItem] { secilenArac == "hepsi" ? items : items.filter { $0.arac == secilenArac } }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.rvBg, .rvBg2, .rvBg], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                LensFlare().opacity(0.6)
                if yukleniyor {
                    ProgressView().tint(tema.c1).scaleEffect(1.3)
                } else if !api.girisli {
                    bilgi("person.crop.circle.badge.questionmark", yerel.p("kutuphaneGiris"))
                } else if items.isEmpty {
                    bilgi("sparkles.rectangle.stack", yerel.p("kutuphaneBos"))
                } else {
                    ScrollView {
                        if araclar.count > 2 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(araclar, id: \.self) { a in cip(a) }
                                }.padding(.horizontal, 20).padding(.top, 4)
                            }
                        }
                        LazyVGrid(columns: kolonlar, spacing: 18) {
                            ForEach(gosterilen) { it in
                                BasilabilirKart { detay = it } content: { KutuphaneKart(item: it) }
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 48)
                    }
                    .scrollIndicators(.hidden)
                    .refreshable { await yukle() }
                }
            }
            .navigationTitle(yerel.p("kutuphaneBaslik"))
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $detay) { it in NavigationStack { KutuphaneDetay(item: it) } }
        }
        .tint(tema.c1)
        .task { await yukle() }
    }

    func yukle() async {
        yukleniyor = true
        if api.girisli { items = await api.kutuphaneGetir() }
        yukleniyor = false
    }

    func cip(_ a: String) -> some View {
        let secili = secilenArac == a
        return Text(a == "hepsi" ? "Hepsi" : a.capitalized)
            .font(.subheadline.bold())
            .padding(.horizontal, 15).padding(.vertical, 9)
            .background(secili ? AnyShapeStyle(tema.grad) : AnyShapeStyle(Color.rvCard), in: .capsule)
            .foregroundStyle(secili ? .white : .rvText)
            .overlay(Capsule().stroke(Color.rvLine, lineWidth: secili ? 0 : 1))
            .onTapGesture { withAnimation(.spring(response: 0.3)) { secilenArac = a } }
    }

    func bilgi(_ ikon: String, _ metin: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: ikon).font(.system(size: 50)).foregroundStyle(tema.grad)
            Text(metin).font(.callout).foregroundStyle(.rvMut).multilineTextAlignment(.center)
        }.padding(40)
    }
}

struct KutuphaneKart: View {
    let item: KutuphaneItem
    @EnvironmentObject var api: API
    @EnvironmentObject var tema: Tema
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if item.gorsel {
                AsyncImage(url: api.ciktiURL(item.id)) { phase in
                    if let img = phase.image { img.resizable().scaledToFill() }
                    else { ZStack { Color.rvCard; ProgressView().tint(tema.c1) } }
                }
                .frame(maxWidth: .infinity).frame(height: 138).clipped()
            } else {
                ZStack(alignment: .topLeading) {
                    LinearGradient(colors: [tema.c1.opacity(0.22), tema.c2.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(item.metin ?? item.prompt ?? "").font(.caption2).foregroundStyle(.rvText).lineLimit(6).padding(12)
                }.frame(maxWidth: .infinity).frame(height: 138).clipped()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(item.baslik?.isEmpty == false ? item.baslik! : item.arac.capitalized)
                    .font(.subheadline.bold()).foregroundStyle(.rvText).lineLimit(1)
                HStack(spacing: 5) {
                    Image(systemName: item.gorsel ? "photo.fill" : "text.alignleft").font(.system(size: 9)).foregroundStyle(tema.c2)
                    Text(item.arac.capitalized).font(.caption2).foregroundStyle(.rvMut).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.rvCard).clipShape(.rect(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.rvLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 7)
    }
}

struct KutuphaneDetay: View {
    let item: KutuphaneItem
    @EnvironmentObject var api: API
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @Environment(\.dismiss) var dismiss
    var body: some View {
        ZStack {
            LinearGradient(colors: [.rvBg, .rvBg2, .rvBg], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if item.gorsel {
                        AsyncImage(url: api.ciktiURL(item.id)) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFit().clipShape(.rect(cornerRadius: 20))
                                    .contextMenu { ShareLink(item: api.ciktiURL(item.id)) { Label("Paylaş", systemImage: "square.and.arrow.up") } }
                            } else { ProgressView().tint(tema.c1).frame(height: 240) }
                        }
                        ShareLink(item: api.ciktiURL(item.id)) {
                            Label(yerel.p("tekrarYukle"), systemImage: "arrow.down.circle.fill")
                                .font(.headline.bold()).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
                                .background(tema.grad, in: .rect(cornerRadius: 16))
                        }
                    } else if let m = item.metin {
                        Text(m).font(.body).foregroundStyle(.rvText).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(18)
                            .background(Color.rvCard, in: .rect(cornerRadius: 18))
                    }
                    if let p = item.prompt, !p.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("İstem").font(.caption.bold()).foregroundStyle(.rvMut)
                                Spacer()
                                Button { UIPasteboard.general.string = p } label: {
                                    Label(yerel.t("promptKopyala"), systemImage: "doc.on.doc").font(.caption2).foregroundStyle(tema.c1)
                                }
                            }
                            Text(p).font(.callout).foregroundStyle(.rvText)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                        .background(Color.rvCard.opacity(0.6), in: .rect(cornerRadius: 16))
                    }
                }.padding(20)
            }
        }
        .navigationTitle(item.arac.capitalized).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { Task { await api.ciktiSil(item.id); dismiss() } } label: { Image(systemName: "trash") }.tint(.red)
            }
        }
    }
}
