import SwiftUI

/// Küçük bir "hakkında" sayfası: birkaç istatistik, titreşim tercihi ve
/// günlüğü düz metin olarak dışa aktarma.
@MainActor
struct SettingsView: View {

    @ObservedObject var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var hapticsEnabled = Haptics.isEnabled
    @State private var exportedText: ExportPayload?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 18) {
                        statistic(value: "\(store.writtenDayCount)", label: "yazılan gün")
                        Divider()
                        statistic(value: "\(store.streak)", label: "günlük seri")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }

                Section("Tercihler") {
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Titreşim", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .tint(Theme.accent)
                    .onChange(of: hapticsEnabled) { _, newValue in
                        Haptics.isEnabled = newValue
                    }
                }

                Section("Günlüğün") {
                    Button {
                        exportedText = ExportPayload(text: store.exportedText())
                    } label: {
                        Label("Düz metin olarak dışa aktar", systemImage: "square.and.arrow.up")
                    }
                    .disabled(store.writtenDayCount == 0)
                }

                Section {
                    Text("Bütün kayıtların yalnızca bu cihazda, uygulamanın kendi klasöründe saklanıyor. Hiçbir veri sunucuya gönderilmiyor.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .navigationTitle("Günlük")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { dismiss() }
                }
            }
        }
        .sheet(item: $exportedText) { payload in
            ShareSheet(items: [payload.text])
        }
    }

    private func statistic(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExportPayload: Identifiable {
    let id = UUID()
    let text: String
}

/// UIKit paylaşım sayfasının SwiftUI karşılığı.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
