import SwiftUI
import StoreKit

@MainActor
final class Store: ObservableObject {
    static let ids = [
        "com.nickdegs.realvirtualityai.credits250",
        "com.nickdegs.realvirtualityai.credits750",
        "com.nickdegs.realvirtualityai.credits2500",
        "com.nickdegs.realvirtualityai.credits7000",
    ]
    @Published var urunler: [Product] = []
    @Published var aliniyor: String? = nil
    @Published var mesaj: String = ""

    func yukle() async {
        urunler = ((try? await Product.products(for: Store.ids)) ?? []).sorted { $0.price < $1.price }
    }

    // Satın al → JWS'i sunucuya gönder → kredi yüklenir
    func satinAl(_ p: Product, api: API) async {
        aliniyor = p.id; mesaj = ""; defer { aliniyor = nil }
        do {
            let sonuc = try await p.purchase()
            switch sonuc {
            case .success(let dogrulama):
                if case .verified(let tx) = dogrulama {
                    // Sunucu krediyi yükledi mi? SADECE başarıda finish et.
                    // Başarısızsa transaction'ı BİTİRME — Transaction.updates/unfinished
                    // (app launch dinleyicisi) tekrar dener, kredi kaybolmaz.
                    if let err = await api.iapDogrula(jws: dogrulama.jwsRepresentation) {
                        mesaj = "Kredi yükleme gecikti, birazdan otomatik tamamlanacak. (\(err))"
                    } else {
                        await tx.finish()
                        mesaj = "✓ Kredi yüklendi!"
                    }
                } else {
                    mesaj = "Satın alma doğrulanamadı."
                }
            case .userCancelled:
                break
            case .pending:
                mesaj = "Ödeme onay bekliyor."
            @unknown default:
                break
            }
        } catch {
            mesaj = error.localizedDescription
        }
    }
}
