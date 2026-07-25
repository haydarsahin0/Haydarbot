import Foundation
import StoreKit

/// Aylık abonelik.
///
/// Yazmak, puanlamak, fotoğraf ve ses eklemek tamamen ücretsiz. Abonelik
/// yalnızca **geçmiş günleri okumayı** açıyor; bugün her zaman açık.
///
/// `Paywall.freeHistoryDays` bu sınırı tek bir yerden belirliyor. Şu an 0:
/// dünden öncesi kilitli. Daha yumuşak bir model istenirse (ör. son 30 gün
/// serbest) yalnızca o sayıyı değiştirmek yeterli.
@MainActor
final class SubscriptionStore: ObservableObject {

    static let productID = "com.haydarsahin.gunluk.pro.monthly"
    /// Playgrounds sürümünde gerçek satın alma yok; orada abonelik durumu
    /// elle açılıp kapatılabiliyor ki iki hâl de denenebilsin.
    static let isTestable = false

    @Published private(set) var isSubscribed = false
    @Published private(set) var product: Product?
    @Published private(set) var isPurchasing = false
    @Published private(set) var lastError: String?
    /// Ürün bilgisi ve mevcut hak durumu ilk kez yüklenene kadar `true`.
    /// Yüklenirken geçmiş sayfalar kilitli görünüp sonra açılmasın diye.
    @Published private(set) var isLoading = true

    private var updatesTask: Task<Void, Never>?

    init() {
        // Uygulama açıkken yapılan satın almalar, iptaller ve aile
        // paylaşımı değişiklikleri buradan geliyor.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refresh()
            }
        }

        Task { await load() }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Yükleme

    func load() async {
        await loadProduct()
        await refresh()
        isLoading = false
    }

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            // Ürün çekilemezse abonelik ekranı fiyat yerine açıklama gösteriyor;
            // uygulamanın geri kalanı etkilenmiyor.
            product = nil
        }
    }

    /// Cihazdaki geçerli hakları tarar.
    func refresh() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard transaction.productID == Self.productID else { continue }
            if let expiration = transaction.expirationDate {
                active = expiration > Date()
            } else {
                active = true
            }
            if transaction.revocationDate != nil { active = false }
        }
        isSubscribed = active
    }

    // MARK: - Satın alma

    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refresh()
                    Haptics.success()
                } else {
                    lastError = String(localized: "Satın alma doğrulanamadı.")
                }
            case .userCancelled:
                break
            case .pending:
                // Satın alma onay bekliyor (ör. Aile Paylaşımı izni).
                break
            @unknown default:
                break
            }
        } catch {
            lastError = String(localized: "Satın alma tamamlanamadı.")
        }
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        try? await AppStore.sync()
        await refresh()
    }

    var priceText: String? {
        product?.displayPrice
    }

    /// Satın alma düğmesinin etkin olup olmayacağı. Playgrounds sürümündeki
    /// karşılığın da aynı adı taşıyabilmesi için `product` yerine bu
    /// kullanılıyor.
    var canPurchase: Bool { product != nil }

    /// Yalnızca `isTestable` sürümlerde anlamlı.
    func toggleForTesting() {}
}

/// Hangi günün okunabildiğine karar veren tek yer.
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
