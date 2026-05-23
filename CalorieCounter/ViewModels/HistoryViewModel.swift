import Foundation
import SwiftData

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var selectedFilter: HistoryFilter = .all
    @Published var searchText: String = ""

    enum HistoryFilter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
    }

    func filteredEntries(_ entries: [MealEntry]) -> [MealEntry] {
        var filtered = entries

        switch selectedFilter {
        case .all:
            break
        case .today:
            filtered = filtered.filter { $0.date.isToday }
        case .thisWeek:
            filtered = filtered.filter { $0.date.isThisWeek }
        case .thisMonth:
            filtered = filtered.filter { $0.date.isThisMonth }
        }

        if !searchText.isEmpty {
            filtered = filtered.filter { entry in
                entry.foodItems.contains { food in
                    food.name.localizedCaseInsensitiveContains(searchText)
                }
            }
        }

        return filtered.sorted { $0.date > $1.date }
    }

    func groupedByDate(_ entries: [MealEntry]) -> [(date: Date, entries: [MealEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        return grouped.sorted { $0.key > $1.key }.map { ($0.key, $0.value.sorted { $0.date > $1.date }) }
    }

    func deleteEntry(_ entry: MealEntry, from modelContext: ModelContext) {
        SyncStore.delete(meal: entry, in: modelContext)
    }
}
