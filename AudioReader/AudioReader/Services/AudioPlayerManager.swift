//
//  AudioPlayerManager.swift
//  AudioReader
//
//  Manages text-to-speech audio playback using AVFoundation
//

import Foundation
import AVFoundation
import Combine

class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentItem: ContentItem?
    @Published var currentPosition: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    @Published var availableVoices: [AVSpeechSynthesisVoice] = []
    @Published var selectedVoice: AVSpeechSynthesisVoice?

    private var synthesizer = AVSpeechSynthesizer()
    private var utterance: AVSpeechUtterance?
    private var timer: Timer?

    // For tracking position in text
    private var totalCharacters: Double = 0
    private var currentCharacterIndex: Double = 0

    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        loadAvailableVoices()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \\(error)")
        }
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
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPlaying = false
        stopPositionTimer()
    }

    func resume() {
        synthesizer.continueSpeaking()
        isPlaying = true
        startPositionTimer()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        currentPosition = 0
        stopPositionTimer()
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
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioPlayerManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isPlaying = false
        currentPosition = currentItem?.duration ?? 0
        stopPositionTimer()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isPlaying = false
        stopPositionTimer()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        currentCharacterIndex = Double(characterRange.location)
    }
}
