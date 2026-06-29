import SwiftUI

// Share Extension arayüzü — paylaşılan fotoğrafı RV API ile işler (kullanıcının kendi oturumu/kredisi).
// Oturum: ana uygulama App Group'a yazdığı `rv_sid` çerezi okunur (anonim değil → kredi kullanıcıya işler).
struct ShareView: View {
    let imageData: Data?
    let kapat: () -> Void

    @State private var sonuc: Data?
    @State private var calisiyor = false
    @State private var hata = ""
    @State private var bilgi = ""

    private let base = "https://realvirtuality.app"
    private let grup = "group.com.nickdegs.realvirtualityai"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let d = sonuc ?? imageData, let ui = UIImage(data: d) {
                        Image(uiImage: ui).resizable().scaledToFit()
                            .frame(maxHeight: 300).clipShape(.rect(cornerRadius: 16))
                    } else {
                        Text("Görsel okunamadı").foregroundStyle(.secondary)
                    }

                    if calisiyor {
                        ProgressView("İşleniyor…").padding()
                    } else if let d = sonuc, let ui = UIImage(data: d) {
                        ShareLink(item: Image(uiImage: ui),
                                  preview: SharePreview("RealVirtuality AI", image: Image(uiImage: ui))) {
                            etiket("Kaydet / Paylaş", "square.and.arrow.up", dolu: true)
                        }
                        Button { sonuc = nil } label: { etiket("Başka işlem", "arrow.uturn.left", dolu: false) }
                    } else {
                        Text("Bu fotoğrafa ne yapalım?").font(.headline).padding(.top, 4)
                        eylem("Kaliteyi Artır (Upscale)", "arrow.up.left.and.arrow.down.right", "upscale")
                        eylem("Arka Planı Sil", "scissors", "bgremove")
                    }

                    if !bilgi.isEmpty {
                        Text(bilgi).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    if !hata.isEmpty {
                        Text(hata).font(.subheadline).foregroundStyle(.orange)
                    }
                }
                .padding()
            }
            .navigationTitle("RealVirtuality AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Kapat", action: kapat) } }
        }
    }

    func etiket(_ t: String, _ ik: String, dolu: Bool) -> some View {
        Label(t, systemImage: ik).font(.subheadline.bold())
            .foregroundStyle(dolu ? Color.white : Color.primary)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(dolu ? AnyShapeStyle(Color(red: 0.45, green: 0.32, blue: 0.95))
                             : AnyShapeStyle(Color(.secondarySystemBackground)),
                        in: .rect(cornerRadius: 14))
    }

    func eylem(_ t: String, _ ik: String, _ ep: String) -> some View {
        Button { Task { await isle(ep) } } label: { etiket(t, ik, dolu: false) }
            .disabled(imageData == nil || calisiyor)
    }

    func isle(_ ep: String) async {
        guard let d = imageData else { return }
        calisiyor = true; hata = ""; bilgi = ""
        defer { calisiyor = false }
        let b64 = "data:image/jpeg;base64," + d.base64EncodedString()
        var r = URLRequest(url: URL(string: base + "/api/" + ep)!)
        r.httpMethod = "POST"; r.timeoutInterval = 120
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let sid = UserDefaults(suiteName: grup)?.string(forKey: "rv_sid"), !sid.isEmpty {
            r.setValue("sid=\(sid)", forHTTPHeaderField: "Cookie")
        }
        r.httpBody = try? JSONSerialization.data(withJSONObject: [
            "image": b64, "lang": Locale.current.language.languageCode?.identifier ?? "tr"])
        do {
            let (data, _) = try await URLSession.shared.data(for: r)
            guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                hata = "Yanıt okunamadı"; return
            }
            if j["ok"] as? Bool == true, let s = j["image"] as? String,
               let c = s.range(of: ","), let out = Data(base64Encoded: String(s[c.upperBound...])) {
                sonuc = out
            } else if let e = j["err"] as? String, e == "kota_doldu" || e == "giris_gerekli" {
                bilgi = "Krediniz bitti veya giriş gerekli. RealVirtuality AI uygulamasını açıp giriş yapın / kredi alın."
            } else {
                hata = (j["mesaj"] as? String) ?? (j["err"] as? String) ?? "İşlenemedi"
            }
        } catch {
            hata = "Bağlantı hatası — internetinizi kontrol edin."
        }
    }
}
