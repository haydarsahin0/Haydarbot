import SwiftUI

/// Ayarlar ve "hakkında": istatistikler, kilit, hatırlatma, yedekleme durumu
/// ve dışa aktarma.
@MainActor
struct SettingsView: View {

    @ObservedObject var store: DiaryStore
    @ObservedObject var photos: PhotoStore
    @ObservedObject var lock: AppLock
    @ObservedObject var reminders: Reminders

    @Environment(\.dismiss) private var dismiss
    @State private var hapticsEnabled = Haptics.isEnabled
    @State private var exportPayload: ExportPayload?

    var body: some View {
        NavigationStack {
            List {
                statisticsSection
                securitySection
                reminderSection
                preferencesSection
                dataSection
                aboutSection
            }
            .navigationTitle("Günlük")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { dismiss() }
                }
            }
        }
        .sheet(item: $exportPayload) { payload in
            ShareSheet(items: [payload.text])
        }
    }

    // MARK: - Bölümler

    private var statisticsSection: some View {
        Section {
            HStack(spacing: 12) {
                statistic(value: "\(store.writtenDayCount)", label: "yazılan gün")
                Divider()
                statistic(value: "\(store.streak)", label: "günlük seri")
                Divider()
                statistic(value: "\(store.allPhotoIDs.count)", label: "fotoğraf")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .listRowBackground(Color.clear)
        }
    }

    private var securitySection: some View {
        Section("Gizlilik") {
            Toggle(isOn: $lock.isEnabled) {
                Label(lock.biometryName + " ile kilitle", systemImage: "faceid")
            }
            .tint(Theme.accent)
            .disabled(!lock.isBiometryAvailable)

            if !lock.isBiometryAvailable {
                Text("Bu cihazda kimlik doğrulama kurulu değil. Ayarlar'dan Face ID ya da cihaz şifresi tanımlarsan kilidi açabilirsin.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var reminderSection: some View {
        Section("Hatırlatma") {
            Toggle(isOn: $reminders.isEnabled) {
                Label("Günlük hatırlatma", systemImage: "bell.badge")
            }
            .tint(Theme.accent)

            if reminders.isEnabled {
                DatePicker(
                    selection: $reminders.time,
                    displayedComponents: .hourAndMinute
                ) {
                    Label("Saat", systemImage: "clock")
                }
                .tint(Theme.accent)
            }

            if reminders.permissionDenied {
                Text("Bildirimlere izin verilmedi. iPhone Ayarlar → Bildirimler → Günlük yolundan açabilirsin.")
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private var preferencesSection: some View {
        Section("Tercihler") {
            Toggle(isOn: $hapticsEnabled) {
                Label("Titreşim", systemImage: "iphone.radiowaves.left.and.right")
            }
            .tint(Theme.accent)
            .onChange(of: hapticsEnabled) { _, newValue in
                Haptics.isEnabled = newValue
            }
        }
    }

    private var dataSection: some View {
        Section("Günlüğün") {
            Button {
                exportPayload = ExportPayload(text: store.exportedText())
            } label: {
                Label("Düz metin olarak dışa aktar", systemImage: "square.and.arrow.up")
            }
            .disabled(store.writtenDayCount == 0)

            LabeledContent {
                Text(photoSizeText)
                    .foregroundStyle(Theme.inkSoft)
            } label: {
                Label("Fotoğraflar", systemImage: "photo.stack")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Text("Kayıtların bu cihazda ve senin iCloud hesabında tutuluyor. Hiçbir veri bize ya da üçüncü bir tarafa gönderilmiyor.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: - Yardımcılar

    private var photoSizeText: String {
        let bytes = photos.totalBytes
        guard bytes > 0 else { return "yok" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func statistic(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ExportPayload: Identifiable {
    let id = UUID()
    let text: String
}

/// UIKit paylaşım sayfasının SwiftUI karşılığı.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
