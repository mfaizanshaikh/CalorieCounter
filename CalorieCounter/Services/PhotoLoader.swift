import Foundation
import SwiftUI
import SwiftData
import UIKit

/// Lazy downloader for meal photos pulled from the backend. Pulled meals
/// arrive with `photoRemoteId` but no bytes — views call `image(for:)` and
/// get back a UIImage once we've fetched (and cached) the JPEG. The bytes
/// are also persisted back into the SwiftData row so subsequent reads are
/// instant. `updatedAt` is deliberately *not* bumped — this is a local-only
/// hydration, not a user mutation, and should not echo back to the server.
@MainActor
final class PhotoLoader: ObservableObject {
    static let shared = PhotoLoader()

    private let cache = NSCache<NSString, UIImage>()
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 80
    }

    /// Drop all cached bytes and cancel in-flight downloads. Called on sign-out
    /// so the next account on this device doesn't see the previous user's photos
    /// served from the in-memory NSCache.
    func clear() {
        cache.removeAllObjects()
        for task in inflight.values { task.cancel() }
        inflight.removeAll()
    }

    /// Returns a UIImage for the meal if one is available — either from
    /// local `imageData`, the in-memory cache, or a freshly fetched download.
    /// Returns nil if the meal has no photo or the download fails.
    func image(for entry: MealEntry) async -> UIImage? {
        if let data = entry.imageData, let img = UIImage(data: data) {
            return img
        }
        guard let photoId = entry.photoRemoteId, !photoId.isEmpty else {
            return nil
        }
        let key = photoId as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        if let existing = inflight[photoId] {
            return await existing.value
        }

        let entryId = entry.id
        let context = entry.modelContext
        let task = Task<UIImage?, Never> { [weak self] in
            do {
                let data = try await APIClient.shared.getData("photos/\(photoId)")
                guard let image = UIImage(data: data) else { return nil }
                self?.cache.setObject(image, forKey: key)
                // Persist the bytes back so we don't refetch next time.
                // Look up the row freshly in case the original reference is stale.
                if let context {
                    let descriptor = FetchDescriptor<MealEntry>(
                        predicate: #Predicate { $0.id == entryId }
                    )
                    if let fresh = try? context.fetch(descriptor).first {
                        fresh.imageData = data
                        try? context.save()
                    }
                }
                return image
            } catch {
                #if DEBUG
                print("[PhotoLoader] failed to fetch \(photoId): \(error)")
                #endif
                return nil
            }
        }
        inflight[photoId] = task
        let result = await task.value
        inflight[photoId] = nil
        return result
    }
}

/// Renders a meal's photo, falling back to a system-icon placeholder while
/// the bytes are unavailable or downloading. Shared by HistoryView,
/// MealDetailView, and TodayDetailView so the lazy-load logic lives in one place.
struct MealPhotoView: View {
    let entry: MealEntry
    var size: CGFloat = 60
    var cornerRadius: CGFloat = 8
    var placeholderIcon: String = "photo"
    var placeholderBackground: Color = Color(.systemGray5)
    var placeholderForeground: Color = .secondary
    /// When true, treat the view as a detail hero: scale-to-fit, no fixed size.
    var hero: Bool = false

    @State private var image: UIImage?
    @State private var isLoading: Bool = false

    var body: some View {
        Group {
            if let image {
                if hero {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            } else if hero {
                // No placeholder for hero (matches old behavior — section hides).
                EmptyView()
            } else {
                ZStack {
                    Image(systemName: placeholderIcon)
                        .font(.title)
                        .foregroundStyle(placeholderForeground)
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .frame(width: size, height: size)
                .background(placeholderBackground)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
        .task(id: entry.id) {
            await load()
        }
    }

    private func load() async {
        if image != nil { return }
        // Fast path: local bytes.
        if let data = entry.imageData, let img = UIImage(data: data) {
            image = img
            return
        }
        // Only show spinner when we're actually about to hit the network.
        guard entry.photoRemoteId != nil else { return }
        isLoading = true
        let fetched = await PhotoLoader.shared.image(for: entry)
        isLoading = false
        image = fetched
    }
}
