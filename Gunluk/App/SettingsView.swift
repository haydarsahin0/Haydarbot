import SwiftUI

/// Ayarlar ve "hakkında": istatistikler, kilit, hatırlatma, yedekleme durumu
/// ve dışa aktarma.
@MainActor
struct SettingsView: View {

    @ObservedObject var store: DiaryStore
    @ObservedObject var photos: PhotoStore
    @ObservedObject var voices: VoiceStore
    @ObservedObject var lock: AppLock
    @ObservedObject var reminders: Reminders
    @ObservedObject var cloud: CloudSync

    @Environment(\.dismiss) private var dismiss
    @State private var hapticsEnabled = Haptics.isEnabled
    @State private var exportPayload: ExportPayload?

    var body: some View {
        NavigationStack {
            List {
                statisticsSection
                cloudSection
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
                Divider()
                statistic(value: "\(store.allVoiceIDs.count)", label: "ses kaydı")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .listRowBackground(Color.clear)
        }
    }

    private var cloudSection: some View {
        Section("Yedekleme") {
            Toggle(isOn: $cloud.isEnabled) {
                Label("iCloud'a yedekle", systemImage: "icloud")
            }
            .tint(Theme.accent)

            HStack {
                Text("Durum")
                Spacer()
                Text(cloudStatusText)
                    .foregroundStyle(cloudStatusIsError ? Theme.accent : Theme.inkSoft)
                    .font(.system(size: 14, design: .rounded))
            }

            if cloud.isEnabled {
                Text("Günlüğün ve fotoğrafların senin iCloud hesabında saklanıyor. Telefonunu değiştirdiğinde ya da uygulamayı yeniden kurduğunda geri geliyor.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            } else {
                Text("Yedekleme kapalıyken kayıtların yalnızca bu cihazda. Telefonu kaybedersen ya da uygulamayı silersen geri getirilemez.")
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
            }
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

            LabeledContent {
                Text(voiceSizeText)
                    .foregroundStyle(Theme.inkSoft)
            } label: {
                Label("Ses kayıtları", systemImage: "waveform")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Text("Kayıtların bu cihazda ve açıksa senin iCloud hesabında tutuluyor. Hiçbir veri bize ya da üçüncü bir tarafa gönderilmiyor.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: - Yardımcılar

    private var cloudStatusText: String {
        switch cloud.status {
        case .disabled: return "kapalı"
        case .unavailable: return "iCloud hesabı yok"
        case .waiting: return "bekliyor"
        case .syncing: return "eşitleniyor…"
        case .synced(let date):
            let formatter = DateFormatter()
            formatter.locale = DayIndex.locale
            formatter.dateFormat = "HH:mm"
            return "son: " + formatter.string(from: date)
        case .failed(let message): return message
        }
    }

    private var cloudStatusIsError: Bool {
        if case .failed = cloud.status { return true }
        return false
    }

    private var photoSizeText: String { sizeText(photos.totalBytes) }
    private var voiceSizeText: String { sizeText(voices.totalBytes) }

    private func sizeText(_ bytes: Int64) -> String {
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
