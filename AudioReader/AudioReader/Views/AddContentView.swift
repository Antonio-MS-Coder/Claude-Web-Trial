//
//  AddContentView.swift
//  AudioReader
//
//  Interface for adding new content (PDF, web, text, images)
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AddContentView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var contentStore: ContentStore

    @State private var selectedType: ContentType = .text
    @State private var inputText = ""
    @State private var urlString = ""
    @State private var showingFilePicker = false
    @State private var showingImagePicker = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        NavigationView {
            Form {
                // Type selector
                Section("Content Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(ContentType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Input section based on selected type
                Section("Content") {
                    switch selectedType {
                    case .text:
                        TextInputSection(text: $inputText)

                    case .webpage:
                        WebInputSection(urlString: $urlString)

                    case .pdf:
                        PDFInputSection(showingFilePicker: $showingFilePicker)

                    case .image:
                        ImageInputSection(
                            selectedImage: $selectedImage,
                            showingImagePicker: $showingImagePicker
                        )
                    }
                }

                // Help text
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text(helpText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task {
                            await processContent()
                        }
                    }
                    .disabled(!canAdd || isProcessing)
                }
            }
            .overlay {
                if isProcessing {
                    ProcessingOverlay(contentType: selectedType)
                }
            }
            .alert("Unable to Add Content", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                }
                if selectedType == .webpage {
                    Button("Try Again") {
                        Task {
                            await processContent()
                        }
                    }
                }
            } message: {
                Text(getActionableErrorMessage())
            }
        }
    }

    private var canAdd: Bool {
        switch selectedType {
        case .text:
            return !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .webpage:
            return !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .pdf:
            return true
        case .image:
            return selectedImage != nil
        }
    }

    private var helpText: String {
        switch selectedType {
        case .text:
            return "Paste or type any text you want to listen to"
        case .webpage:
            return "Enter a URL to extract and listen to the article"
        case .pdf:
            return "Select a PDF file to extract and listen to its content"
        case .image:
            return "Select an image with text to extract using OCR"
        }
    }

    private func processContent() async {
        isProcessing = true
        errorMessage = nil

        do {
            let item: ContentItem

            switch selectedType {
            case .text:
                item = ContentItem(
                    title: generateTitle(from: inputText),
                    type: .text,
                    extractedText: inputText
                )

            case .webpage:
                let (title, content) = try await WebExtractor.extractText(from: urlString)
                item = ContentItem(
                    title: title,
                    type: .webpage,
                    extractedText: content
                )

            case .pdf:
                // Note: This is a placeholder. In a real app, you'd get the PDF from a file picker
                throw ExtractionError.invalidPDF

            case .image:
                guard let selectedImage = selectedImage else {
                    throw ExtractionError.imageProcessingFailed
                }

                guard let imageData = try await selectedImage.loadTransferable(type: Data.self) else {
                    throw ExtractionError.imageProcessingFailed
                }

                let extractedText = try await ImageTextExtractor.extractText(from: imageData)
                item = ContentItem(
                    title: generateTitle(from: extractedText),
                    type: .image,
                    extractedText: extractedText
                )
            }

            contentStore.addItem(item)
            isProcessing = false

            // Success feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            dismiss()

        } catch {
            isProcessing = false
            errorMessage = error.localizedDescription
            showingError = true

            // Error feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }

    private func generateTitle(from text: String) -> String {
        let words = text.prefix(100).split(separator: " ")
        let title = words.prefix(8).joined(separator: " ")
        return title.isEmpty ? "Untitled" : title + (words.count > 8 ? "..." : "")
    }

    private func getActionableErrorMessage() -> String {
        guard let errorMessage = errorMessage else {
            return "An unexpected error occurred. Please try again."
        }

        // Provide helpful, actionable error messages
        switch selectedType {
        case .pdf:
            return "Unable to extract text from PDF. Make sure the PDF contains readable text and is not scanned images only."

        case .webpage:
            if errorMessage.contains("Invalid URL") || errorMessage.contains("invalid") {
                return "Please check the URL and make sure it's complete (e.g., https://example.com/article)"
            } else if errorMessage.contains("network") || errorMessage.contains("Internet") {
                return "Unable to load web page. Check your internet connection and try again."
            } else {
                return "Unable to extract content from this web page. Some websites may block automated access."
            }

        case .image:
            if errorMessage.contains("no text") || errorMessage.contains("No text") {
                return "No text detected in the image. Make sure the image contains clear, readable text."
            } else {
                return "Unable to process the image. Try selecting a clearer image with visible text."
            }

        case .text:
            return "Unable to add text. Make sure you've entered some content."
        }
    }
}

// MARK: - Input Sections

struct TextInputSection: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter or paste text")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $text)
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

struct WebInputSection: View {
    @Binding var urlString: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter URL")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("https://example.com/article", text: $urlString)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .textInputAutocapitalization(.never)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

struct PDFInputSection: View {
    @Binding var showingFilePicker: Bool

    var body: some View {
        VStack(spacing: 16) {
            Button {
                showingFilePicker = true
            } label: {
                HStack {
                    Image(systemName: "doc.fill")
                    Text("Select PDF File")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .foregroundColor(.primary)

            Text("PDF import requires document picker integration")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
}

struct ImageInputSection: View {
    @Binding var selectedImage: PhotosPickerItem?
    @Binding var showingImagePicker: Bool

    var body: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $selectedImage, matching: .images) {
                HStack {
                    Image(systemName: "photo")
                    Text(selectedImage == nil ? "Select Image" : "Image Selected")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .foregroundColor(.primary)
        }
    }
}

// MARK: - Processing Overlay

struct ProcessingOverlay: View {
    let contentType: ContentType

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(contentType.color.opacity(0.2))
                        .frame(width: 80, height: 80)

                    if #available(iOS 17.0, *) {
                        Image(systemName: contentType.icon)
                            .font(.largeTitle)
                            .foregroundColor(contentType.color)
                            .symbolEffect(.pulse, options: .repeating)
                    } else {
                        Image(systemName: contentType.icon)
                            .font(.largeTitle)
                            .foregroundColor(contentType.color)
                    }
                }

                VStack(spacing: 8) {
                    Text(processingTitle)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(processingSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                ProgressView()
                    .tint(.white)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemGray).opacity(0.95))
                    .shadow(color: .black.opacity(0.3), radius: 20)
            )
            .padding(.horizontal, 40)
        }
    }

    private var processingTitle: String {
        switch contentType {
        case .text:
            return "Processing Text"
        case .webpage:
            return "Fetching Web Page"
        case .pdf:
            return "Extracting PDF"
        case .image:
            return "Reading Image"
        }
    }

    private var processingSubtitle: String {
        switch contentType {
        case .text:
            return "Preparing your text for playback..."
        case .webpage:
            return "Downloading and extracting content..."
        case .pdf:
            return "Extracting text from PDF..."
        case .image:
            return "Using OCR to detect text..."
        }
    }
}

#Preview {
    AddContentView()
        .environmentObject(ContentStore())
}
