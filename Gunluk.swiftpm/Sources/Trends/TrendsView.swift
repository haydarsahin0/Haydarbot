import SwiftUI
import Charts

/// Puanların geri dönüşü: verilen notların zaman içindeki seyri.
///
/// Her gün dört soruyu puanlamanın karşılığı burada; hangi soruların nasıl
/// gittiği, haftanın hangi gününün daha iyi geçtiği ve en yüksek günler.
@MainActor
struct TrendsView: View {

    @ObservedObject var store: DiaryStore
    @Environment(\.dismiss) private var dismiss

    @State private var range: TrendRange = .threeMonths
    @State private var selectedQuestion: RatingQuestion = RatingQuestion.all[0]

    private var series: [TrendPoint] {
        store.trendPoints(for: selectedQuestion, in: range)
    }

    private var summary: TrendSummary {
        TrendSummary(points: series)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    questionPicker
                    rangePicker

                    if series.isEmpty {
                        emptyState
                    } else {
                        summaryCards
                        lineChart
                        weekdayChart
                    }
                }
                .padding(20)
            }
            .background(Theme.surface.ignoresSafeArea())
            .navigationTitle("Puanların")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { dismiss() }
                }
            }
        }
    }

    // MARK: - Seçiciler

    private var questionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RatingQuestion.all) { question in
                    let isSelected = question.id == selectedQuestion.id

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedQuestion = question
                        }
                        Haptics.tap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: question.symbol)
                                .font(.system(size: 12, weight: .semibold))
                            Text(question.shortTitle)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(isSelected ? .white : Theme.inkSoft)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background {
                            if isSelected {
                                Capsule().fill(question.gradient)
                            } else {
                                Capsule().fill(Theme.paper)
                            }
                        }
                        .overlay(
                            Capsule().strokeBorder(
                                isSelected ? Color.clear : Theme.paperEdge,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var rangePicker: some View {
        Picker("Aralık", selection: $range) {
            ForEach(TrendRange.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Özet

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(title: "Ortalama", value: summary.averageText)
            summaryCard(title: "En yüksek", value: summary.bestText)
            summaryCard(title: "Puanlanan", value: "\(series.count) gün")
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.paperEdge, lineWidth: 1)
        )
    }

    // MARK: - Grafikler

    private var lineChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Zaman içinde")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.inkFaint)

            Chart(series) { point in
                AreaMark(
                    x: .value("Tarih", point.date),
                    y: .value("Puan", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [selectedQuestion.endColor.opacity(0.28),
                                 selectedQuestion.endColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Tarih", point.date),
                    y: .value("Puan", point.value)
                )
                .foregroundStyle(selectedQuestion.endColor)
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100])
            }
            .frame(height: 210)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.paperEdge, lineWidth: 1)
            )
        }
    }

    private var weekdayChart: some View {
        let averages = store.weekdayAverages(for: selectedQuestion, in: range)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Haftanın günlerine göre")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.inkFaint)

            Chart(averages) { item in
                BarMark(
                    x: .value("Gün", item.label),
                    y: .value("Ortalama", item.average)
                )
                .foregroundStyle(selectedQuestion.gradient)
                .cornerRadius(6)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 170)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.paperEdge, lineWidth: 1)
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 34))
                .foregroundStyle(Theme.inkFaint)

            Text("Bu aralıkta puan yok")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)

            Text("Günleri puanlamaya başlayınca seyri burada göreceksin.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}

// MARK: - Veri tipleri

enum TrendRange: String, CaseIterable, Identifiable {
    case month
    case threeMonths
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: return "30 gün"
        case .threeMonths: return "3 ay"
        case .year: return "1 yıl"
        }
    }

    var days: Int {
        switch self {
        case .month: return 30
        case .threeMonths: return 90
        case .year: return 365
        }
    }
}

struct TrendPoint: Identifiable {
    let day: Int
    let value: Int

    var id: Int { day }
    var date: Date { DayIndex.date(for: day) }
}

struct WeekdayAverage: Identifiable {
    let weekday: Int
    let label: String
    let average: Double

    var id: Int { weekday }
}

/// Grafiğin üstündeki üç kutunun hesabı.
struct TrendSummary {
    let points: [TrendPoint]

    var average: Double {
        guard !points.isEmpty else { return 0 }
        return Double(points.reduce(0) { $0 + $1.value }) / Double(points.count)
    }

    var averageText: String {
        points.isEmpty ? "–" : String(Int(average.rounded()))
    }

    var bestText: String {
        guard let best = points.max(by: { $0.value < $1.value }) else { return "–" }
        return "\(best.value)"
    }
}
