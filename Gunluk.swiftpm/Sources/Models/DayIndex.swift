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

    /// Gün sayacı ve diskteki anahtarlar için sabit takvim.
    ///
    /// Kullanıcının takvimi (Hicri, Budist…) ya da bölgesi ne olursa olsun
    /// aynı günün aynı numaraya ve aynı `"yyyy-MM-dd"` anahtarına düşmesi
    /// gerekiyor; yoksa cihaz ya da bölge değişince veri kayar.
    static let storageCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }()

    /// Ekranda görünen ay ve gün adları için kullanıcının kendi takvimi.
    static var displayCalendar: Calendar { Calendar.current }

    /// Geriye dönük uyumluluk için: eski çağrı yerleri `calendar` kullanıyordu.
    static var calendar: Calendar { storageCalendar }

    /// Gün sayacının başlangıcı: 1 Ocak 2015.
    static let epoch: Date = {
        var components = DateComponents()
        components.year = 2015
        components.month = 1
        components.day = 1
        return storageCalendar.date(from: components) ?? Date(timeIntervalSince1970: 1_420_070_400)
    }()

    /// Verilen tarihin gün numarası. Yaz saati geçişlerinde kaymaması için
    /// saniye farkı yerine takvim gün farkı kullanılır.
    static func index(for date: Date) -> Int {
        let start = storageCalendar.startOfDay(for: date)
        return storageCalendar.dateComponents([.day], from: epoch, to: start).day ?? 0
    }

    static func date(for index: Int) -> Date {
        storageCalendar.date(byAdding: .day, value: index, to: epoch) ?? epoch
    }

    static var today: Int { index(for: Date()) }

    // MARK: - Diskte saklanan tarih anahtarı

    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = storageCalendar
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
    //
    // Hepsi cihazın diliyle biçimleniyor. `setLocalizedDateFormatFromTemplate`
    // kalıbı dile göre yeniden sıralıyor: Türkçe "25 Temmuz", İngilizce
    // "July 25", Japonca "7月25日".

    private static func formatter(template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = displayCalendar
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    /// "Temmuz 2026" / "July 2026"
    static func monthAndYear(_ index: Int) -> String {
        formatter(template: "LLLL yyyy").string(from: date(for: index)).capitalizedFirst
    }

    /// "Temmuz" / "July"
    static func month(_ index: Int) -> String {
        formatter(template: "LLLL").string(from: date(for: index)).capitalizedFirst
    }

    /// "2026"
    static func year(_ index: Int) -> String {
        displayCalendar.component(.year, from: date(for: index)).formatted(.number.grouping(.never))
    }

    /// "25"
    static func dayNumber(_ index: Int) -> String {
        displayCalendar.component(.day, from: date(for: index)).formatted(.number.grouping(.never))
    }

    /// "Cts" / "Sat"
    static func shortWeekday(_ index: Int) -> String {
        formatter(template: "EEE").string(from: date(for: index)).capitalizedFirst
    }

    /// "Cumartesi" / "Saturday"
    static func weekday(_ index: Int) -> String {
        formatter(template: "EEEE").string(from: date(for: index)).capitalizedFirst
    }

    /// "25 Temmuz 2026 Cumartesi" / "Saturday, July 25, 2026"
    static func longDescription(_ index: Int) -> String {
        date(for: index).formatted(
            .dateTime.weekday(.wide).day().month(.wide).year()
                .locale(Locale.current)
        )
    }

    /// Haftanın günlerinin kısa adları, kullanıcının hafta başlangıcına göre
    /// sıralı. Grafikteki sütun etiketleri buradan geliyor.
    static var orderedWeekdaySymbols: [(weekday: Int, label: String)] {
        let calendar = displayCalendar
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday
        return (0..<7).map { offset in
            // Takvimde gün numaraları 1...7; ilk gün bölgeye göre değişiyor.
            let weekday = (first - 1 + offset) % 7 + 1
            return (weekday, symbols[weekday - 1].capitalizedFirst)
        }
    }

    static func isToday(_ index: Int) -> Bool { index == today }
    static func isFuture(_ index: Int) -> Bool { index > today }
}

extension String {
    /// Türkçe ay adları `LLLL` ile küçük harf gelebiliyor; ilk harfi büyütür.
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return String(first).uppercased(with: Locale.current) + dropFirst()
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
