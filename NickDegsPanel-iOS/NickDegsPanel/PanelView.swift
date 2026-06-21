import SwiftUI
import WebKit

// Giriş sonrası: panel WebView içinde oto-açılır. Görünen içerik tamamen
// sunucudaki hesabın rolüne göre (işletme / süper-admin). Native kabukta admin UI yok.
struct PanelView: View {
    @EnvironmentObject var tema: Tema
    @EnvironmentObject var oturum: Oturum
    @State private var ilerleme: Double = 0
    @State private var yukleniyor = true
    @State private var cikisOnay = false
    @State private var yenile = UUID()

    var body: some View {
        ZStack(alignment: .top) {
            Color.rvBg.ignoresSafeArea()
            if let url = URL(string: oturum.panelURL) {
                PanelWeb(url: url, ilerleme: $ilerleme, yukleniyor: $yukleniyor, yenile: yenile)
                    .ignoresSafeArea(edges: .bottom)
            }
            if yukleniyor { ProgressView(value: ilerleme).tint(tema.c1) }
            // İnce üst bar (çıkış + yenile)
            HStack {
                Button { yenile = UUID() } label: { Image(systemName: "arrow.clockwise") }
                Spacer()
                Button { cikisOnay = true } label: { Image(systemName: "rectangle.portrait.and.arrow.right") }
            }
            .font(.subheadline).foregroundStyle(tema.c1)
            .padding(.horizontal, 18).padding(.top, 4)
            .opacity(yukleniyor ? 0 : 1)
        }
        .confirmationDialog("Çıkış yapılsın mı?", isPresented: $cikisOnay, titleVisibility: .visible) {
            Button("Çıkış Yap", role: .destructive) { oturum.cikis() }
            Button("Vazgeç", role: .cancel) {}
        }
    }
}

struct PanelWeb: UIViewRepresentable {
    let url: URL
    @Binding var ilerleme: Double
    @Binding var yukleniyor: Bool
    let yenile: UUID

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration(); cfg.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.allowsBackForwardNavigationGestures = true
        wv.navigationDelegate = context.coordinator
        wv.addObserver(context.coordinator, forKeyPath: "estimatedProgress", options: .new, context: nil)
        wv.load(URLRequest(url: url)); context.coordinator.web = wv
        return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if context.coordinator.sonYenile != yenile { context.coordinator.sonYenile = yenile; uiView.reload() }
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: PanelWeb; weak var web: WKWebView?; var sonYenile: UUID
        init(_ p: PanelWeb) { parent = p; sonYenile = p.yenile }
        override func observeValue(forKeyPath k: String?, of o: Any?, change: [NSKeyValueChangeKey:Any]?, context: UnsafeMutableRawPointer?) {
            if k == "estimatedProgress", let wv = o as? WKWebView { parent.ilerleme = wv.estimatedProgress; parent.yukleniyor = wv.estimatedProgress < 1.0 }
        }
        func webView(_ w: WKWebView, didFinish n: WKNavigation!) { parent.yukleniyor = false }
        func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { parent.yukleniyor = false }
        deinit { web?.removeObserver(self, forKeyPath: "estimatedProgress") }
    }
}
