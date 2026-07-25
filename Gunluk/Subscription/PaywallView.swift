import SwiftUI

/// Kilitli bir geçmiş güne dokunulduğunda ya da ayarlardan açıldığında
/// görünen abonelik ekranı.
@MainActor
struct PaywallView: View {

    @ObservedObject var subscriptions: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    /// Kullanıcının hangi güne ulaşmaya çalıştığı; başlığı kişiselleştiriyor.
    var requestedDay: Int?

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 26) {
                    header
                    benefits
                    Spacer(minLength: 4)
                    purchaseArea
                    footer
                }
                .padding(.horizontal, 26)
                .padding(.top, 28)
                .padding(.bottom, 30)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.trailing, 18)
            .padding(.top, 14)
            .accessibilityLabel(Text("Kapat", comment: "Abonelik ekranını kapatma düğmesi"))
        }
        .onChange(of: subscriptions.isSubscribed) { _, subscribed in
            if subscribed { dismiss() }
        }
    }

    // MARK: - Parçalar

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.accentSoft)
                    .frame(width: 84, height: 84)

                Image(systemName: "book.closed.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.accent)
            }
            .shadow(color: Theme.accent.opacity(0.2), radius: 18, y: 8)

            VStack(spacing: 8) {
                Text("Geçmişini aç")
                    .font(.system(size: 29, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var subtitle: String {
        if let requestedDay {
            return String(
                format: String(localized: "%@ gününde yazdıklarını okumak için aboneliğe geç."),
                DayIndex.longDescription(requestedDay)
            )
        }
        return String(localized: "Yazmak her zaman ücretsiz. Abonelik geçmiş günlerini okumanı açıyor.")
    }

    private var benefits: some View {
        VStack(spacing: 14) {
            benefit(symbol: "clock.arrow.circlepath",
                    title: String(localized: "Bütün geçmişin"),
                    detail: String(localized: "Yıllar öncesine kadar her günü açıp okuyabilirsin."))

            benefit(symbol: "chart.line.uptrend.xyaxis",
                    title: String(localized: "Puanlarının seyri"),
                    detail: String(localized: "Mutluluğun ve enerjin zaman içinde nasıl değişmiş, gör."))

            benefit(symbol: "pencil.and.outline",
                    title: String(localized: "Yazmak hep ücretsiz"),
                    detail: String(localized: "Bugünü yazmak, fotoğraf ve ses eklemek hiçbir zaman ücretli olmayacak."))
        }
    }

    private func benefit(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)

                Text(detail)
                    .font(.system(size: 13.5, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.paperEdge, lineWidth: 1)
        )
    }

    private var purchaseArea: some View {
        VStack(spacing: 12) {
            Button {
                Task { await subscriptions.purchase() }
            } label: {
                Group {
                    if subscriptions.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        VStack(spacing: 2) {
                            Text("Aboneliğe geç")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            if let price = subscriptions.priceText {
                                Text(String(format: String(localized: "%@ / ay"), price))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .opacity(0.85)
                            }
                        }
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule().fill(Theme.accent)
                )
                .shadow(color: Theme.accent.opacity(0.3), radius: 14, y: 6)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.97))
            .disabled(subscriptions.isPurchasing || !subscriptions.canPurchase)

            if !subscriptions.canPurchase && !subscriptions.isLoading {
                Text("Abonelik şu an yüklenemedi. Bağlantını kontrol edip tekrar dene.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.center)
            }

            if let error = subscriptions.lastError {
                Text(error)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await subscriptions.restore() }
            } label: {
                Text("Satın alımları geri yükle")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var footer: some View {
        Text("Abonelik her ay kendiliğinden yenilenir. İstediğin zaman App Store ayarlarından iptal edebilirsin. Yazdıkların iptal etsen de silinmez, cihazında durmaya devam eder.")
            .font(.system(size: 11.5, design: .rounded))
            .foregroundStyle(Theme.inkFaint)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
