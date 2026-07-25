import SwiftUI

/// Açık duran defter ve parmakla sürüklenerek çevrilen sayfalar.
///
/// ## Nasıl çalışıyor
/// `turn` değeri -1 ile 1 arasında sürüklenme ilerlemesini tutar:
/// * `turn > 0` — ileri gidiliyor, sağdaki sayfa sırtın etrafında sola dönüyor.
/// * `turn < 0` — geri gidiliyor, soldaki sayfa sağa dönüyor.
///
/// Dönen yaprak tek bir görünüm; ön yüzü 90 dereceye kadar, arka yüzü ondan
/// sonra görünür. Arka yüz `scaleEffect(x: -1)` ile aynalanır, çünkü yaprak
/// 180 dereceye vardığında zaten aynalanmış olur; ikisi birbirini götürür.
///
/// Y ekseni ekranda aşağıyı gösterdiği için, sayfanın serbest kenarının
/// kullanıcıya doğru kalkması pozitif değil **negatif** açı gerektiriyor —
/// ileri çevirmede açı negatif, geri çevirmede pozitif.
@MainActor
struct BookView: View {

    @Binding var spread: Int
    /// Ok düğmelerinden gelen çevirme isteği; uygulanınca `nil`'e çekilir.
    @Binding var command: BookCommand?
    let store: DiaryStore
    let photos: PhotoStore
    /// Geçmiş günlerin okunabilmesi için abonelik gerekiyor mu.
    let isSubscribed: Bool
    /// Bir sayfaya dokunulduğunda: gün numarası ve dokunulan taraf.
    let onSelectDay: @MainActor (Int, PageSide) -> Void

    @State private var turn: Double = 0
    @State private var isDragging = false
    @State private var isAnimating = false

    /// Açık defterin en/boy oranı (iki sayfa yan yana).
    ///
    /// Tek sayfa 0.64 — gerçek bir cep defterinin oranı (90×140 mm). Önceki
    /// 0.71 daha kare bir defter veriyordu ve telefonun uzun ekranında
    /// ortada küçük kalıyordu.
    static let aspectRatio: CGFloat = 1.28

    var body: some View {
        GeometryReader { geo in
            let size = bookSize(in: geo.size)

            ZStack {
                // Gölge yalnızca arkadaki kağıt yığınına veriliyor: dönen
                // yaprakla aynı katmanda olsaydı 3B dönüşüm sırasında
                // bozuluyordu.
                pageStackEdges(size: size)
                    .shadow(color: .black.opacity(0.13), radius: 40, x: 0, y: 24)
                    .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.07), radius: 2, x: 0, y: 1)

                spreadContent(size: size)
            }
            .frame(width: size.width, height: size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(dragGesture(pageWidth: size.width / 2))
        }
        .onChange(of: command) { _, newValue in
            guard let newValue else { return }
            perform(newValue)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Günlük defteri")
        .accessibilityHint("Sağa sola kaydırarak günler arasında geçebilir, bir güne dokunarak açabilirsin.")
    }

    private func bookSize(in available: CGSize) -> CGSize {
        let width = min(available.width, available.height * Self.aspectRatio)
        return CGSize(width: width, height: width / Self.aspectRatio)
    }

    // MARK: - Görünen günler

    private var currentLeft: Int { SpreadIndex.leftDay(of: spread) }
    private var currentRight: Int { SpreadIndex.rightDay(of: spread) }

    /// Çevirme sırasında sol yarıda duran sabit sayfa.
    private var leftBaseDay: Int {
        turn < 0 ? SpreadIndex.leftDay(of: spread - 1) : currentLeft
    }

    /// Çevirme sırasında sağ yarıda duran sabit sayfa.
    private var rightBaseDay: Int {
        turn > 0 ? SpreadIndex.rightDay(of: spread + 1) : currentRight
    }

    /// Dönen yaprağın ön yüzü (kullanıcının kaldırdığı sayfa).
    private var leafFrontDay: Int {
        turn > 0 ? currentRight : currentLeft
    }

    /// Dönen yaprağın arka yüzü (çevrilince ortaya çıkan sayfa).
    private var leafBackDay: Int {
        turn > 0 ? SpreadIndex.leftDay(of: spread + 1) : SpreadIndex.rightDay(of: spread - 1)
    }

    // MARK: - Yerleşim

    private func spreadContent(size: CGSize) -> some View {
        let half = size.width / 2

        let lift = sin(abs(turn) * .pi)

        return ZStack(alignment: .topLeading) {
            page(day: leftBaseDay, side: .left)
                .frame(width: half, height: size.height)
                .onTapGesture { select(day: leftBaseDay, side: .left) }

            page(day: rightBaseDay, side: .right)
                .frame(width: half, height: size.height)
                .offset(x: half)
                .onTapGesture { select(day: rightBaseDay, side: .right) }

            // Havadaki yaprağın sabit sayfalara düşürdüğü gölge. Yaprağın
            // kendi katmanının altında, sayfaların üstünde duruyor.
            if turn != 0 {
                castShadow(on: .left, lift: lift)
                    .frame(width: half, height: size.height)

                castShadow(on: .right, lift: lift)
                    .frame(width: half, height: size.height)
                    .offset(x: half)

                leaf()
                    .frame(width: half, height: size.height)
                    .offset(x: turn > 0 ? half : 0)
                    .allowsHitTesting(false)
            }
        }
        // Dönen yaprak defterin sınırlarının dışına taşabilmeli; bu yüzden
        // burada kırpma yok, her sayfa kendi köşesini kendi kırpıyor.
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// Defterin kalınlığı: sayfaların arkasında hafifçe taşan kağıt kenarları.
    private func pageStackEdges(size: CGSize) -> some View {
        ZStack {
            ForEach(1...3, id: \.self) { depth in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.paperEdge)
                    .frame(width: size.width + CGFloat(depth) * 2.5,
                           height: size.height + CGFloat(depth) * 1.6)
                    .opacity(0.55 - Double(depth) * 0.13)
                    .offset(y: CGFloat(depth) * 0.8)
            }
        }
    }

    private func page(day: Int, side: PageSide) -> some View {
        let entry = store.entry(for: day)
        let locked = Paywall.isLocked(day: day,
                                      isSubscribed: isSubscribed,
                                      hasContent: entry?.isEmpty == false)
        return PageView(day: day,
                        entry: entry,
                        side: side,
                        photos: photos,
                        isLocked: locked)
    }

    // MARK: - Dönen yaprak

    private func leaf() -> some View {
        let progress = abs(turn)
        let forward = turn > 0
        // Sıfırdan 180 dereceye; işaret yönü belirliyor.
        let angle = forward ? -180.0 * progress : 180.0 * progress
        let showingBack = progress > 0.5
        // Çevirmenin ortasında en yüksek olan yumuşak bir eğri (0 -> 1 -> 0).
        let lift = sin(progress * .pi)

        return ZStack {
            page(day: leafFrontDay, side: forward ? .right : .left)
                .opacity(showingBack ? 0 : 1)

            page(day: leafBackDay, side: forward ? .left : .right)
                .scaleEffect(x: -1, y: 1)
                .opacity(showingBack ? 1 : 0)
        }
        .overlay { leafShading(forward: forward, lift: lift) }
        .overlay { leafSheen(progress: progress, forward: forward, lift: lift) }
        .overlay { leafCurl(forward: forward, lift: lift) }
        // Sayfa kalkarken göze bir parça yaklaşıyor. Çok az, ama kağıdın
        // düzlemden ayrıldığı hissini veren şey bu.
        .scaleEffect(1 + 0.035 * lift)
        .shadow(color: .black.opacity(0.32 * lift),
                radius: 26 * lift,
                x: (forward ? -18 : 18) * lift,
                y: 10 * lift)
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0, y: 1, z: 0),
            anchor: forward ? .leading : .trailing,
            perspective: 0.42
        )
    }

    /// Kalkan sayfanın üzerine düşen gölge; sırta yakın taraf daha koyu.
    ///
    /// Dönme ekseni yaprağın kendi kenarında sabit olduğu için, sırt açı ne
    /// olursa olsun ileri çevirmede yaprağın leading, geri çevirmede trailing
    /// kenarında kalır — gölge de sayfa yüzü değişse bile yer değiştirmez.
    private func leafShading(forward: Bool, lift: Double) -> some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.30 * lift), location: 0),
                .init(color: .black.opacity(0.10 * lift), location: 0.35),
                .init(color: .black.opacity(0), location: 1)
            ],
            startPoint: forward ? .leading : .trailing,
            endPoint: forward ? .trailing : .leading
        )
        .allowsHitTesting(false)
    }

    /// Sayfa döndükçe üzerinden geçen ışık bandı. Kağıdın parlak yüzeyinin
    /// ışığı yakalaması; hareketi asıl "pahalı" gösteren ayrıntı bu.
    private func leafSheen(progress: Double, forward: Bool, lift: Double) -> some View {
        // Bant, çevirme boyunca sayfanın bir ucundan diğerine yürüyor.
        let center = forward ? progress : 1 - progress
        let width = 0.30

        return LinearGradient(
            stops: [
                .init(color: .white.opacity(0), location: max(0, center - width)),
                .init(color: .white.opacity(0.55 * lift), location: min(1, max(0, center))),
                .init(color: .white.opacity(0), location: min(1, center + width))
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .blendMode(.softLight)
        .allowsHitTesting(false)
    }

    /// Serbest kenardaki kıvrım: kağıt sırttan uzaklaştıkça hafifçe bükülüyor,
    /// dış kenarında ince bir gölge birikiyor.
    private func leafCurl(forward: Bool, lift: Double) -> some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0), location: 0.78),
                .init(color: .black.opacity(0.06 * lift), location: 0.93),
                .init(color: .black.opacity(0.16 * lift), location: 1)
            ],
            startPoint: forward ? .leading : .trailing,
            endPoint: forward ? .trailing : .leading
        )
        .allowsHitTesting(false)
    }

    /// Havadaki yaprağın altındaki sayfalara düşürdüğü gölge.
    ///
    /// Yaprağın kendi gölgesi onunla birlikte döndüğü için alttaki kağıda
    /// düşen izi vermiyor; bu katman sabit duran sayfaların üzerinde, sırta
    /// yakın tarafta duruyor ve çevirmenin ortasında en koyu hâline geliyor.
    private func castShadow(on side: PageSide, lift: Double) -> some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.26 * lift), location: 0),
                .init(color: .black.opacity(0.08 * lift), location: 0.30),
                .init(color: .black.opacity(0), location: 0.62)
            ],
            startPoint: side == .left ? .trailing : .leading,
            endPoint: side == .left ? .leading : .trailing
        )
        .allowsHitTesting(false)
    }

    // MARK: - Etkileşim

    private func select(day: Int, side: PageSide) {
        guard turn == 0, !isAnimating else { return }
        Haptics.tap()
        onSelectDay(day, side)
    }

    private func dragGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isAnimating else { return }
                // Dikey kaydırmalar sayfayı çevirmesin.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if !isDragging {
                    isDragging = true
                    Haptics.prepare()
                }
                turn = clampedTurn(from: -value.translation.width / max(pageWidth, 1))
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false

                let raw = -value.translation.width / max(pageWidth, 1)
                let velocity = -value.predictedEndTranslation.width / max(pageWidth, 1)
                finish(progress: clampedTurn(from: raw), momentum: velocity)
            }
    }

    /// Sürüklemeyi -1...1 aralığına sıkıştırır ve defterin ilk/son açılımında
    /// lastik gibi direnç uygular.
    private func clampedTurn(from value: Double) -> Double {
        if value > 0 {
            guard spread < SpreadIndex.maxSpread else { return min(value, 1) * 0.12 }
            return min(value, 1)
        } else if value < 0 {
            guard spread > SpreadIndex.minSpread else { return max(value, -1) * 0.12 }
            return max(value, -1)
        }
        return 0
    }

    private func finish(progress: Double, momentum: Double) {
        // Yön her zaman sürüklemenin kendi yönü; hızlı bir geri savurma
        // yanlışlıkla ters tarafa çevirmesin.
        let forward = progress > 0
        let canTurn = forward
            ? spread < SpreadIndex.maxSpread
            : spread > SpreadIndex.minSpread

        // Yarıyı geçtiyse ya da aynı yöne yeterince hızlı savrulduysa tamamla.
        let flicked = forward ? momentum > 0.85 : momentum < -0.85
        let magnitude = abs(progress)
        let shouldTurn = canTurn && magnitude > 0.02 && (magnitude > 0.5 || flicked)

        guard shouldTurn else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                turn = 0
            }
            return
        }

        let target: Double = forward ? 1 : -1
        let step = forward ? 1 : -1
        // Kalan yola göre süre: az kalmışsa animasyon da kısa olsun.
        let remaining = abs(target - turn)
        let response = 0.22 + 0.30 * remaining

        isAnimating = true
        Haptics.pageTurn()

        withAnimation(.spring(response: response, dampingFraction: 0.92), completionCriteria: .logicallyComplete) {
            turn = target
        } completion: {
            // Çevirme bittiğinde görüntü zaten yeni açılımla birebir aynı;
            // sayfa numarasını kaydırıp ilerlemeyi sıfırlamak titremeye yol açmaz.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                spread += step
                turn = 0
            }
            isAnimating = false
        }
    }

    // MARK: - Dışarıdan çevirme (ok düğmeleri)

    /// Ok düğmeleri sayfayı doğrudan çeviremez — `BookView` bir değer tipi,
    /// dışarıdaki kopyanın `@State`'i yok. Bunun yerine üst görünüm bir komut
    /// bırakıyor, defter onu görüp uyguluyor ve komutu temizliyor.
    private func perform(_ request: BookCommand) {
        defer { command = nil }
        guard !isAnimating, turn == 0 else { return }

        let forward = request == .forward
        if forward && spread >= SpreadIndex.maxSpread { return }
        if !forward && spread <= SpreadIndex.minSpread { return }

        isAnimating = true
        Haptics.pageTurn()

        withAnimation(.spring(response: 0.52, dampingFraction: 0.9), completionCriteria: .logicallyComplete) {
            turn = forward ? 1 : -1
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                spread += forward ? 1 : -1
                turn = 0
            }
            isAnimating = false
        }
    }
}

/// Üst görünümden deftere verilen sayfa çevirme komutu.
enum BookCommand: Equatable {
    case forward
    case backward
}
