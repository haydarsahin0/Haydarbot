import SwiftUI

/// 1-100 arası puanlama için parmakla sürüklenen kaydırıcı.
///
/// Henüz puanlanmamışken kesikli boş bir ray görünür; ilk dokunuşta değer
/// oturur, dolgu yaylanarak yerine gelir ve sayının etrafında bir halka
/// açılıp kaybolur — puanın "kaydedildiği" hissini veren küçük gösteri.
@MainActor
struct RatingSlider: View {

    let question: RatingQuestion
    /// `nil` = henüz puanlanmadı.
    @Binding var value: Int?
    /// Geçmiş bir gün salt okunur olabilir.
    var isEnabled: Bool = true

    @State private var isDragging = false
    @State private var pulse: CGFloat = 0
    @State private var pulseOpacity: Double = 0

    private let trackHeight: CGFloat = 52
    private let knobSize: CGFloat = 40

    private var displayValue: Int { value ?? 50 }
    private var hasValue: Bool { value != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            slider
            endLabels
        }
        .padding(18)
        .background(cardBackground)
        .opacity(isEnabled ? 1 : 0.55)
        .allowsHitTesting(isEnabled)
    }

    // MARK: - Başlık

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(question.gradient)
                    .frame(width: 34, height: 34)
                    .shadow(color: question.endColor.opacity(0.35), radius: 6, y: 3)

                Image(systemName: question.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(question.title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            valueBadge
        }
    }

    private var valueBadge: some View {
        Text(hasValue ? "\(displayValue)" : "–")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
            .foregroundStyle(hasValue ? question.color(for: displayValue) : Theme.inkFaint)
            .scaleEffect(isDragging ? 1.12 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
    }

    // MARK: - Kaydırıcı

    private var slider: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let travel = max(width - knobSize, 1)
            let fraction = CGFloat(displayValue - 1) / 99.0
            let knobX = knobSize / 2 + travel * fraction

            ZStack(alignment: .leading) {
                track
                fill(width: knobX + knobSize / 2 - 3)
                tickMarks(width: width)
                knob
                    .position(x: knobX, y: trackHeight / 2)
            }
            .frame(width: width, height: trackHeight)
            .contentShape(Rectangle())
            .gesture(drag(travel: travel))
        }
        .frame(height: trackHeight)
    }

    private var track: some View {
        Capsule(style: .continuous)
            .fill(Theme.paperShade)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(hasValue ? Theme.paperEdge : Theme.inkFaint.opacity(0.35),
                                  style: hasValue
                                      ? StrokeStyle(lineWidth: 1)
                                      : StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            )
            .frame(height: trackHeight)
    }

    @ViewBuilder
    private func fill(width: CGFloat) -> some View {
        if hasValue {
            Capsule(style: .continuous)
                .fill(question.gradient)
                .frame(width: max(trackHeight, width), height: trackHeight - 6)
                .padding(.leading, 3)
                .shadow(color: question.endColor.opacity(0.25), radius: 5, y: 2)
        }
    }

    /// 25 / 50 / 75 hizasındaki ince işaretler.
    private func tickMarks(width: CGFloat) -> some View {
        let travel = max(width - knobSize, 1)

        return ForEach([25, 50, 75], id: \.self) { mark in
            let x = knobSize / 2 + travel * CGFloat(mark - 1) / 99.0
            Capsule()
                .fill(Theme.ink.opacity(displayValue >= mark && hasValue ? 0.16 : 0.08))
                .frame(width: 1.5, height: 8)
                .position(x: x, y: trackHeight / 2)
        }
    }

    private var knob: some View {
        ZStack {
            // Puan oturduğunda dışa doğru açılıp kaybolan halka.
            Circle()
                .stroke(question.color(for: displayValue), lineWidth: 2)
                .frame(width: knobSize, height: knobSize)
                .scaleEffect(pulse)
                .opacity(pulseOpacity)

            Circle()
                .fill(Theme.paper)
                .frame(width: knobSize, height: knobSize)
                .shadow(color: .black.opacity(0.18), radius: isDragging ? 8 : 4, y: 2)

            Text(hasValue ? "\(displayValue)" : "?")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(hasValue ? question.color(for: displayValue) : Theme.inkFaint)
        }
        .scaleEffect(isDragging ? 1.18 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isDragging)
    }

    private var endLabels: some View {
        HStack {
            Text(question.lowLabel)
            Spacer()
            Text(question.highLabel)
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(Theme.inkFaint)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Theme.paper)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.paperEdge, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    // MARK: - Sürükleme

    private func drag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !isDragging {
                    isDragging = true
                    Haptics.prepare()
                }
                apply(locationX: gesture.location.x, travel: travel)
            }
            .onEnded { gesture in
                apply(locationX: gesture.location.x, travel: travel)
                isDragging = false
                land()
            }
    }

    private func apply(locationX: CGFloat, travel: CGFloat) {
        let fraction = (locationX - knobSize / 2) / travel
        let newValue = Int((fraction * 99).rounded()) + 1
        let clamped = max(1, min(100, newValue))
        guard clamped != value else { return }

        let wasEmpty = value == nil
        if wasEmpty {
            // İlk değer yaylanarak gelsin, sonraki değişiklikler anlık olsun.
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                value = clamped
            }
        } else {
            value = clamped
        }

        if clamped == 1 || clamped == 100 {
            Haptics.edge()
        } else {
            Haptics.tick()
        }
    }

    /// Parmak kalkınca: halka bir kez açılıp kayboluyor.
    private func land() {
        guard hasValue else { return }
        Haptics.tap()

        pulse = 1
        pulseOpacity = 0.85
        withAnimation(.easeOut(duration: 0.55)) {
            pulse = 1.9
            pulseOpacity = 0
        }
    }
}
