# RealVirtuality AI — iOS (Native SwiftUI 26 + Liquid Glass)

Native iOS uygulaması. realvirtuality.app API'sini kullanır (e-posta OTP girişi,
kredi sistemi, görsel/yazı/çeviri/SEO/kod/logo üretimi). Tasarım: iOS 26 **Liquid Glass**
(`.glassEffect`, `GlassEffectContainer`).

## Dosyalar
- `RealVirtualityAI/RealVirtualityAIApp.swift` — App girişi, tema, araç listesi
- `RealVirtualityAI/API.swift` — API istemcisi (çerez oturumu, async/await)
- `RealVirtualityAI/ContentView.swift` — ana ekran (Liquid Glass araç kartları)
- `RealVirtualityAI/LoginView.swift` — e-posta OTP girişi
- `RealVirtualityAI/ToolView.swift` — üretim ekranı (sonuç + paylaş)
- `RealVirtualityAI/Assets.xcassets` — app ikonu (3D kristal)
- `project.yml` — XcodeGen spec · `codemagic.yaml` — CI build

## Build (Mac gerekir — iOS Linux'ta derlenmez)
**Seçenek 1 — Xcode (Mac):**
```
brew install xcodegen
cd RealVirtualityAI-iOS
xcodegen generate          # RealVirtualityAI.xcodeproj üretir
open RealVirtualityAI.xcodeproj
# Xcode 26'da: Signing > kendi Apple Developer ekibini seç > Run/Archive
```
**Seçenek 2 — Codemagic CI (Mac'siz):**
- Repoyu GitHub'a koy, Codemagic'e bağla, `codemagic.yaml` workflow'unu çalıştır.
- App Store Connect API key ekle → TestFlight'a otomatik yükler.
- ⚠️ `xcrun altool` KULLANMA (Xcode 16'da kaldırıldı); `publishing.app_store_connect` bloğu kullan.

## Gereken
- iOS 26 deployment target (Liquid Glass için)
- Apple Developer hesabı (imzalama + TestFlight/App Store)
- Bundle ID: `com.nickdegs.realvirtualityai`
