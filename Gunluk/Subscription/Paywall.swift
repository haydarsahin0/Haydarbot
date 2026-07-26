import Foundation

/// Hangi günün okunabildiğine karar veren tek yer.
///
/// `SubscriptionStore` ile aynı dosyada değil: Playgrounds sürümünde satın
/// alma sınıfının yerine boş bir karşılığı konuyor ve aynı dosyada olsalardı
/// bu kurallar da onunla birlikte silinirdi.
enum Paywall {

    /// Abonelik olmadan geriye doğru okunabilen gün sayısı.
    /// 0 = yalnızca bugün açık.
    static let freeHistoryDays = 0

    /// O gün abonelik olmadan okunabilir mi.
    static func isReadable(day: Int, isSubscribed: Bool) -> Bool {
        if isSubscribed { return true }
        // Gelecek günler zaten boş; kilitlemenin anlamı yok.
        if day >= DayIndex.today - freeHistoryDays { return true }
        return false
    }

    /// O gün kilitli mi — sayfada asma kilit göstermek için.
    static func isLocked(day: Int, isSubscribed: Bool, hasContent: Bool) -> Bool {
        // Boş bir geçmiş günü kilitlemek anlamsız: gösterilecek bir şey yok
        // ve kullanıcı orada yalnızca kilit görüp kafası karışıyor.
        hasContent && !isReadable(day: day, isSubscribed: isSubscribed)
    }
}
