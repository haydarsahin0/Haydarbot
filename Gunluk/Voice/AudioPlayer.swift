import AVFoundation
import Foundation

/// Sesli günlük kayıtlarını çalar. Aynı anda tek kayıt çalıyor; başka birine
/// dokunulunca öncekini durduruyor.
@MainActor
final class AudioPlayer: NSObject, ObservableObject {

    /// Şu an çalan kaydın kimliği; hiçbiri çalmıyorsa `nil`.
    @Published private(set) var playingID: String?
    /// 0...1 arası ilerleme, dalga çubuklarını doldurmak için.
    @Published private(set) var progress: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?
    /// Efektler susturulduysa `stop()` bunu geri almalı; `play()` ve `stop()`
    /// her sırada çağrılabildiği için askı durumu burada takip ediliyor.
    private var didSuspendEffects = false

    func toggle(id: String, url: URL) {
        if playingID == id {
            stop()
        } else {
            play(id: id, url: url)
        }
    }

    func play(id: String, url: URL) {
        stop()
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        // Efektler oturumu `.ambient`'a çekiyor; kayıt çalarken sussunlar.
        SoundEffects.suspend()
        didSuspendEffects = true

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            guard player.play() else {
                releaseEffects()
                return
            }
            self.player = player
        } catch {
            releaseEffects()
            return
        }

        playingID = id
        progress = 0
        startTimer()
        Haptics.tap()
    }

    func stop() {
        player?.stop()
        player = nil
        timer?.invalidate()
        timer = nil
        playingID = nil
        progress = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        releaseEffects()
    }

    private func releaseEffects() {
        guard didSuspendEffects else { return }
        didSuspendEffects = false
        SoundEffects.resume()
    }

    private func startTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player, player.duration > 0 else { return }
                self.progress = min(1, player.currentTime / player.duration)
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.progress = 1
            self.stop()
        }
    }
}
