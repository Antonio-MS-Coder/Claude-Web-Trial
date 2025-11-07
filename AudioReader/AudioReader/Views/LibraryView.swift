//
//  LibraryView.swift
//  AudioReader
//
//  Library view showing all saved content items
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var contentStore: ContentStore
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @State private var showingAddContent = false
    @State private var searchText = ""
    @State private var selectedFilter: ContentType?

    var filteredItems: [ContentItem] {
        var items = contentStore.items

        if let filter = selectedFilter {
            items = items.filter { $0.type == filter }
        }

        if !searchText.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedFilter == nil,
                            action: { selectedFilter = nil }
                        )

                        ForEach(ContentType.allCases, id: \.self) { type in
                            FilterChip(
                                title: type.rawValue,
                                icon: type.icon,
                                color: type.color,
                                isSelected: selectedFilter == type,
                                action: { selectedFilter = type }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))

                Divider()

                // Content list
                if filteredItems.isEmpty {
                    EmptyLibraryView()
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            ContentItemRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    audioPlayer.play(item, from: item.lastPlayedPosition)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            contentStore.deleteItem(item)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        withAnimation {
                                            contentStore.toggleFavorite(item)
                                        }
                                    } label: {
                                        Label("Favorite", systemImage: item.isFavorite ? "star.slash" : "star.fill")
                                    }
                                    .tint(.yellow)
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("AudioReader")
            .searchable(text: $searchText, prompt: "Search content")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddContent = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddContent) {
                AddContentView()
            }
        }
    }
}

// MARK: - Content Item Row

struct ContentItemRow: View {
    let item: ContentItem

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.type.color.opacity(0.15))
                    .frame(width: 60, height: 60)

                Image(systemName: item.type.icon)
                    .font(.title2)
                    .foregroundColor(item.type.color)
            }

            // Content info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(2)

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }

                Text(item.type.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(item.formattedDuration)
                        .font(.caption)

                    if item.lastPlayedPosition > 0 {
                        Spacer()
                        Text("\(Int(item.lastPlayedPosition / item.duration * 100))% played")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var icon: String?
    var color: Color = .blue
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Empty State

struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Content Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap the + button to add PDFs, web pages, text, or images")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LibraryView()
        .environmentObject(ContentStore())
        .environmentObject(AudioPlayerManager())
}
