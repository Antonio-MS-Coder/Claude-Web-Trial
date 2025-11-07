# AudioReader - Listen to Your Content on the Go

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2017.0%2B-blue.svg" alt="Platform: iOS 17.0+">
  <img src="https://img.shields.io/badge/Language-Swift%205.9-orange.svg" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/Framework-SwiftUI-green.svg" alt="SwiftUI">
</p>

AudioReader is a modern, **human-centric** iOS app that converts various content types into audio, perfect for listening to articles, documents, and text while driving, exercising, or multitasking.

## Features

### Content Types Supported
- **PDFs** - Extract and listen to PDF documents
- **Web Pages** - Convert online articles to audio
- **Text** - Paste any text to convert to speech
- **Images** - OCR text extraction from photos using Apple Vision framework

### Key Features

#### Audio & Playback
- **Background Audio Playback** - Keep listening when the app is backgrounded or screen is locked (perfect for driving!)
- **Lock Screen Controls** - Full media controls on lock screen and control center
- **CarPlay Ready** - Remote control support for safe in-car use
- **High-Quality Text-to-Speech** - Uses Apple's AVSpeechSynthesizer with premium voices
- **Smart Playback Controls** - Play, pause, skip forward/backward (15 seconds)
- **Variable Speed** - Adjust playback speed from 0.75x to 2.0x
- **Auto-Play Next** - Automatically continue to next item in queue
- **Resume Playback** - Automatically saves your position in each content item

#### User Experience
- **Intuitive Onboarding** - Beautiful first-time experience explaining key features
- **Mini Player** - Quick access player stays at bottom while browsing library
- **Haptic Feedback** - Tactile responses for all interactions
- **Smooth Animations** - Spring-based animations throughout
- **Undo Delete** - Safety net with 5-second undo for accidental deletions
- **Smart Loading States** - Context-aware processing indicators
- **Actionable Error Messages** - Clear, helpful error messages with retry options
- **Empty States** - Encouraging guidance when library is empty

#### Organization
- **Beautiful UI** - Modern, intuitive SwiftUI interface with color-coded content types
- **Content Library** - Organize and manage all your audio content
- **Favorites** - Star your favorite content for quick access
- **Search & Filter** - Easily find content by type or search term
- **Persistent Storage** - All content saved locally for offline access
- **Smart Titles** - Auto-generated titles from content

## Architecture

AudioReader follows a clean MVVM architecture with SwiftUI:

```
AudioReader/
├── Models/
│   ├── ContentItem.swift       # Data model for content items
│   └── ContentStore.swift      # ObservableObject for managing library
├── Services/
│   ├── PDFExtractor.swift      # PDF text extraction using PDFKit
│   ├── WebExtractor.swift      # Web content extraction
│   ├── ImageTextExtractor.swift # OCR using Vision framework
│   └── AudioPlayerManager.swift # Text-to-speech + background audio
└── Views/
    ├── ContentView.swift       # Main app with onboarding
    ├── LibraryView.swift       # Content library with mini player
    ├── PlayerView.swift        # Full-screen audio player
    ├── AddContentView.swift    # Content import with smart loading
    ├── MiniPlayerView.swift    # Compact bottom player
    └── OnboardingView.swift    # First-time user experience
```

## Technology Stack

- **SwiftUI** - Modern declarative UI framework with animations
- **Combine** - Reactive programming for state management
- **AVFoundation** - Audio playback, text-to-speech, and background audio
- **MediaPlayer** - Now Playing info and remote control commands
- **UIKit** - Haptic feedback and advanced UI components
- **PDFKit** - PDF text extraction
- **Vision** - OCR for image text recognition
- **URLSession** - Web content fetching
- **UserDefaults** - Persistent storage with AppStorage

## Requirements

- iOS 17.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Installation

### Option 1: Using Xcode

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/AudioReader.git
   cd AudioReader
   ```

2. Open the project in Xcode:
   ```bash
   open AudioReader/AudioReader.xcodeproj
   ```

3. Select your target device or simulator

4. Build and run (⌘R)

### Option 2: Manual Build

```bash
cd AudioReader
xcodebuild -project AudioReader.xcodeproj -scheme AudioReader -configuration Debug
```

## Usage

### Adding Content

1. Tap the **+** button in the top right corner
2. Select your content type (Text, Web Page, PDF, or Image)
3. Provide the content:
   - **Text**: Paste or type your text
   - **Web Page**: Enter the URL
   - **PDF**: Select a PDF file (requires document picker)
   - **Image**: Select an image from your photo library
4. Tap **Add** to process and save

### Playing Content

1. Tap any item in your library to start playback
2. Use the player controls:
   - **Play/Pause**: Toggle playback
   - **Skip buttons**: Jump 15 seconds forward or backward
   - **Speed control**: Adjust from 0.75x to 2.0x
3. Playback position is automatically saved

### Managing Library

- **Search**: Use the search bar to find content
- **Filter**: Tap filter chips to show specific content types
- **Favorite**: Swipe right on an item to star it
- **Delete**: Swipe left on an item to delete it

## Apple Intelligence Integration

AudioReader leverages Apple's on-device intelligence features:

- **Vision Framework**: Advanced OCR for accurate text recognition from images
- **Natural Language Processing**: Used in text extraction and title generation
- **AVSpeechSynthesizer**: High-quality, natural-sounding voices with enhanced quality options
- **On-Device Processing**: All processing happens on-device for privacy and speed

## Privacy & Security

- All content processing happens **on-device**
- No data is sent to external servers (except when fetching web pages)
- Content is stored locally using UserDefaults
- No analytics or tracking
- No internet connection required after content is imported

## Roadmap

Completed:
- [x] Background audio playback with lock screen controls
- [x] Remote control support (CarPlay-ready)
- [x] Mini player for quick access
- [x] Onboarding experience
- [x] Haptic feedback throughout
- [x] Undo delete functionality
- [x] Auto-play next feature
- [x] Smart error messages
- [x] Beautiful loading states

Future enhancements planned:
- [ ] Full CarPlay native UI
- [ ] iCloud sync across devices
- [ ] Export audio files
- [ ] Podcast-style queue management
- [ ] Voice customization (pitch, gender, accent)
- [ ] Sleep timer
- [ ] Share extension for Safari
- [ ] Widget for quick access to recent content
- [ ] Siri shortcuts integration
- [ ] VoiceOver accessibility improvements

## Known Limitations

1. **PDF Import**: Currently requires implementation of document picker (placeholder in UI)
2. **Web Extraction**: Basic HTML parsing; may not work perfectly with all websites
3. **OCR Accuracy**: Depends on image quality and text clarity
4. **Playback Position**: Estimated based on text length (not exact timing)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is available under the MIT License. See LICENSE file for details.

## Acknowledgments

- Built with SwiftUI and modern iOS frameworks
- Inspired by the need for accessible content consumption while driving
- Uses Apple's native frameworks for privacy and performance

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Contact: [your-email@example.com]

---

**Note**: This app is designed for iOS 17.0+. Some features may require specific device capabilities (e.g., camera for OCR).

Made with ❤️ for iOS
