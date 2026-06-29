import UIKit
import SwiftUI
import UniformTypeIdentifiers

// Share Extension principal class — paylaşılan görseli yükler, SwiftUI arayüzünü gömer.
class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        loadImage { data in
            DispatchQueue.main.async { self.embed(data) }
        }
    }

    private func loadImage(_ done: @escaping (Data?) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let prov = item.attachments?.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) else {
            return done(nil)
        }
        _ = prov.loadDataRepresentation(for: .image) { data, _ in done(data) }
    }

    private func embed(_ data: Data?) {
        let root = ShareView(imageData: data) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}
