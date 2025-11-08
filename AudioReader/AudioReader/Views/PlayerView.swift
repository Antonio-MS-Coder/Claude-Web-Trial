//
//  PlayerView.swift
//  AudioReader
//
//  Audio player interface with playback controls
//

import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @EnvironmentObject var contentStore: ContentStore

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    if let item = audioPlayer.currentItem {
                        // Artwork
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [item.type.color.opacity(0.6), item.type.color],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 280, height: 280)
                                .shadow(radius: 10)

                            Image(systemName: item.type.icon)
                                .font(.system(size: 100))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 40)

                        // Title and info
                        VStack(spacing: 8) {
                            Text(item.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)

                            HStack(spacing: 8) {
                                Text(item.type.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("•")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .font(.caption)
                                    Text(item.languageDisplayName)
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)

                        // Progress bar
                        VStack(spacing: 8) {
                            ProgressView(value: audioPlayer.currentPosition, total: item.duration)
                                .tint(item.type.color)

                            HStack {
                                Text(formatTime(audioPlayer.currentPosition))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(formatTime(item.duration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 30)

                        // Main playback controls
                        HStack(spacing: 50) {
                            Button {
                                audioPlayer.skip(seconds: -15)
                            } label: {
                                Image(systemName: "gobackward.15")
                                    .font(.system(size: 32))
                            }

                            Button {
                                audioPlayer.togglePlayPause()
                            } label: {
                                Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 72))
                            }

                            Button {
                                audioPlayer.skip(seconds: 15)
                            } label: {
                                Image(systemName: "goforward.15")
                                    .font(.system(size: 32))
                            }
                        }
                        .foregroundColor(item.type.color)
                        .padding(.vertical)

                        // Playback rate
                        VStack(spacing: 12) {
                            Text("Playback Speed")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 16) {
                                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                                    PlaybackRateButton(
                                        rate: rate,
                                        isSelected: abs(audioPlayer.playbackRate - Float(rate)) < 0.01,
                                        color: item.type.color
                                    ) {
                                        audioPlayer.setPlaybackRate(Float(rate))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Language selection
                        LanguageSelector(item: item)
                            .environmentObject(contentStore)
                            .environmentObject(audioPlayer)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        // Content preview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Content")
                                .font(.headline)

                            ScrollView {
                                Text(item.extractedText)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 200)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Language Selector

struct LanguageSelector: View {
    let item: ContentItem
    @EnvironmentObject var contentStore: ContentStore
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @State private var showingLanguagePicker = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Voice Language")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if item.manualLanguageOverride != nil {
                    Text("Manual")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                }
            }

            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                showingLanguagePicker = true
            } label: {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .foregroundColor(item.type.color)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.languageDisplayName)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            if item.manualLanguageOverride == nil {
                                Text("Auto-detected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Manually selected")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showingLanguagePicker) {
            LanguagePickerSheet(item: item)
                .environmentObject(contentStore)
                .environmentObject(audioPlayer)
        }
    }
}

// MARK: - Language Picker Sheet

struct LanguagePickerSheet: View {
    let item: ContentItem
    @EnvironmentObject var contentStore: ContentStore
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button {
                        resetToAutoDetect()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto-detect Language")
                                    .font(.body)
                                    .foregroundColor(.primary)

                                Text("Detected: \(item.detectedLanguage.uppercased()) - \(Locale(identifier: "en").localizedString(forLanguageCode: item.detectedLanguage)?.capitalized ?? item.detectedLanguage)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if item.manualLanguageOverride == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                } header: {
                    Text("Automatic")
                }

                Section {
                    ForEach(ContentItem.supportedLanguages, id: \.code) { language in
                        Button {
                            setLanguage(language.code)
                        } label: {
                            HStack {
                                Text(language.name)
                                    .foregroundColor(.primary)

                                Spacer()

                                if item.manualLanguageOverride == language.code {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Manual Selection")
                } footer: {
                    Text("If the auto-detected language is incorrect, you can manually select the correct language here.")
                }
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func setLanguage(_ languageCode: String) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        var updatedItem = item
        updatedItem.manualLanguageOverride = languageCode
        contentStore.updateItem(updatedItem)

        // If this is the currently playing item, restart playback with new language
        if audioPlayer.currentItem?.id == item.id {
            let currentPosition = audioPlayer.currentPosition
            let wasPlaying = audioPlayer.isPlaying
            audioPlayer.stop()
            if wasPlaying {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    audioPlayer.play(updatedItem, from: currentPosition)
                }
            } else {
                audioPlayer.currentItem = updatedItem
            }
        }
    }

    private func resetToAutoDetect() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        var updatedItem = item
        updatedItem.manualLanguageOverride = nil
        contentStore.updateItem(updatedItem)

        // If this is the currently playing item, restart playback with auto-detected language
        if audioPlayer.currentItem?.id == item.id {
            let currentPosition = audioPlayer.currentPosition
            let wasPlaying = audioPlayer.isPlaying
            audioPlayer.stop()
            if wasPlaying {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    audioPlayer.play(updatedItem, from: currentPosition)
                }
            } else {
                audioPlayer.currentItem = updatedItem
            }
        }
    }
}

// MARK: - Playback Rate Button

struct PlaybackRateButton: View {
    let rate: Double
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(rate, specifier: "%.2g")×")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 50, height: 36)
                .background(isSelected ? color : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(18)
        }
    }
}

#Preview {
    PlayerView()
        .environmentObject({
            let player = AudioPlayerManager()
            player.currentItem = ContentItem(
                title: "Sample Article",
                type: .webpage,
                extractedText: "This is a sample article content..."
            )
            return player
        }())
        .environmentObject(ContentStore())
}
