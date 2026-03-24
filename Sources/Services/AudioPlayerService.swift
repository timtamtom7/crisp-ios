import AVFoundation
import Combine

final class AudioPlayerService: ObservableObject {
    private var player: AVAudioPlayer?

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0

    private var timer: Timer?

    static let speedOptions: [Float] = [0.5, 1.0, 1.5, 2.0]

    func play(url: URL) throws {
        stop()

        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)

        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = nil
        player?.prepareToPlay()
        player?.enableRate = true
        player?.rate = playbackRate
        duration = player?.duration ?? 0

        player?.play()

        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func resume() {
        player?.rate = playbackRate
        player?.play()
        isPlaying = true
        startTimer()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimer()
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func skipForward(seconds: TimeInterval = 15) {
        guard let player = player else { return }
        let newTime = min(player.currentTime + seconds, duration)
        seek(to: newTime)
    }

    func skipBackward(seconds: TimeInterval = 15) {
        guard let player = player else { return }
        let newTime = max(player.currentTime - seconds, 0)
        seek(to: newTime)
    }

    func setSpeed(_ speed: Float) {
        playbackRate = speed
        player?.rate = speed
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = self?.player?.currentTime ?? 0
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
