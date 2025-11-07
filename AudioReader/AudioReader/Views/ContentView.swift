//
//  ContentView.swift
//  AudioReader
//
//  Main app view with tab navigation and onboarding
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var contentStore: ContentStore
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "books.vertical.fill")
                    }
                    .tag(0)

                if audioPlayer.currentItem != nil {
                    PlayerView()
                        .tabItem {
                            Label("Now Playing", systemImage: "play.circle.fill")
                        }
                        .tag(1)
                }
            }
            .accentColor(.blue)
            .onAppear {
                // Setup callback for saving playback position
                audioPlayer.onItemFinished = { item in
                    contentStore.updatePlaybackPosition(for: item, position: item.duration)
                }

                // Show onboarding if first launch
                if !hasCompletedOnboarding {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showOnboarding = true
                    }
                }
            }

            // Onboarding overlay
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding)
                    .transition(.opacity)
                    .zIndex(1)
                    .onChange(of: showOnboarding) { _, newValue in
                        if !newValue {
                            hasCompletedOnboarding = true
                        }
                    }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ContentStore())
        .environmentObject(AudioPlayerManager())
}
