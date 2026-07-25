import SwiftUI

/// Bir güne dokunulduğunda açılan tam ekran sayfa: serbest yazı alanı ve
/// günü puanlayan sorular. Kaydet düğmesi yok — yazılan her şey kendiliğinden
/// saklanıyor, üstteki küçük gösterge de bunu bildiriyor.
@MainActor
struct EntryEditorView: View {

    let day: Int
    @ObservedObject var store: DiaryStore
    let onClose: @MainActor () -> Void

    @State private var text: String = ""
    @State private var ratings: [String: Int] = [:]
    @FocusState private var isWriting: Bool

    /// Gelecekteki günlere yazılamaz.
    private var isEditable: Bool { !DayIndex.isFuture(day) }

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        dateHeader
                        writingArea
                        questionsSection
                        if isEditable { footerNote }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear(perform: loadFromStore)
        .onDisappear { store.flush() }
    }

    // MARK: - Üst çubuk

    private var toolbar: some View {
        HStack {
            Button(action: close) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Defter")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Theme.accent)
            }
            .accessibilityLabel("Deftere dön")

            Spacer()

            SaveIndicator(state: store.saveState)

            if isWriting {
                Button("Bitti") { isWriting = false }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .padding(.leading, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isWriting)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Tarih başlığı

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(DayIndex.monthAndYear(day).uppercased(with: DayIndex.locale))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(Theme.inkFaint)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(DayIndex.dayNumber(day))
                    .font(.system(size: 46, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)

                Text(DayIndex.weekday(day))
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.inkSoft)

                if DayIndex.isToday(day) {
                    Text("Bugün")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.accentSoft))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Yazı alanı

    private var writingArea: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(isWriting ? Theme.accent.opacity(0.45) : Theme.paperEdge,
                                      lineWidth: isWriting ? 1.5 : 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)

            if text.isEmpty {
                Text(isEditable ? "Bugün neler oldu?" : "Bu gün henüz gelmedi.")
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.system(size: 17, design: .serif))
                .foregroundStyle(Theme.ink)
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($isWriting)
                .disabled(!isEditable)
                .padding(.horizontal, 17)
                .padding(.vertical, 16)
        }
        .frame(minHeight: 240)
        .animation(.easeInOut(duration: 0.2), value: isWriting)
        .onChange(of: text) { _, newValue in
            guard isEditable else { return }
            store.setText(newValue, for: day)
        }
    }

    // MARK: - Sorular

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Günü puanla")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Theme.inkFaint)

                Rectangle()
                    .fill(Theme.paperEdge)
                    .frame(height: 1)
            }
            .padding(.top, 4)

            ForEach(RatingQuestion.all) { question in
                RatingSlider(
                    question: question,
                    value: binding(for: question),
                    isEnabled: isEditable
                )
            }
        }
    }

    private var footerNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
            Text("Yazdıkların yalnızca bu cihazda saklanıyor.")
                .font(.system(size: 12, design: .rounded))
        }
        .foregroundStyle(Theme.inkFaint)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Veri bağlantısı

    private func binding(for question: RatingQuestion) -> Binding<Int?> {
        Binding(
            get: { ratings[question.id] },
            set: { newValue in
                guard let newValue else {
                    ratings.removeValue(forKey: question.id)
                    store.removeRating(question: question, for: day)
                    return
                }
                ratings[question.id] = newValue
                store.setRating(newValue, question: question, for: day)
            }
        )
    }

    private func loadFromStore() {
        let entry = store.entry(for: day)
        text = entry?.text ?? ""
        ratings = entry?.ratings ?? [:]
    }

    private func close() {
        isWriting = false
        store.flush()
        onClose()
    }
}

/// "Kaydediliyor…" / "Kaydedildi" göstergesi.
private struct SaveIndicator: View {
    let state: DiaryStore.SaveState

    var body: some View {
        HStack(spacing: 5) {
            switch state {
            case .idle:
                EmptyView()
            case .saving:
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                Text("Kaydediliyor")
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Kaydedildi")
            }
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(state == .saved ? Theme.accent : Theme.inkFaint)
        .padding(.horizontal, state == .idle ? 0 : 10)
        .padding(.vertical, state == .idle ? 0 : 5)
        .background(
            Capsule().fill(state == .idle ? Color.clear : Theme.paper.opacity(0.9))
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state)
    }
}
