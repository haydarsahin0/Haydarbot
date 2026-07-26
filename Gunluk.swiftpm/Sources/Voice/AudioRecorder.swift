import AVFoundation
import Foundation

/// Sesli günlük kaydı alır.
///
/// Kayıt sırasında ses seviyesini de örnekliyor; bu hem canlı dalga
/// animasyonunu besliyor hem de kayıt bitince `VoiceNote` içine yazılıp
/// listede gerçek dalga biçimi olarak görünüyor. Böylece kaydedilmiş sesin
/// dalgasını çizmek için dosyayı sonradan çözümlemeye gerek kalmıyor.
@MainActor
final class AudioRecorder: NSObject, ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    /// Canlı dalga için son seviyeler (0...1), en yenisi sonda.
    @Published private(set) var liveLevels: [Double] = []
    @Published private(set) var permissionDenied = false

    /// Kaydedilmiş notta saklanacak dalga çubuğu sayısı.
    private let waveformSampleCount = 44
    private let sampleInterval: TimeInterval = 0.05
    /// Ekranda aynı anda görünen canlı çubuk sayısı.
    private let liveWindow = 34

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    /// Tüm kayıt boyunca toplanan seviyeler; bitişte örneklenip nota yazılıyor.
    private var collectedLevels: [Double] = []

    // MARK: - İzin

    func requestPermission() async -> Bool {
        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
        permissionDenied = !granted
        return granted
    }

    // MARK: - Kayıt

    func start(url: URL) async -> Bool {
        guard !isRecording else { return false }
        guard await requestPermission() else { return false }

        // Efektler oturum kategorisini değiştiriyor; kayıt boyunca sussunlar.
        SoundEffects.suspend()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .spokenAudio,
                                    options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            SoundEffects.resume()
            return false
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.record() else {
                SoundEffects.resume()
                return false
            }
            self.recorder = recorder
        } catch {
            SoundEffects.resume()
            return false
        }

        isRecording = true
        elapsed = 0
        liveLevels = []
        collectedLevels = []
        startTimer()
        Haptics.tap()
        return true
    }

    /// Kaydı bitirir ve nota dönüştürür. Kayıt çok kısaysa (kazara dokunma)
    /// dosya silinip `nil` dönülüyor.
    func stop(id: String) -> VoiceNote? {
        guard let recorder, isRecording else { return nil }

        let url = recorder.url
        let duration = recorder.currentTime
        recorder.stop()
        stopTimer()
        self.recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        SoundEffects.resume()

        guard duration >= 0.6 else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        Haptics.success()
        return VoiceNote(id: id,
                         duration: duration,
                         waveform: downsampled(collectedLevels))
    }

    func cancel() {
        guard let recorder else { return }
        let url = recorder.url
        recorder.stop()
        stopTimer()
        self.recorder = nil
        isRecording = false
        try? FileManager.default.removeItem(at: url)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        SoundEffects.resume()
    }

    // MARK: - Seviye örnekleme

    private func startTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        elapsed = recorder.currentTime

        // averagePower desibel veriyor (-160...0). Doğrusal genliğe çevirip
        // konuşma aralığında görünür olacak şekilde biraz yükseltiyoruz.
        let decibels = Double(recorder.averagePower(forChannel: 0))
        let linear = pow(10, decibels / 20)
        let level = min(1, max(0.04, pow(linear, 0.5) * 1.6))

        collectedLevels.append(level)
        liveLevels.append(level)
        if liveLevels.count > liveWindow {
            liveLevels.removeFirst(liveLevels.count - liveWindow)
        }
    }

    /// Toplanan seviyeleri sabit sayıda çubuğa indirger.
    private func downsampled(_ levels: [Double]) -> [Double] {
        guard levels.count > waveformSampleCount else {
            return levels.isEmpty ? Array(repeating: 0.25, count: 8) : levels
        }

        let bucketSize = Double(levels.count) / Double(waveformSampleCount)
        return (0..<waveformSampleCount).map { index in
            let start = Int(Double(index) * bucketSize)
            let end = min(levels.count, Int(Double(index + 1) * bucketSize))
            guard end > start else { return levels[min(start, levels.count - 1)] }
            let slice = levels[start..<end]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }
}
