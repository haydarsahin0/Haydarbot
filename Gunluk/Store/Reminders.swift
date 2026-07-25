import Foundation
import UserNotifications

/// Akşam hatırlatması. Günlük uygulamalarının terk edilme sebebi çoğunlukla
/// unutulmak; her gün aynı saatte tekrar eden tek bir yerel bildirim yeterli.
@MainActor
final class Reminders: ObservableObject {

    static let identifier = "gunluk.gunluk-hatirlatma"

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            Task { await apply() }
        }
    }

    @Published var time: Date {
        didSet {
            UserDefaults.standard.set(time.timeIntervalSince1970, forKey: Keys.time)
            Task { await apply() }
        }
    }

    /// Kullanıcı bildirimlere izin vermediyse arayüzde uyarı göstermek için.
    @Published private(set) var permissionDenied = false

    private enum Keys {
        static let enabled = "reminder.enabled"
        static let time = "reminder.time"
    }

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)

        let stored = UserDefaults.standard.double(forKey: Keys.time)
        if stored > 0 {
            time = Date(timeIntervalSince1970: stored)
        } else {
            // Varsayılan: akşam 21:00
            var components = DateComponents()
            components.hour = 21
            components.minute = 0
            time = DayIndex.calendar.date(from: components) ?? Date()
        }
    }

    /// Ayarlarda anahtar açıldığında izin isteyip zamanlamayı kurar.
    func apply() async {
        let center = UNUserNotificationCenter.current()

        guard isEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
            permissionDenied = false
            return
        }

        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            granted = false
        }

        guard granted else {
            permissionDenied = true
            // Anahtarı geri kapatmak `didSet` üzerinden buraya tekrar girmesin
            // diye doğrudan saklanan değer güncelleniyor.
            UserDefaults.standard.set(false, forKey: Keys.enabled)
            return
        }

        permissionDenied = false
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])

        let content = UNMutableNotificationContent()
        content.title = "Günlük"
        content.body = Self.messages.randomElement() ?? "Bugünü yazmak ister misin?"
        content.sound = .default

        var components = DayIndex.calendar.dateComponents([.hour, .minute], from: time)
        components.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.identifier,
                                            content: content,
                                            trigger: trigger)
        try? await center.add(request)
    }

    /// Aynı metin her akşam tekrarlanmasın diye küçük bir havuz.
    private static let messages = [
        "Bugünü yazmak ister misin?",
        "Bugün nasıl geçti?",
        "Defterinde bugünün sayfası seni bekliyor.",
        "Birkaç satır da bugüne düşelim mi?",
        "Bugünden aklında ne kaldı?"
    ]
}
