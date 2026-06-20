import Foundation
import Capacitor

// iCloud Key-Value Store köprüsü — GİRİŞ GEREKTİRMEZ.
// Kullanıcının iCloud hesabına bağlı, cihazlar arası küçük veri (favoriler) senkronu.
@objc(ICloudKVPlugin)
public class ICloudKVPlugin: CAPPlugin, CAPBridgedPlugin {
    // Capacitor 6 ZORUNLU
    public let identifier = "ICloudKVPlugin"
    public let jsName = "ICloudKV"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "get", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "set", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "remove", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sync", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "available", returnType: CAPPluginReturnPromise)
    ]

    private let store = NSUbiquitousKeyValueStore.default

    override public func load() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(storeChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store)
        store.synchronize()
    }

    @objc func storeChanged(_ note: Notification) {
        // Uzaktan (başka cihaz) değişiklik geldi → JS'e haber ver
        self.notifyListeners("icloudChange", data: [:])
    }

    @objc func available(_ call: CAPPluginCall) {
        let ok = FileManager.default.ubiquityIdentityToken != nil
        call.resolve(["available": ok])
    }

    @objc func get(_ call: CAPPluginCall) {
        let key = call.getString("key") ?? ""
        let val = store.string(forKey: key)
        call.resolve(["value": val as Any])
    }

    @objc func set(_ call: CAPPluginCall) {
        guard let key = call.getString("key") else { call.reject("key gerekli"); return }
        let value = call.getString("value") ?? ""
        store.set(value, forKey: key)
        store.synchronize()
        call.resolve()
    }

    @objc func remove(_ call: CAPPluginCall) {
        let key = call.getString("key") ?? ""
        store.removeObject(forKey: key)
        store.synchronize()
        call.resolve()
    }

    @objc func sync(_ call: CAPPluginCall) {
        store.synchronize()
        call.resolve()
    }
}
