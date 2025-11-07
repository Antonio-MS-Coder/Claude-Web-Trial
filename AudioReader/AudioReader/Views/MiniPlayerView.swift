//
//  MiniPlayerView.swift
//  AudioReader
//
//  Compact player that stays at bottom for quick access
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @EnvironmentObject var contentStore: ContentStore
    @Binding var showFullPlayer: Bool

    var body: some View {
        if let item = audioPlayer.currentItem {
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 3)

                        Rectangle()
                            .fill(item.type.color)
                            .frame(
                                width: geometry.size.width * CGFloat(audioPlayer.currentPosition / item.duration),
                                height: 3
                            )
                            .animation(.linear(duration: 0.1), value: audioPlayer.currentPosition)
                    }
                }
                .frame(height: 3)

                // Mini player content
                HStack(spacing: 12) {
                    // Artwork thumbnail
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [item.type.color.opacity(0.6), item.type.color],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)

                        Image(systemName: item.type.icon)
                            .font(.title3)
                            .foregroundColor(.white)
                    }

                    // Title and info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Text(formatTime(audioPlayer.currentPosition))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(item.type.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Play/Pause button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            audioPlayer.togglePlayPause()
                        }
                    } label: {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(item.type.color)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }

                    // Forward button
                    Button {
                        audioPlayer.skip(seconds: 15)
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showFullPlayer = true
                    }
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    MiniPlayerView(showFullPlayer: .constant(false))
        .environmentObject({
            let player = AudioPlayerManager()
            player.currentItem = ContentItem(
                title: "Sample Article About Technology",
                type: .webpage,
                extractedText: "This is sample content"
            )
            player.isPlaying = true
            return player
        }())
        .environmentObject(ContentStore())
}
