import SwiftUI

/// Ana ekran: üstte ay bilgisi, ortada defter, altta sayfa okları.
/// Bir güne dokunulduğunda editör aynı ekranın üzerine açılıyor.
@MainActor
struct RootView: View {

    @EnvironmentObject private var store: DiaryStore
    @EnvironmentObject private var photos: PhotoStore
    @EnvironmentObject private var lock: AppLock
    @EnvironmentObject private var reminders: Reminders

    @State private var spread: Int = SpreadIndex.spread(for: DayIndex.today)
    @State private var command: BookCommand?
    @State private var selectedDay: Int?
    @State private var openAnchor: UnitPoint = .center
    @State private var showsDatePicker = false
    @State private var showsSettings = false
    @State private var showsTrends = false
    @State private var jumpDate = Date()

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 6)

                BookView(
                    spread: $spread,
                    command: $command,
                    store: store,
                    photos: photos,
                    onSelectDay: openDay(_:side:)
                )
                .padding(.horizontal, 18)

                pageControls
                    .padding(.bottom, 10)
            }

            if let selectedDay {
                EntryEditorView(day: selectedDay,
                                store: store,
                                photos: photos,
                                onClose: closeEditor)
                    .transition(
                        .scale(scale: 0.92, anchor: openAnchor).combined(with: .opacity)
                    )
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $showsDatePicker) { datePickerSheet }
        .sheet(isPresented: $showsTrends) {
            TrendsView(store: store)
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView(store: store,
                         photos: photos,
                         lock: lock,
                         reminders: reminders)
        }
    }

    // MARK: - Üst çubuk

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(DayIndex.monthAndYear(SpreadIndex.leftDay(of: spread)))
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: spread)

                if store.streak > 1 {
                    Text("\(store.streak) gündür yazıyorsun")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.inkFaint)
                }
            }

            Spacer()

            if spread != SpreadIndex.spread(for: DayIndex.today) {
                Button(action: goToToday) {
                    Text("Bugün")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.accentSoft))
                }
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }

            Menu {
                Button {
                    showsTrends = true
                } label: {
                    Label("Puanların", systemImage: "chart.line.uptrend.xyaxis")
                }

                Button {
                    jumpDate = DayIndex.date(for: SpreadIndex.leftDay(of: spread))
                    showsDatePicker = true
                } label: {
                    Label("Tarihe git", systemImage: "calendar")
                }

                Button {
                    showsSettings = true
                } label: {
                    Label("Ayarlar", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Seçenekler")
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: spread)
    }

    // MARK: - Sayfa okları

    private var pageControls: some View {
        HStack(spacing: 26) {
            arrowButton(systemName: "chevron.left",
                        label: "Önceki günler",
                        enabled: spread > SpreadIndex.minSpread) {
                command = .backward
            }

            Text("\(DayIndex.dayNumber(SpreadIndex.leftDay(of: spread))) – \(DayIndex.dayNumber(SpreadIndex.rightDay(of: spread)))")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.inkFaint)
                .frame(minWidth: 70)

            arrowButton(systemName: "chevron.right",
                        label: "Sonraki günler",
                        enabled: spread < SpreadIndex.maxSpread) {
                command = .forward
            }
        }
        .padding(.top, 4)
    }

    private func arrowButton(systemName: String,
                             label: String,
                             enabled: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? Theme.inkSoft : Theme.inkFaint.opacity(0.4))
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(Theme.paper.opacity(enabled ? 0.85 : 0.4))
                        .shadow(color: .black.opacity(enabled ? 0.08 : 0), radius: 4, y: 2)
                )
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: - Tarihe git

    private var datePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Tarih",
                    selection: $jumpDate,
                    in: DayIndex.epoch...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Theme.accent)
                .padding()

                Spacer()
            }
            .background(Theme.surface.ignoresSafeArea())
            .navigationTitle("Tarihe git")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { showsDatePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Git") {
                        showsDatePicker = false
                        jump(to: DayIndex.index(for: jumpDate))
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Eylemler

    private func openDay(_ day: Int, side: PageSide) {
        openAnchor = side == .left ? UnitPoint(x: 0.25, y: 0.45) : UnitPoint(x: 0.75, y: 0.45)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            selectedDay = day
        }
    }

    private func closeEditor() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
            selectedDay = nil
        }
    }

    private func goToToday() {
        jump(to: DayIndex.today)
    }

    private func jump(to day: Int) {
        let target = min(max(SpreadIndex.spread(for: day), SpreadIndex.minSpread), SpreadIndex.maxSpread)
        guard target != spread else { return }
        Haptics.pageTurn()
        withAnimation(.easeInOut(duration: 0.28)) {
            spread = target
        }
    }
}
