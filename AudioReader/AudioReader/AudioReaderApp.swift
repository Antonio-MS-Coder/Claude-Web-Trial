//
//  AudioReaderApp.swift
//  AudioReader
//
//  A modern iOS app that converts PDFs, web pages, text, and images into audio
//

import SwiftUI

@main
struct AudioReaderApp: App {
    @StateObject private var contentStore = ContentStore()
    @StateObject private var audioPlayer = AudioPlayerManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(contentStore)
                .environmentObject(audioPlayer)
        }
    }
}
