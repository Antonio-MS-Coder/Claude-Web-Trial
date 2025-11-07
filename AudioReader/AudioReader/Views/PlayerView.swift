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

                            Text(item.type.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
