import SwiftUI

/// Ana ekran: üstte ay bilgisi, ortada defter, altta sayfa okları.
/// Bir güne dokunulduğunda editör aynı ekranın üzerine açılıyor.
@MainActor
struct RootView: View {

    @EnvironmentObject private var store: DiaryStore
    @EnvironmentObject private var photos: PhotoStore
    @EnvironmentObject private var voices: VoiceStore
    @EnvironmentObject private var recorder: AudioRecorder
    @EnvironmentObject private var player: AudioPlayer
    @EnvironmentObject private var lock: AppLock
    @EnvironmentObject private var reminders: Reminders
    @EnvironmentObject private var cloud: CloudSync
    @EnvironmentObject private var subscriptions: SubscriptionStore

    @State private var spread: Int = SpreadIndex.spread(for: DayIndex.today)
    @State private var command: BookCommand?
    @State private var selectedDay: Int?
    @State private var openAnchor: UnitPoint = .center
    @State private var showsDatePicker = false
    @State private var showsSettings = false
    @State private var showsTrends = false
    @State private var paywallDay: PaywallRequest?
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
                    isSubscribed: subscriptions.isSubscribed,
                    onSelectDay: openDay(_:side:)
                )
                .padding(.horizontal, 10)

                pageControls
                    .padding(.bottom, 14)
            }

            if let selectedDay {
                EntryEditorView(day: selectedDay,
                                store: store,
                                photos: photos,
                                voices: voices,
                                recorder: recorder,
                                player: player,
                                onClose: closeEditor)
                    .transition(
                        .scale(scale: 0.92, anchor: openAnchor).combined(with: .opacity)
                    )
                    .zIndex(10)
            }
        }
        .sheet(item: $paywallDay) { request in
            PaywallView(subscriptions: subscriptions, requestedDay: request.day)
        }
        .sheet(isPresented: $showsDatePicker) { datePickerSheet }
        .sheet(isPresented: $showsTrends) {
            TrendsView(store: store)
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView(subscriptions: subscriptions,
                         store: store,
                         photos: photos,
                         voices: voices,
                         lock: lock,
                         reminders: reminders,
                         cloud: cloud)
        }
    }

    // MARK: - Üst çubuk

    private var topBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                // Ay kalın, yıl ince: aynı satırda iki ağırlık, başlığa
                // sakin bir hiyerarşi veriyor.
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(DayIndex.month(SpreadIndex.leftDay(of: spread)))
                        .font(.system(size: 27, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.ink)

                    Text(DayIndex.year(SpreadIndex.leftDay(of: spread)))
                        .font(.system(size: 19, weight: .regular, design: .serif))
                        .foregroundStyle(Theme.inkFaint)
                }
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.28), value: spread)

                if store.streak > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(store.streak) gün")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accentSoft))
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }

            Spacer(minLength: 8)

            if spread != SpreadIndex.spread(for: DayIndex.today) {
                Button(action: goToToday) {
                    Text("Bugün")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.accentSoft))
                }
                .buttonStyle(PressableButtonStyle())
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
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().strokeBorder(Theme.paperEdge.opacity(0.6), lineWidth: 0.5))
            }
            .accessibilityLabel("Seçenekler")
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: spread)
    }

    // MARK: - Sayfa okları

    private var pageControls: some View {
        HStack(spacing: 4) {
            arrowButton(systemName: "chevron.left",
                        label: "Önceki günler",
                        enabled: spread > SpreadIndex.minSpread) {
                command = .backward
            }

            Text(spreadRangeText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.inkSoft)
                .frame(minWidth: 92)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: spread)

            arrowButton(systemName: "chevron.right",
                        label: "Sonraki günler",
                        enabled: spread < SpreadIndex.maxSpread) {
                command = .forward
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
        )
        .overlay(
            Capsule().strokeBorder(Theme.paperEdge.opacity(0.5), lineWidth: 0.5)
        )
    }

    /// "18 – 19 Temmuz"
    private var spreadRangeText: String {
        let left = SpreadIndex.leftDay(of: spread)
        let right = SpreadIndex.rightDay(of: spread)
        return "\(DayIndex.dayNumber(left)) – \(DayIndex.dayNumber(right)) \(DayIndex.month(right))"
    }

    private func arrowButton(systemName: String,
                             label: String,
                             enabled: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? Theme.inkSoft : Theme.inkFaint.opacity(0.35))
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
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
        // Kilitli geçmiş gün: editör yerine abonelik ekranı açılıyor.
        let hasContent = store.entry(for: day)?.isEmpty == false
        if Paywall.isLocked(day: day,
                            isSubscribed: subscriptions.isSubscribed,
                            hasContent: hasContent) {
            paywallDay = PaywallRequest(day: day)
            return
        }

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

/// `sheet(item:)` bir `Identifiable` istiyor; gün numarasını sarmalıyor.
struct PaywallRequest: Identifiable {
    let day: Int
    var id: Int { day }
}
