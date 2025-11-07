//
//  ContentStore.swift
//  AudioReader
//
//  Manages the library of content items with persistence
//

import Foundation
import Combine

class ContentStore: ObservableObject {
    @Published var items: [ContentItem] = []

    private let saveKey = "SavedContentItems"

    init() {
        loadItems()
    }

    func addItem(_ item: ContentItem) {
        items.insert(item, at: 0) // Add to beginning for most recent first
        saveItems()
    }

    func deleteItem(_ item: ContentItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func updateItem(_ item: ContentItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveItems()
        }
    }

    func toggleFavorite(_ item: ContentItem) {
        var updatedItem = item
        updatedItem.isFavorite.toggle()
        updateItem(updatedItem)
    }

    func updatePlaybackPosition(for item: ContentItem, position: TimeInterval) {
        var updatedItem = item
        updatedItem.lastPlayedPosition = position
        updateItem(updatedItem)
    }

    // MARK: - Persistence

    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([ContentItem].self, from: data) {
            items = decoded
        }
    }

    // MARK: - Filtering

    func items(ofType type: ContentType) -> [ContentItem] {
        items.filter { $0.type == type }
    }

    var favoriteItems: [ContentItem] {
        items.filter { $0.isFavorite }
    }
}
