import UIKit
import SwiftUI
import AVFoundation

/// Custom keyboard extension with waveform + mic button and gradient animation during dictation.
class CrispKeyboardViewController: UIInputViewController {

    // MARK: - Properties

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var gradientLayer: CAGradientLayer?
    private var waveformBars: [UIView] = []
    private var isRecording = false

    private lazy var containerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.051, green: 0.051, blue: 0.055, alpha: 1.0)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var waveformContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var micButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.backgroundColor = UIColor(red: 0.784, green: 0.663, blue: 0.494, alpha: 1.0)
        btn.layer.cornerRadius = 28
        btn.setImage(UIImage(systemName: "mic.fill")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        ), for: .normal)
        btn.tintColor = UIColor(red: 0.051, green: 0.051, blue: 0.055, alpha: 1.0)
        btn.addTarget(self, action: #selector(micButtonLongPressed(_:)), for: .touchDown)
        btn.addTarget(self, action: #selector(micButtonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return btn
    }()

    private lazy var textLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.textColor = UIColor(red: 0.545, green: 0.545, blue: 0.557, alpha: 1.0)
        l.textAlignment = .center
        l.numberOfLines = 2
        l.text = "Hold to dictate"
        return l
    }()

    private lazy var waveformHint: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 11)
        l.textColor = UIColor(red: 0.545, green: 0.545, blue: 0.557, alpha: 0.7)
        l.textAlignment = .center
        l.text = "Dictation inserted at cursor"
        l.alpha = 0
        return l
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSpeechRecognizer()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupWaveformBars()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer?.frame = waveformContainer.bounds
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(containerView)
        containerView.addSubview(waveformContainer)
        containerView.addSubview(micButton)
        containerView.addSubview(textLabel)
        containerView.addSubview(waveformHint)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 160),

            waveformContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            waveformContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            waveformContainer.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            waveformContainer.heightAnchor.constraint(equalToConstant: 40),

            micButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            micButton.topAnchor.constraint(equalTo: waveformContainer.bottomAnchor, constant: 8),
            micButton.widthAnchor.constraint(equalToConstant: 56),
            micButton.heightAnchor.constraint(equalToConstant: 56),

            textLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            textLabel.topAnchor.constraint(equalTo: micButton.bottomAnchor, constant: 6),
            textLabel.widthAnchor.constraint(lessThanOrEqualTo: containerView.widthAnchor, constant: -40),

            waveformHint.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            waveformHint.topAnchor.constraint(equalTo: waveformContainer.bottomAnchor, constant: 8),
        ])
    }

    private func setupWaveformBars() {
        waveformBars.forEach { $0.removeFromSuperview() }
        waveformBars.removeAll()
        gradientLayer?.removeFromSuperlayer()
        gradientLayer = nil

        let barCount = 30
        let spacing: CGFloat = 3
        let totalSpacing = spacing * CGFloat(barCount - 1)
        let barWidth: CGFloat = (UIScreen.main.bounds.width - 40 - totalSpacing) / CGFloat(barCount)
        let containerWidth = waveformContainer.bounds.width

        for i in 0..<barCount {
            let bar = UIView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.backgroundColor = UIColor(red: 0.545, green: 0.545, blue: 0.557, alpha: 0.4)
            bar.layer.cornerRadius = 2
            waveformContainer.addSubview(bar)

            let xPos = CGFloat(i) * (barWidth + spacing)
            NSLayoutConstraint.activate([
                bar.leadingAnchor.constraint(equalTo: waveformContainer.leadingAnchor, constant: xPos),
                bar.widthAnchor.constraint(equalToConstant: barWidth),
                bar.centerYAnchor.constraint(equalTo: waveformContainer.centerYAnchor),
                bar.heightAnchor.constraint(equalToConstant: 8)
            ])

            waveformBars.append(bar)
        }

        // Gradient layer for recording animation
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 0.784, green: 0.663, blue: 0.494, alpha: 1.0).cgColor,
            UIColor(red: 0.831, green: 0.627, blue: 0.337, alpha: 1.0).cgColor,
            UIColor(red: 0.910, green: 0.584, blue: 0.416, alpha: 1.0).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = waveformContainer.bounds
        gradient.opacity = 0
        waveformContainer.layer.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
    }

    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Actions

    @objc private func micButtonLongPressed(_ sender: UIButton) {
        guard !isRecording else { return }
        startDictation()
    }

    @objc private func micButtonReleased(_ sender: UIButton) {
        guard isRecording else { return }
        stopDictation()
    }

    private func startDictation() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            showError("Speech recognition unavailable")
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.beginRecording()
                case .denied, .restricted:
                    self?.showError("Microphone or speech access denied")
                case .notDetermined:
                    self?.showError("Speech recognition not authorized")
                @unknown default:
                    self?.showError("Speech recognition unavailable")
                }
            }
        }
    }

    private func beginRecording() {
        isRecording = true
        textLabel.text = "Listening..."
        textLabel.textColor = UIColor(red: 0.784, green: 0.663, blue: 0.494, alpha: 1.0)

        // Animate gradient
        animateWaveformGradient(true)

        // Start animating bars
        animateBars()

        // Start audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            showError("Could not create recognition request")
            return
        }

        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                let transcript = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self?.textLabel.text = transcript.isEmpty ? "Listening..." : transcript
                }
            }

            if error != nil || result?.isFinal == true {
                self?.finishDictation(withFinal: result?.bestTranscription.formattedString ?? "")
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            showError("Audio engine failed to start")
        }
    }

    private func stopDictation() {
        finishDictation(withFinal: nil)
    }

    private func finishDictation(withFinal transcript: String?) {
        guard isRecording else { return }
        isRecording = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        // Stop animation
        animateWaveformGradient(false)
        stopBarAnimation()

        if let text = transcript, !text.isEmpty {
            // Insert text into the current text field
            textDocumentProxy.insertText(text)

            textLabel.text = "Inserted!"
            textLabel.textColor = UIColor(red: 0.784, green: 0.663, blue: 0.494, alpha: 1.0)

            // Show hint
            UIView.animate(withDuration: 0.2) {
                self.waveformHint.alpha = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                UIView.animate(withDuration: 0.3) {
                    self.waveformHint.alpha = 0
                }
                self.textLabel.text = "Hold to dictate"
                self.textLabel.textColor = UIColor(red: 0.545, green: 0.545, blue: 0.557, alpha: 1.0)
            }
        } else {
            textLabel.text = "Hold to dictate"
            textLabel.textColor = UIColor(red: 0.545, green: 0.545, blue: 0.557, alpha: 1.0)
        }
    }

    private func showError(_ message: String) {
        textLabel.text = message
        textLabel.textColor = .systemRed
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.textLabel.text = "Hold to dictate"
            self.textLabel.textColor = UIColor(red: 0.545, green: 0.545, blue: 0.557, alpha: 1.0)
        }
    }

    // MARK: - Animations

    private func animateWaveformGradient(_ on: Bool) {
        if on {
            gradientLayer?.opacity = 1

            let animation = CABasicAnimation(keyPath: "locations")
            animation.fromValue = [0.0, 0.0, 0.25]
            animation.toValue = [0.75, 1.0, 1.0]
            animation.duration = 1.5
            animation.repeatCount = .infinity
            gradientLayer?.add(animation, forKey: "gradientShift")
        } else {
            gradientLayer?.removeAnimation(forKey: "gradientShift")
            gradientLayer?.opacity = 0
        }
    }

    private var barAnimationTimer: Timer?

    private func animateBars() {
        barAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            self?.updateBarHeights()
        }
    }

    private func stopBarAnimation() {
        barAnimationTimer?.invalidate()
        barAnimationTimer = nil

        UIView.animate(withDuration: 0.3) {
            for bar in self.waveformBars {
                bar.backgroundColor = UIColor(red: 0.545, green: 0.545, blue: 0.557, alpha: 0.4)
                bar.constraints.forEach { constraint in
                    if constraint.firstAttribute == .height {
                        constraint.constant = 8
                    }
                }
            }
            self.waveformContainer.layoutIfNeeded()
        }
    }

    private func updateBarHeights() {
        for (index, bar) in waveformBars.enumerated() {
            let progress = sin(Double(index) * 0.4 + CACurrentMediaTime() * 4)
            let height = CGFloat(8 + progress * 16)

            bar.constraints.forEach { constraint in
                if constraint.firstAttribute == .height {
                    constraint.constant = height
                }
            }

            // Apply gradient color
            let ratio = CGFloat(index) / CGFloat(waveformBars.count)
            bar.backgroundColor = interpolateColor(
                from: UIColor(red: 0.784, green: 0.663, blue: 0.494, alpha: 1.0),
                to: UIColor(red: 0.910, green: 0.584, blue: 0.416, alpha: 1.0),
                ratio: ratio
            )
        }
        waveformContainer.layoutIfNeeded()
    }

    private func interpolateColor(from: UIColor, to: UIColor, ratio: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return UIColor(
            red: r1 + (r2 - r1) * ratio,
            green: g1 + (g2 - g1) * ratio,
            blue: b1 + (b2 - b1) * ratio,
            alpha: a1 + (a2 - a1) * ratio
        )
    }
}

import Speech
