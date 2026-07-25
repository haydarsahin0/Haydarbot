import Foundation

/// Gün numaralandırması.
///
/// Uygulama içinde her gün, sabit bir başlangıç tarihine (epoch) göre bir tamsayı
/// ile temsil edilir. Böylece "önceki gün / sonraki gün" hesapları basit toplama
/// çıkarmaya iner ve defterin sayfa mantığı kolaylaşır.
///
/// Diskte ise gün numarası değil `"yyyy-MM-dd"` biçimindeki tarih anahtarı saklanır;
/// ileride epoch değişse bile kullanıcının verisi bozulmaz.
enum DayIndex {

    /// Türkçe ay/gün adları cihaz dilinden bağımsız olarak aynı görünsün diye
    /// tarih biçimlendirmesi sabit bir yerelde yapılır.
    static let locale = Locale(identifier: "tr_TR")

    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        cal.firstWeekday = 2 // Pazartesi
        return cal
    }()

    /// Gün sayacının başlangıcı: 1 Ocak 2015.
    static let epoch: Date = {
        var components = DateComponents()
        components.year = 2015
        components.month = 1
        components.day = 1
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 1_420_070_400)
    }()

    /// Verilen tarihin gün numarası. Yaz saati geçişlerinde kaymaması için
    /// saniye farkı yerine takvim gün farkı kullanılır.
    static func index(for date: Date) -> Int {
        let start = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: epoch, to: start).day ?? 0
    }

    static func date(for index: Int) -> Date {
        calendar.date(byAdding: .day, value: index, to: epoch) ?? epoch
    }

    static var today: Int { index(for: Date()) }

    // MARK: - Diskte saklanan tarih anahtarı

    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func key(for index: Int) -> String {
        keyFormatter.string(from: date(for: index))
    }

    static func index(forKey key: String) -> Int? {
        guard let date = keyFormatter.date(from: key) else { return nil }
        return index(for: date)
    }

    // MARK: - Ekranda görünen metinler

    /// "Temmuz 2026"
    static func monthAndYear(_ index: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date(for: index)).capitalizedFirst
    }

    /// "Temmuz"
    static func month(_ index: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date(for: index)).capitalizedFirst
    }

    /// "25"
    static func dayNumber(_ index: Int) -> String {
        String(calendar.component(.day, from: date(for: index)))
    }

    /// "Cts"
    static func shortWeekday(_ index: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = "EEE"
        return formatter.string(from: date(for: index)).capitalizedFirst
    }

    /// "Cumartesi"
    static func weekday(_ index: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date(for: index)).capitalizedFirst
    }

    /// "25 Temmuz 2026, Cumartesi"
    static func longDescription(_ index: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = "d MMMM yyyy, EEEE"
        return formatter.string(from: date(for: index))
    }

    static func isToday(_ index: Int) -> Bool { index == today }
    static func isFuture(_ index: Int) -> Bool { index > today }
}

extension String {
    /// Türkçe ay adları `LLLL` ile küçük harf gelebiliyor; ilk harfi büyütür.
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return String(first).uppercased(with: DayIndex.locale) + dropFirst()
    }
}

/// Defterin açık duran iki sayfası (bir "sayfa açılımı").
enum SpreadIndex {
    static func spread(for day: Int) -> Int {
        day >= 0 ? day / 2 : (day - 1) / 2
    }

    static func leftDay(of spread: Int) -> Int { spread * 2 }
    static func rightDay(of spread: Int) -> Int { spread * 2 + 1 }

    /// İleri doğru gidilebilecek son açılım: bugünün bulunduğu açılım.
    static var maxSpread: Int { spread(for: DayIndex.today) }
    static let minSpread: Int = 0
}
