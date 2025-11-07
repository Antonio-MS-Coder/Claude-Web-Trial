//
//  AudioPlayerManager.swift
//  AudioReader
//
//  Manages text-to-speech audio playback using AVFoundation
//  Enhanced with background playback, remote controls, and auto-play
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer
import UIKit

class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentItem: ContentItem?
    @Published var currentPosition: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    @Published var availableVoices: [AVSpeechSynthesisVoice] = []
    @Published var selectedVoice: AVSpeechSynthesisVoice?
    @Published var autoPlayNext: Bool = true
    @Published var queue: [ContentItem] = []

    private var synthesizer = AVSpeechSynthesizer()
    private var utterance: AVSpeechUtterance?
    private var timer: Timer?

    // For tracking position in text
    private var totalCharacters: Double = 0
    private var currentCharacterIndex: Double = 0

    // For auto-play next
    var onItemFinished: ((ContentItem) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        loadAvailableVoices()
        setupRemoteCommandCenter()
        setupNotifications()
    }

    private func setupAudioSession() {
        do {
            // Enable background audio playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)

            // This is critical for background playback
            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        // Skip forward
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skip(seconds: 15)
            self?.provideHapticFeedback(.light)
            return .success
        }

        // Skip backward
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skip(seconds: -15)
            self?.provideHapticFeedback(.light)
            return .success
        }

        // Next track (for queue)
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNextInQueue()
            return .success
        }

        // Previous track
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.restartCurrent()
            return .success
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Audio session interrupted (e.g., phone call)
            pause()
        case .ended:
            // Interruption ended - optionally resume
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    resume()
                }
            }
        @unknown default:
            break
        }
    }

    private func updateNowPlayingInfo() {
        guard let item = currentItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = item.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = "AudioReader"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = item.type.rawValue
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = item.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentPosition
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        // Add artwork
        if let artwork = generateArtwork(for: item) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func generateArtwork(for item: ContentItem) -> MPMediaItemArtwork? {
        let size = CGSize(width: 512, height: 512)
        return MPMediaItemArtwork(boundsSize: size) { _ in
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                // Draw gradient background
                let colors = [item.type.color.withAlphaComponent(0.6), item.type.color]
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors.map { $0.cgColor } as CFArray,
                    locations: [0.0, 1.0]
                )!

                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )

                // Draw icon
                let iconConfig = UIImage.SymbolConfiguration(pointSize: 200, weight: .semibold)
                if let icon = UIImage(systemName: item.type.icon, withConfiguration: iconConfig) {
                    let iconRect = CGRect(
                        x: (size.width - icon.size.width) / 2,
                        y: (size.height - icon.size.height) / 2,
                        width: icon.size.width,
                        height: icon.size.height
                    )
                    icon.withTintColor(.white).draw(in: iconRect)
                }
            }
        }
    }

    func provideHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private func loadAvailableVoices() {
        // Get high-quality English voices
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.starts(with: "en") }
            .sorted { $0.name < $1.name }

        // Select a default enhanced quality voice if available
        selectedVoice = availableVoices.first {
            $0.quality == .enhanced || $0.quality == .premium
        } ?? availableVoices.first
    }

    func play(_ item: ContentItem, from position: TimeInterval = 0) {
        stop()

        currentItem = item
        totalCharacters = Double(item.extractedText.count)
        currentCharacterIndex = (position / item.duration) * totalCharacters

        utterance = AVSpeechUtterance(string: item.extractedText)
        utterance?.voice = selectedVoice ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance?.rate = playbackRate * 0.5 // AVSpeechUtteranceDefaultSpeechRate
        utterance?.pitchMultiplier = 1.0
        utterance?.volume = 1.0

        synthesizer.speak(utterance!)
        isPlaying = true

        startPositionTimer()
        updateNowPlayingInfo()
        provideHapticFeedback(.light)
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPlaying = false
        stopPositionTimer()
        updateNowPlayingInfo()
        provideHapticFeedback(.light)
    }

    func resume() {
        synthesizer.continueSpeaking()
        isPlaying = true
        startPositionTimer()
        updateNowPlayingInfo()
        provideHapticFeedback(.light)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        currentPosition = 0
        stopPositionTimer()
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if synthesizer.isPaused {
            resume()
        } else if let item = currentItem {
            play(item, from: currentPosition)
        }
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        provideHapticFeedback(.light)
        if let item = currentItem, isPlaying {
            let savedPosition = currentPosition
            stop()
            play(item, from: savedPosition)
        }
    }

    func skip(seconds: TimeInterval) {
        guard let item = currentItem else { return }
        let newPosition = max(0, min(currentPosition + seconds, item.duration))
        let wasPlaying = isPlaying
        stop()
        if wasPlaying {
            play(item, from: newPosition)
        } else {
            currentPosition = newPosition
        }
        provideHapticFeedback(.light)
    }

    func playNextInQueue() {
        guard !queue.isEmpty else { return }
        let nextItem = queue.removeFirst()
        play(nextItem)
        provideHapticFeedback()
    }

    func restartCurrent() {
        guard let item = currentItem else { return }
        play(item, from: 0)
        provideHapticFeedback()
    }

    func addToQueue(_ items: [ContentItem]) {
        queue.append(contentsOf: items)
    }

    func clearQueue() {
        queue.removeAll()
    }

    // MARK: - Position Tracking

    private func startPositionTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePosition()
        }
    }

    private func stopPositionTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updatePosition() {
        guard let item = currentItem, totalCharacters > 0 else { return }
        // Estimate position based on character progress
        currentPosition = (currentCharacterIndex / totalCharacters) * item.duration

        // Update now playing info periodically
        updateNowPlayingInfo()
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioPlayerManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isPlaying = false
        currentPosition = currentItem?.duration ?? 0
        stopPositionTimer()

        // Notify that item finished (for saving progress)
        if let item = currentItem {
            onItemFinished?(item)
        }

        // Auto-play next item if enabled
        if autoPlayNext && !queue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.playNextInQueue()
            }
        } else {
            updateNowPlayingInfo()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isPlaying = false
        stopPositionTimer()
        updateNowPlayingInfo()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        currentCharacterIndex = Double(characterRange.location)
    }
}

// MARK: - Color Extension for CGColor

extension Color {
    var cgColor: CGColor {
        UIColor(self).cgColor
    }

    func withAlphaComponent(_ alpha: CGFloat) -> Color {
        return Color(UIColor(self).withAlphaComponent(alpha))
    }
}
