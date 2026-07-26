import SwiftUI

/// Gün editöründeki sesli günlük bölümü.
///
/// Kayıt düğmesi basılıyken daire yerini yuvarlatılmış kareye bırakıyor ve
/// yanında canlı dalga akıyor. Kayıt bitince nota kendi dalga biçimiyle
/// listeye yaylanarak giriyor; çalarken dalga soldan sağa doluyor.
@MainActor
struct VoiceSection: View {

    let day: Int
    @ObservedObject var store: DiaryStore
    @ObservedObject var voices: VoiceStore
    @ObservedObject var recorder: AudioRecorder
    @ObservedObject var player: AudioPlayer
    var isEnabled: Bool = true

    @State private var pendingID: String?

    private var notes: [VoiceNote] {
        store.entry(for: day)?.voiceNotes ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if !notes.isEmpty {
                VStack(spacing: 10) {
                    ForEach(notes) { note in
                        VoiceNoteRow(
                            note: note,
                            isPlaying: player.playingID == note.id,
                            progress: player.playingID == note.id ? player.progress : 0,
                            onPlay: { player.toggle(id: note.id, url: voices.url(for: note.id)) },
                            onDelete: { remove(note) }
                        )
                    }
                }
            }

            if isEnabled {
                recordBar
            }
        }
        .onDisappear {
            player.stop()
            if recorder.isRecording { finishRecording() }
        }
    }

    // MARK: - Başlık

    private var header: some View {
        HStack(spacing: 8) {
            Text("Sesli günlük")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Theme.inkFaint)

            Rectangle()
                .fill(Theme.paperEdge)
                .frame(height: 1)
        }
    }

    // MARK: - Kayıt çubuğu

    private var recordBar: some View {
        HStack(spacing: 14) {
            recordButton

            if recorder.isRecording {
                LiveWaveform(levels: recorder.liveLevels)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)

                Text(timeText(recorder.elapsed))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Konuşarak yaz")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(recorder.permissionDenied
                         ? "Mikrofon izni kapalı"
                         : "Bugünü anlatmak için dokun")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(recorder.permissionDenied ? Theme.accent : Theme.inkFaint)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(recorder.isRecording ? Theme.accent.opacity(0.5) : Theme.paperEdge,
                              lineWidth: recorder.isRecording ? 1.5 : 1)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: recorder.isRecording)
    }

    private var recordButton: some View {
        Button {
            if recorder.isRecording {
                finishRecording()
            } else {
                startRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(Theme.accent.opacity(0.35), lineWidth: 2)
                    .frame(width: 46, height: 46)

                // Daire kayıt sırasında kareye dönüşüyor; iOS'un ses
                // kaydedicilerindeki tanıdık hareket.
                RoundedRectangle(cornerRadius: recorder.isRecording ? 6 : 17,
                                 style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: recorder.isRecording ? 20 : 34,
                           height: recorder.isRecording ? 20 : 34)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recorder.isRecording ? "Kaydı bitir" : "Ses kaydı başlat")
    }

    // MARK: - Eylemler

    private func startRecording() {
        let id = UUID().uuidString
        pendingID = id
        Task {
            let started = await recorder.start(url: voices.url(for: id))
            if !started { pendingID = nil }
        }
    }

    private func finishRecording() {
        guard let id = pendingID else { return }
        pendingID = nil
        guard let note = recorder.stop(id: id) else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            store.addVoiceNote(note, for: day)
        }
    }

    private func remove(_ note: VoiceNote) {
        if player.playingID == note.id { player.stop() }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            store.removeVoiceNote(id: note.id, for: day)
        }
        voices.delete(note.id)
        Haptics.tap()
        SoundEffects.tap()
    }

    private func timeText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Kaydedilmiş not satırı

@MainActor
private struct VoiceNoteRow: View {
    let note: VoiceNote
    let isPlaying: Bool
    let progress: Double
    let onPlay: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                ZStack {
                    Circle()
                        .fill(Theme.accentSoft)
                        .frame(width: 38, height: 38)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .offset(x: isPlaying ? 0 : 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Duraklat" : "Çal")

            StaticWaveform(levels: note.waveform, progress: isPlaying ? progress : 0)
                .frame(height: 30)
                .frame(maxWidth: .infinity)

            Text(note.durationText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.paperEdge, lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Sil", systemImage: "trash")
            }
        }
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }
}

// MARK: - Dalga çizimleri

/// Kayıt sırasında akan dalga. En yeni seviye sağda.
@MainActor
private struct LiveWaveform: View {
    let levels: [Double]

    var body: some View {
        GeometryReader { geo in
            let barWidth: CGFloat = 3
            let spacing: CGFloat = 3
            let capacity = max(1, Int((geo.size.width + spacing) / (barWidth + spacing)))
            let shown = Array(levels.suffix(capacity))

            HStack(alignment: .center, spacing: spacing) {
                Spacer(minLength: 0)
                ForEach(Array(shown.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: barWidth,
                               height: max(3, geo.size.height * level))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .trailing)
            .animation(.linear(duration: 0.05), value: levels.count)
        }
    }
}

/// Kaydedilmiş notun dalgası. Çalarken soldan sağa doluyor.
@MainActor
private struct StaticWaveform: View {
    let levels: [Double]
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let bars = levels.isEmpty ? Array(repeating: 0.3, count: 30) : levels
            let spacing: CGFloat = 2.5
            let barWidth = max(2, (geo.size.width - spacing * CGFloat(bars.count - 1)) / CGFloat(bars.count))
            let playedCount = Int(Double(bars.count) * progress)

            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, level in
                    Capsule()
                        .fill(index < playedCount ? Theme.accent : Theme.inkFaint.opacity(0.45))
                        .frame(width: barWidth,
                               height: max(2.5, geo.size.height * level))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.linear(duration: 0.05), value: playedCount)
        }
    }
}
