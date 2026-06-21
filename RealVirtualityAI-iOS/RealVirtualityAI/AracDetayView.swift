import SwiftUI

struct AracDetayView: View {
    let arac: Arac
    @EnvironmentObject var api: API
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @State private var aracAcik = false
    @State private var girisAcik = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [.rvBg, .rvBg2, .rvBg], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    baslik
                    // Açıklama
                    Text(yerel.aracMetin(arac.id,"detay"))
                        .font(.callout).foregroundStyle(.rvText).opacity(0.92)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.rvCard, in: .rect(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.rvLine, lineWidth: 1))

                    kutu(baslik: yerel.t("ozellikler"), ikon: "checkmark.seal.fill", oge: yerel.aracDizi(arac.id,"ozellikler"), isaret: "checkmark")
                    kullanimKutu

                    Color.clear.frame(height: 70)
                }
                .padding(.horizontal, 16).padding(.top, 6)
            }
            // Sabit alt CTA
            VStack {
                Spacer()
                kullanButonu
            }
        }
        .navigationTitle(yerel.aracMetin(arac.id,"ad"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.yellow)
                    Text("\(api.girisli ? api.kredi : api.freeKalan)").font(.subheadline.bold()).foregroundStyle(.rvText)
                }
            }
        }
        .navigationDestination(isPresented: $aracAcik) { ToolView(arac: arac) }
        .sheet(isPresented: $girisAcik) { LoginView() }
    }

    var baslik: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [tema.c1.opacity(0.25), tema.c2.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 66, height: 66)
                Image(systemName: arac.ikon).font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(tema.grad)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(yerel.aracMetin(arac.id,"ad")).font(.title2.bold()).foregroundStyle(.rvText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(yerel.aracMetin(arac.id,"slogan")).font(.subheadline).foregroundStyle(.rvMut)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    func kutu(baslik: String, ikon: String, oge: [String], isaret: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(baslik, systemImage: ikon).font(.headline).foregroundStyle(.rvText)
            ForEach(oge, id: \.self) { o in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: isaret).font(.caption.bold()).foregroundStyle(tema.c2).padding(.top, 2)
                    Text(o).font(.subheadline).foregroundStyle(.rvText).opacity(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rvCard, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.rvLine, lineWidth: 1))
    }

    var kullanimKutu: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(yerel.t("kullanimAlanlari"), systemImage: "lightbulb.fill").font(.headline).foregroundStyle(.rvText)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(yerel.aracDizi(arac.id,"kullanim"), id: \.self) { k in
                    Text(k).font(.caption).foregroundStyle(.rvText).opacity(0.9)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .padding(.horizontal, 8)
                        .background(Color.rvBg2.opacity(0.6), in: .rect(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.rvLine, lineWidth: 1))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rvCard, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.rvLine, lineWidth: 1))
    }

    var kullanButonu: some View {
        Button {
            if api.girisli || api.freeKalan > 0 { aracAcik = true } else { girisAcik = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.sparkles")
                Text(yerel.t("hemenKullan"))
                Text("⚡\(arac.kredi)").opacity(0.85)
            }
            .font(.headline.bold()).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(tema.grad, in: .rect(cornerRadius: 18))
            .shadow(color: tema.c1.opacity(0.4), radius: 14, y: 6)
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
    }
}
