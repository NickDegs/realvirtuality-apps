import SwiftUI
import WebKit

// Web panel / hizmet sayfası — native kabuk içinde WebView
struct PanelView: View {
    let url: URL
    let baslik: String
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var yerel: Yerel
    @Environment(\.dismiss) var dismiss
    @State private var ilerleme: Double = 0
    @State private var yukleniyor = true

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WebGorunum(url: url, ilerleme: $ilerleme, yukleniyor: $yukleniyor)
                    .ignoresSafeArea(edges: .bottom)
                if yukleniyor {
                    ProgressView(value: ilerleme)
                        .tint(tema.c1)
                }
            }
            .navigationTitle(baslik)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(yerel.t("kapat")) { dismiss() }.foregroundStyle(tema.c1)
                }
            }
        }
        .tint(tema.c1)
    }
}

struct WebGorunum: UIViewRepresentable {
    let url: URL
    @Binding var ilerleme: Double
    @Binding var yukleniyor: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.allowsBackForwardNavigationGestures = true
        wv.navigationDelegate = context.coordinator
        wv.addObserver(context.coordinator, forKeyPath: "estimatedProgress", options: .new, context: nil)
        wv.load(URLRequest(url: url))
        context.coordinator.web = wv
        return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebGorunum
        weak var web: WKWebView?
        init(_ p: WebGorunum) { parent = p }
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "estimatedProgress", let wv = object as? WKWebView {
                parent.ilerleme = wv.estimatedProgress
                parent.yukleniyor = wv.estimatedProgress < 1.0
            }
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { parent.yukleniyor = false }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { parent.yukleniyor = false }
        deinit { web?.removeObserver(self, forKeyPath: "estimatedProgress") }
    }
}
