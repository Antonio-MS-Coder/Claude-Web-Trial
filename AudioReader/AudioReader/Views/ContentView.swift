//
//  ContentView.swift
//  AudioReader
//
//  Main app view with tab navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var contentStore: ContentStore
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @State private var selectedTab = 0

    var body: some View {
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
    }
}

#Preview {
    ContentView()
        .environmentObject(ContentStore())
        .environmentObject(AudioPlayerManager())
}
