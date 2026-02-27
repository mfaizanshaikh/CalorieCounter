import Foundation
import Combine
import SwiftData

// MARK: - Supporting Types

struct BasketItem: Identifiable {
    let id = UUID()
    let food: FoodSearchResult
    let grams: Double
    let portionLabel: String
    var calories: Int
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double?
    var sodium: Double?
}

enum FoodHistoryTab {
    case recent, frequent
}

struct RecentFood: Identifiable {
    let id = UUID()
    let name: String
    let portionLabel: String
    let calories: Int
    let food: FoodSearchResult
}

struct FrequentFood: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let calories: Int
    let food: FoodSearchResult
}

// MARK: - ViewModel

@MainActor
class ManualFoodLogViewModel: ObservableObject {

    // MARK: Search state
    @Published var searchQuery = ""
    @Published var searchResults: [FoodSearchResult] = []
    @Published var isSearchingOnline = false
    @Published var onlineSearchError: String?
    @Published var hasSearchedOnline = false

    // MARK: Other state
    @Published var selectedMealType: MealType
    @Published var basket: [BasketItem] = []
    @Published var bottomTab: FoodHistoryTab = .recent

    // MARK: Dependencies
    /// Set from the View via .task { viewModel.configure(with: modelContext) }
    var modelContext: ModelContext?

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.selectedMealType = MealClassifier.classify()
        setupSearchDebounce()
    }

    // MARK: - Configuration (called from View after modelContext is available)

    func configure(with context: ModelContext) {
        guard modelContext == nil else { return }
        modelContext = context
        prefillIfNeeded(context: context)
    }

    // MARK: - Pre-fill from bundled JSON (runs once)

    private func prefillIfNeeded(context: ModelContext) {
        let key = "savedFoodPrefilled_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        Task.detached(priority: .background) {
            let entries = FoodSearchService.loadBundledFoods()
            await MainActor.run {
                for entry in entries {
                    context.insert(SavedFood(
                        name: entry.name,
                        caloriesPer100g: entry.caloriesPer100g,
                        proteinPer100g: entry.proteinPer100g,
                        carbsPer100g: entry.carbsPer100g,
                        fatPer100g: entry.fatPer100g,
                        fiberPer100g: entry.fiberPer100g,
                        sodiumPer100g: entry.sodiumPer100g,
                        defaultServingSizeG: entry.servingSizeG,
                        defaultServingLabel: entry.servingLabel,
                        isFromAI: false
                    ))
                }
                try? context.save()
                UserDefaults.standard.set(true, forKey: key)
#if DEBUG
                print("ManualFoodLogViewModel: pre-filled \(entries.count) foods")
#endif
            }
        }
    }

    // MARK: - Search Setup (debounced local search)

    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] query in
                guard let self else { return }
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count >= 2 {
                    self.runLocalSearch(query: trimmed)
                    self.hasSearchedOnline = false
                    self.onlineSearchError = nil
                } else {
                    self.searchResults = []
                    self.onlineSearchError = nil
                    self.hasSearchedOnline = false
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Local Search (SwiftData, synchronous on MainActor)

    private func runLocalSearch(query: String) {
        guard let context = modelContext else { return }
        let lower = query.lowercased()

        let descriptor = FetchDescriptor<SavedFood>()
        guard let all = try? context.fetch(descriptor) else { return }

        let filtered = all.filter { $0.name.lowercased().contains(lower) }
        let sorted = filtered.sorted {
            let aExact = $0.name.lowercased() == lower
            let bExact = $1.name.lowercased() == lower
            if aExact != bExact { return aExact }
            if $0.searchCount != $1.searchCount { return $0.searchCount > $1.searchCount }
            return $0.name < $1.name
        }

        searchResults = Array(sorted.prefix(15)).map { FoodSearchResult(from: $0) }
    }

    // MARK: - Online AI Search (explicit user action)

    func searchOnline() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2, !isSearchingOnline else { return }

        isSearchingOnline = true
        onlineSearchError = nil

        do {
            let existingNames = searchResults.map { $0.name.lowercased() }
            let aiResults = try await FoodSearchService.shared.searchWithAI(
                query: query,
                excluding: existingNames
            )

            // Dedup against what's already shown
            let existingSet = Set(existingNames)
            let newOnly = aiResults.filter { !existingSet.contains($0.name.lowercased()) }

            // Persist new foods to local DB
            if let context = modelContext {
                for result in newOnly {
                    saveToLocalDB(result, context: context)
                }
            }

            searchResults = searchResults + newOnly
            hasSearchedOnline = true
        } catch {
            onlineSearchError = error.localizedDescription
        }

        isSearchingOnline = false
    }

    // MARK: - Persist AI result to local DB

    private func saveToLocalDB(_ result: FoodSearchResult, context: ModelContext) {
        let name = result.name
        let descriptor = FetchDescriptor<SavedFood>(
            predicate: #Predicate { $0.name == name }
        )
        guard (try? context.fetchCount(descriptor)) == 0 else { return }

        context.insert(SavedFood(
            name: result.name,
            caloriesPer100g: result.caloriesPer100g,
            proteinPer100g: result.proteinPer100g,
            carbsPer100g: result.carbsPer100g,
            fatPer100g: result.fatPer100g,
            fiberPer100g: result.fiberPer100g,
            sodiumPer100g: result.sodiumPer100g,
            defaultServingSizeG: result.defaultServingSizeG,
            defaultServingLabel: result.defaultServingLabel,
            isFromAI: true
        ))
        try? context.save()
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        onlineSearchError = nil
        hasSearchedOnline = false
    }

    // MARK: - Basket

    func addToBasket(food: FoodSearchResult, grams: Double) {
        let item = BasketItem(
            food: food,
            grams: grams,
            portionLabel: "\(Int(grams)) g",
            calories: food.calories(for: grams),
            protein: food.protein(for: grams),
            carbs: food.carbs(for: grams),
            fat: food.fat(for: grams),
            fiber: food.fiber(for: grams),
            sodium: food.sodium(for: grams)
        )
        basket.append(item)
        incrementSearchCount(for: food)
    }

    func removeFromBasket(id: UUID) {
        basket.removeAll { $0.id == id }
    }

    var basketTotalCalories: Int {
        basket.reduce(0) { $0 + $1.calories }
    }

    // MARK: - Increment search count (so frequent foods bubble up)

    private func incrementSearchCount(for food: FoodSearchResult) {
        guard let context = modelContext else { return }
        let name = food.name
        let descriptor = FetchDescriptor<SavedFood>(predicate: #Predicate { $0.name == name })
        if let saved = try? context.fetch(descriptor).first {
            saved.searchCount += 1
            try? context.save()
        }
    }

    // MARK: - Recent & Frequent

    func recentFoods(from entries: [MealEntry]) -> [RecentFood] {
        var seen = Set<String>()
        var results: [RecentFood] = []

        for entry in entries {
            for item in entry.foodItems {
                let key = item.name.lowercased()
                if seen.contains(key) { continue }
                seen.insert(key)
                results.append(RecentFood(
                    name: item.name,
                    portionLabel: item.portionSize,
                    calories: item.caloriesAvg,
                    food: makeSyntheticResult(from: item)
                ))
                if results.count >= 20 { break }
            }
            if results.count >= 20 { break }
        }
        return results
    }

    func frequentFoods(from entries: [MealEntry]) -> [FrequentFood] {
        var counts: [String: (FoodItem, Int)] = [:]
        for entry in entries {
            for item in entry.foodItems {
                let key = item.name.lowercased()
                counts[key] = (item, (counts[key]?.1 ?? 0) + 1)
            }
        }
        return counts.values
            .sorted { $0.1 > $1.1 }
            .prefix(20)
            .map { item, count in
                FrequentFood(
                    name: item.name,
                    count: count,
                    calories: item.caloriesAvg,
                    food: makeSyntheticResult(from: item)
                )
            }
    }

    private func makeSyntheticResult(from item: FoodItem) -> FoodSearchResult {
        let grams = extractGrams(from: item.portionSize) ?? 100.0
        let div = grams == 0 ? 100.0 : grams
        return FoodSearchResult(
            name: item.name,
            caloriesPer100g: Double(item.caloriesAvg) * 100 / div,
            proteinPer100g: item.protein.map { $0 * 100 / div },
            carbsPer100g:   item.carbs.map   { $0 * 100 / div },
            fatPer100g:     item.fat.map     { $0 * 100 / div },
            fiberPer100g:   item.fiber.map   { $0 * 100 / div },
            sodiumPer100g:  item.sodium.map  { $0 * 100 / div },
            defaultServingSizeG: grams,
            defaultServingLabel: item.portionSize,
            source: .local
        )
    }

    private func extractGrams(from portionString: String) -> Double? {
        let s = portionString.lowercased()
        if s.contains("oz") {
            let d = s.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let oz = Double(d) { return oz * 28.3495 }
        }
        let d = s.components(separatedBy: CharacterSet.decimalDigits.union(.init(charactersIn: "."))).joined()
        return Double(d)
    }

    // MARK: - Save Meal

    @discardableResult
    func saveMeal(to modelContext: ModelContext) -> Bool {
        guard !basket.isEmpty else { return false }
        let total = basketTotalCalories
        let newItems = basket.map { item in
            FoodItem(
                name: item.food.name,
                caloriesMin: item.calories,
                caloriesMax: item.calories,
                caloriesAvg: item.calories,
                portionSize: item.portionLabel,
                confidence: 1.0,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                fiber: item.fiber,
                sodium: item.sodium
            )
        }

        // Append to an existing entry of the same type from today, if one exists.
        let mealType = selectedMealType
        let all = (try? modelContext.fetch(FetchDescriptor<MealEntry>())) ?? []
        if let existing = all.first(where: {
            Calendar.current.isDateInToday($0.date) && $0.mealType == mealType
        }) {
            existing.foodItems.append(contentsOf: newItems)
            existing.totalCaloriesMin += total
            existing.totalCaloriesMax += total
            existing.totalCaloriesAvg += total
        } else {
            let entry = MealEntry(
                mealType: mealType,
                totalCaloriesMin: total,
                totalCaloriesMax: total,
                totalCaloriesAvg: total,
                foodItems: newItems
            )
            modelContext.insert(entry)
        }

        do {
            try modelContext.save()
            return true
        } catch {
#if DEBUG
            print("ManualFoodLogViewModel: save failed: \(error)")
#endif
            return false
        }
    }
}
