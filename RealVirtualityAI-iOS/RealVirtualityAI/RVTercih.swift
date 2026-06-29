import SwiftUI

// MARK: - Kullanıcı tercihleri: favori araçlar + son kullanılanlar (yerel, UserDefaults)
@MainActor final class RVTercih: ObservableObject {
    @Published private(set) var favoriler: [String] = []
    @Published private(set) var sonlar: [String] = []
    private let fKey = "rv_favoriler_v1"
    private let sKey = "rv_sonlar_v1"
    private let sonMax = 12

    init() {
        favoriler = UserDefaults.standard.stringArray(forKey: fKey) ?? []
        sonlar = UserDefaults.standard.stringArray(forKey: sKey) ?? []
    }

    func favoriMi(_ id: String) -> Bool { favoriler.contains(id) }

    func favoriDegis(_ id: String) {
        if let i = favoriler.firstIndex(of: id) { favoriler.remove(at: i) }
        else { favoriler.insert(id, at: 0) }
        UserDefaults.standard.set(favoriler, forKey: fKey)
    }

    func kullanildi(_ id: String) {
        sonlar.removeAll { $0 == id }
        sonlar.insert(id, at: 0)
        if sonlar.count > sonMax { sonlar = Array(sonlar.prefix(sonMax)) }
        UserDefaults.standard.set(sonlar, forKey: sKey)
    }
}
