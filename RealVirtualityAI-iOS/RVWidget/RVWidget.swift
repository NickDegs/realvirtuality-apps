import WidgetKit
import SwiftUI

// MARK: - RealVirtuality AI ana ekran widget'ı (launcher — App Group YOK, sadece deep-link)
// Dokunma → rvai:// şeması ile uygulama ilgili araca/sekmeye açılır (.onOpenURL).

struct RVEntry: TimelineEntry { let date: Date }

struct RVProvider: TimelineProvider {
    func placeholder(in context: Context) -> RVEntry { RVEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (RVEntry) -> Void) {
        completion(RVEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RVEntry>) -> Void) {
        completion(Timeline(entries: [RVEntry(date: Date())], policy: .never))
    }
}

private let rvGrad = LinearGradient(
    colors: [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.36, green: 0.30, blue: 0.93)],
    startPoint: .topLeading, endPoint: .bottomTrailing)

struct RVWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: RVProvider.Entry

    var body: some View {
        Group {
            if family == .systemSmall { kucuk } else { orta }
        }
        .containerBackground(rvGrad, for: .widget)
    }

    // Küçük: marka + tek dokunuş → görsel üret
    var kucuk: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "wand.and.sparkles").font(.title2).foregroundStyle(.white)
            Spacer()
            Text("RealVirtuality AI").font(.caption.bold()).foregroundStyle(.white)
            Text("Görsel üret").font(.caption2).foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "rvai://gorsel"))
    }

    // Orta: 4 hızlı araç
    var orta: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.sparkles").foregroundStyle(.white)
                Text("RealVirtuality AI").font(.caption.bold()).foregroundStyle(.white)
                Spacer()
            }
            HStack(spacing: 8) {
                tile("Görsel", "photo.artframe", "rvai://gorsel")
                tile("Klip", "scissors.badge.ellipsis", "rvai://klip")
                tile("İçerik", "text.word.spacing", "rvai://icerik")
                tile("Ses", "waveform", "rvai://studyo")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func tile(_ t: String, _ ik: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            VStack(spacing: 5) {
                Image(systemName: ik).font(.title3)
                Text(t).font(.caption2.bold())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(.white.opacity(0.16), in: .rect(cornerRadius: 12))
        }
    }
}

struct RVWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RVWidget", provider: RVProvider()) { entry in
            RVWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("RealVirtuality AI")
        .description("AI araçlarına hızlı erişim")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct RVWidgetBundle: WidgetBundle {
    var body: some Widget { RVWidget() }
}
