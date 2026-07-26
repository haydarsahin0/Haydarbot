import Combine
import Foundation

/// `SubscriptionStore`'un Swift Playgrounds sürümü için karşılığı.
///
/// Playgrounds projelerinde App Store ürünü yok, dolayısıyla gerçek satın
/// alma da yok. Yerine elle açılıp kapatılabilen bir anahtar konuyor;
/// böylece kilitli ve açık hâllerin ikisi de denenebiliyor.
///
/// Bu dosya elle düzenlenmemeli — `Tools/make-swiftpm.sh` yerleştiriyor.
@MainActor
final class SubscriptionStore: ObservableObject {

    static let productID = "com.haydarsahin.gunluk.pro.monthly"
    static let isTestable = true

    @Published private(set) var isSubscribed = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading = false

    var canPurchase: Bool { false }
    var priceText: String? { nil }

    func load() async {}
    func refresh() async {}

    func purchase() async {
        lastError = String(localized: "Swift Playgrounds sürümünde satın alma yapılamıyor.")
    }

    func restore() async {}

    func toggleForTesting() {
        isSubscribed.toggle()
        Haptics.tap()
    }
}
