import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \MealEntry.date, order: .reverse) private var entries: [MealEntry]
    @StateObject private var viewModel = HistoryViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyStateView
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
            .searchable(text: $viewModel.searchText, prompt: "Search foods")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Meals Logged")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your meal history will appear here after you log your first meal.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var historyList: some View {
        let filteredEntries = viewModel.filteredEntries(entries)
        let groupedEntries = viewModel.groupedByDate(filteredEntries)

        return List {
            ForEach(groupedEntries, id: \.date) { group in
                Section {
                    ForEach(group.entries) { entry in
                        NavigationLink {
                            MealDetailView(entry: entry)
                        } label: {
                            MealEntryRow(entry: entry)
                        }
                    }
                    .onDelete { indexSet in
                        deleteEntries(at: indexSet, from: group.entries)
                    }
                } header: {
                    Text(group.date.relativeDescription)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var filterMenu: some View {
        Menu {
            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(HistoryViewModel.HistoryFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    private func deleteEntries(at offsets: IndexSet, from entries: [MealEntry]) {
        for index in offsets {
            viewModel.deleteEntry(entries[index], from: modelContext)
        }
    }
}

struct MealEntryRow: View {
    let entry: MealEntry

    var body: some View {
        HStack(spacing: 12) {
            if let imageData = entry.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, height: 60)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: entry.mealType.icon)
                        .foregroundStyle(.green)

                    Text(entry.mealType.rawValue)
                        .font(.headline)
                }

                Text(foodSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(entry.date.shortTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.totalCaloriesAvg)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)

                Text("cal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var foodSummary: String {
        let names = entry.foodItems.prefix(3).map { $0.name }
        var summary = names.joined(separator: ", ")
        if entry.foodItems.count > 3 {
            summary += " +\(entry.foodItems.count - 3) more"
        }
        return summary
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: MealEntry.self, inMemory: true)
}
