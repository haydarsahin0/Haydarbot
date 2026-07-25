import SwiftUI

/// Defterin açıkken görünen tek bir sayfası.
///
/// Sayfa iki halden birinde: gün boşsa videodaki gibi çizgili boş kağıt,
/// yazı varsa yazının ilk satırları. Altta o güne verilen puanlar küçük
/// renkli noktalar olarak durur.
@MainActor
struct PageView: View {

    let day: Int
    let entry: DiaryEntry?
    let side: PageSide
    /// Sayfada fotoğraf küçüğü göstermek için; yoksa sayfa yalnızca yazı gösterir.
    var photos: PhotoStore? = nil

    private var isToday: Bool { DayIndex.isToday(day) }
    private var isFuture: Bool { DayIndex.isFuture(day) }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let horizontalInset = size.width * 0.11
            let spineInset = size.width * 0.08

            VStack(alignment: .leading, spacing: 0) {
                header(width: size.width)
                    .padding(.top, size.height * 0.10)

                content(size: size)
                    .padding(.top, size.height * 0.055)

                Spacer(minLength: 0)

                footer(width: size.width)
                    .padding(.bottom, size.height * 0.06)
            }
            .padding(.leading, side == .left ? horizontalInset : spineInset)
            .padding(.trailing, side == .left ? spineInset : horizontalInset)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .background(paperBackground)
        .overlay(alignment: .bottomTrailing) { photoCorner }
        .overlay { spineShading }
        .overlay(alignment: side == .left ? .topLeading : .topTrailing) { todayRibbon }
        .clipShape(shape)
        .opacity(isFuture ? 0.55 : 1)
    }

    // MARK: - Parçalar

    private var shape: UnevenRoundedRectangle {
        // Sırt tarafındaki köşeler neredeyse düz, dış köşeler yuvarlak.
        UnevenRoundedRectangle(
            topLeadingRadius: side == .left ? 14 : 2,
            bottomLeadingRadius: side == .left ? 14 : 2,
            bottomTrailingRadius: side == .left ? 2 : 14,
            topTrailingRadius: side == .left ? 2 : 14,
            style: .continuous
        )
    }

    private var paperBackground: some View {
        Theme.paperGradient(for: side)
    }

    /// Sırta yakın kısımdaki hafif karartma — kağıdın kıvrımı hissi.
    /// Gradyan sırttan başlayıp sayfanın ortasına varmadan kayboluyor.
    private var spineShading: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.11), location: 0),
                .init(color: Color.black.opacity(0.04), location: 0.10),
                .init(color: Color.black.opacity(0), location: 0.32)
            ],
            startPoint: side == .left ? .trailing : .leading,
            endPoint: side == .left ? .leading : .trailing
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var todayRibbon: some View {
        if isToday {
            Capsule(style: .continuous)
                .fill(Theme.accent)
                .frame(width: 26, height: 5)
                .padding(.top, 10)
                .padding(side == .left ? .leading : .trailing, 14)
                .opacity(0.9)
        }
    }

    /// Fotoğraflı günlerde sayfanın köşesine bantlanmış gibi duran küçük kare.
    @ViewBuilder
    private var photoCorner: some View {
        if let photos, let first = entry?.photoIDs.first,
           let image = photos.thumbnail(first) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 26, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                .rotationEffect(.degrees(side == .left ? -5 : 5))
                .padding(.trailing, 10)
                .padding(.bottom, 10)
                .allowsHitTesting(false)
        }
    }

    private func header(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(DayIndex.month(day))
                .font(.system(size: max(9, width * 0.075), weight: .medium, design: .default))
                .tracking(0.4)
                .foregroundStyle(Theme.inkFaint)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(DayIndex.dayNumber(day))
                    .font(.system(size: max(13, width * 0.115), weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text(DayIndex.shortWeekday(day))
                    .font(.system(size: max(8, width * 0.068), weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        let lineSpacing = max(9, size.height * 0.052)
        let lineCount = 9

        if let entry, entry.hasText {
            Text(entry.text)
                .font(.system(size: max(7.5, size.width * 0.058), design: .serif))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(lineSpacing * 0.34)
                .lineLimit(lineCount)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Boş sayfa: yalnızca çizgiler.
            VStack(spacing: lineSpacing) {
                ForEach(0..<lineCount, id: \.self) { _ in
                    Rectangle()
                        .fill(Theme.rule)
                        .frame(height: 0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func footer(width: CGFloat) -> some View {
        let ratings = entry?.ratings ?? [:]

        if !ratings.isEmpty {
            HStack(spacing: max(3, width * 0.028)) {
                ForEach(RatingQuestion.all) { question in
                    if let value = ratings[question.id] {
                        RatingDot(question: question, value: value, size: max(5, width * 0.045))
                    }
                }
            }
            .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
    }
}

/// Sayfanın altındaki küçük puan göstergesi: halka ne kadar doluysa puan o kadar yüksek.
private struct RatingDot: View {
    let question: RatingQuestion
    let value: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(question.color(for: value).opacity(0.25), lineWidth: size * 0.22)

            Circle()
                .trim(from: 0, to: CGFloat(max(1, min(100, value))) / 100)
                .stroke(question.color(for: value),
                        style: StrokeStyle(lineWidth: size * 0.22, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
