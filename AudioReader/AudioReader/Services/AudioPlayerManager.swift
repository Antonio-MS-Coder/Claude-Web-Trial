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

    deinit {
        // Clean up resources to prevent memory leaks
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self)
        synthesizer.stopSpeaking(at: .immediate)
        print("🧹 AudioPlayerManager deallocated")
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
                if let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors.map { $0.cgColor } as CFArray,
                    locations: [0.0, 1.0]
                ) {
                    context.cgContext.drawLinearGradient(
                        gradient,
                        start: .zero,
                        end: CGPoint(x: size.width, y: size.height),
                        options: []
                    )
                }

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
        // Get all voices (all languages)
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .sorted { $0.name < $1.name }

        // Select best default English voice for initial selection
        selectedVoice = selectBestVoice(for: "en")

        print("🎙️ Available voices: \(availableVoices.count)")
        print("🎙️ Default selected voice: \(selectedVoice?.name ?? "Unknown") - Language: \(selectedVoice?.language ?? "Unknown")")
    }

    // Select the best voice for a given language
    private func selectBestVoice(for languageCode: String) -> AVSpeechSynthesisVoice {
        // Get all voices for this language
        let languageVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.starts(with: languageCode) }

        // Separate by quality
        let enhancedVoices = languageVoices.filter { $0.quality == .enhanced }
        let premiumVoices = languageVoices.filter { $0.quality == .premium }

        // Language-specific preferred voices
        var preferredVoiceNames: [String] = []

        switch languageCode {
        case "en":
            preferredVoiceNames = ["Samantha", "Alex", "Ava", "Nicky", "Zoe"]
        case "es":
            // Spanish voices: Prefer Mónica (Spain), Paulina (Mexico), or other high-quality options
            preferredVoiceNames = ["Monica", "Mónica", "Paulina", "Juan", "Diego", "Isabela"]
        case "fr":
            preferredVoiceNames = ["Thomas", "Amélie"]
        case "de":
            preferredVoiceNames = ["Anna", "Helena"]
        case "it":
            preferredVoiceNames = ["Alice", "Luca"]
        case "pt":
            preferredVoiceNames = ["Luciana", "Joana"]
        default:
            break
        }

        // Try to find a preferred enhanced voice
        if let voice = enhancedVoices.first(where: { voice in
            preferredVoiceNames.contains { voice.name.contains($0) }
        }) {
            print("🎙️ Selected enhanced voice: \(voice.name) (\(voice.language))")
            return voice
        }

        // Try any enhanced voice
        if let voice = enhancedVoices.first {
            print("🎙️ Selected enhanced voice: \(voice.name) (\(voice.language))")
            return voice
        }

        // Try any premium voice
        if let voice = premiumVoices.first {
            print("🎙️ Selected premium voice: \(voice.name) (\(voice.language))")
            return voice
        }

        // Fallback to first available voice for this language
        if let voice = languageVoices.first {
            print("🎙️ Selected fallback voice: \(voice.name) (\(voice.language))")
            return voice
        }

        // Ultimate fallback to system default
        print("⚠️ No voice found for language: \(languageCode), using system default")
        return AVSpeechSynthesisVoice(language: "\(languageCode)-\(languageCode.uppercased())") ?? AVSpeechSynthesisVoice(language: "en-US")!
    }

    // Helper to map user playback rate to optimal AVSpeechUtterance rate
    private func mapToSpeechRate(_ userRate: Float) -> Float {
        // AVSpeechUtteranceDefaultSpeechRate is ~0.5
        // We want to keep rates in the sweet spot (0.4-0.6) for natural sound
        // Mapping:
        // 0.75x -> 0.45 (slower, clearer)
        // 1.0x  -> 0.50 (default, most natural)
        // 1.25x -> 0.53 (slightly faster but still natural)
        // 1.5x  -> 0.56 (faster but clear)
        // 2.0x  -> 0.58 (fast but not robotic)

        let baseRate: Float = 0.5 // AVSpeechUtteranceDefaultSpeechRate
        let adjustment = (userRate - 1.0) * 0.08 // Gentle scaling
        return max(0.4, min(0.6, baseRate + adjustment))
    }

    func play(_ item: ContentItem, from position: TimeInterval = 0) {
        stop()

        // Guard against empty text
        guard !item.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ Cannot play item with empty text")
            return
        }

        currentItem = item
        totalCharacters = Double(item.extractedText.count)
        currentCharacterIndex = item.duration > 0 ? (position / item.duration) * totalCharacters : 0

        // Select voice based on effective language (manual override or detected)
        let voiceForContent = selectBestVoice(for: item.effectiveLanguage)

        let newUtterance = AVSpeechUtterance(string: item.extractedText)
        newUtterance.voice = voiceForContent
        newUtterance.rate = mapToSpeechRate(playbackRate) // Use natural rate mapping
        newUtterance.pitchMultiplier = 1.0 // Keep natural pitch
        newUtterance.volume = 0.95 // Slightly softer for comfort
        newUtterance.preUtteranceDelay = 0.1 // Small pause before starting

        let languageSource = item.manualLanguageOverride != nil ? "manual" : "auto-detected"
        print("🎵 Playing '\(item.title)' in \(item.effectiveLanguage.uppercased()) (\(languageSource)) with voice: \(voiceForContent.name)")

        utterance = newUtterance
        synthesizer.speak(newUtterance)
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
