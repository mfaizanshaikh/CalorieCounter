import SwiftUI
import SwiftData
import StoreKit

// MARK: - Main View

struct ManualFoodLogView: View {
    let entries: [MealEntry]

    @StateObject private var viewModel = ManualFoodLogViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var showingSaveSuccess = false
    @State private var quantitySheetFood: FoodSearchResult?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    mealTypePicker
                    searchBar

                    if !viewModel.searchResults.isEmpty || viewModel.searchQuery.count >= 2 {
                        searchResultsSection
                    }

                    if !viewModel.basket.isEmpty {
                        basketSection
                    }

                    historySection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .navigationTitle("Log Food Manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveButton
            }
            .sheet(item: $quantitySheetFood) { food in
                FoodQuantitySheet(food: food) { grams in
                    viewModel.addToBasket(food: food, grams: grams)
                    quantitySheetFood = nil
                    viewModel.clearSearch()
                    isSearchFocused = false
                }
            }
            .overlay {
                if showingSaveSuccess {
                    saveSuccessOverlay
                }
            }
            .task {
                viewModel.configure(with: modelContext)
            }
        }
    }

    // MARK: - Meal Type Picker

    private var mealTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meal Type")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Meal Type", selection: $viewModel.selectedMealType) {
                ForEach(MealType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search foods...", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFocused)

            if viewModel.isSearchingOnline {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Results")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !viewModel.searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.searchResults) { food in
                        FoodResultRow(food: food)
                            .contentShape(Rectangle())
                            .onTapGesture { quantitySheetFood = food }
                        if food.id != viewModel.searchResults.last?.id {
                            Divider().padding(.leading)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else if viewModel.searchQuery.count >= 2 {
                Text("No local results for \"\(viewModel.searchQuery)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }

            onlineSearchRow
        }
    }

    @ViewBuilder
    private var onlineSearchRow: some View {
        if viewModel.isSearchingOnline {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.75)
                Text("Searching online…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 6)
        } else if let err = viewModel.onlineSearchError {
            Text(err)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
        } else if !viewModel.hasSearchedOnline {
            Button {
                Task { await viewModel.searchOnline() }
            } label: {
                Label("Search Online with AI", systemImage: "sparkles")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.purple)
        } else {
            Text("Showing all online results")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Basket

    private var basketSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your Meal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.basketTotalCalories) cal")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            }

            VStack(spacing: 0) {
                ForEach(viewModel.basket) { item in
                    BasketItemRow(item: item) {
                        viewModel.removeFromBasket(id: item.id)
                    }
                    if item.id != viewModel.basket.last?.id {
                        Divider().padding(.leading)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("History", selection: $viewModel.bottomTab) {
                Text("Recent").tag(FoodHistoryTab.recent)
                Text("Frequent").tag(FoodHistoryTab.frequent)
            }
            .pickerStyle(.segmented)

            switch viewModel.bottomTab {
            case .recent:
                let recent = viewModel.recentFoods(from: entries)
                if recent.isEmpty {
                    emptyHistoryMessage("Log meals to see your recent foods here")
                } else {
                    VStack(spacing: 0) {
                        ForEach(recent) { item in
                            HistoryFoodRow(name: item.name, subtitle: item.portionLabel, calories: item.calories)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    quantitySheetFood = item.food
                                }
                            if item.id != recent.last?.id {
                                Divider().padding(.leading)
                            }
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

            case .frequent:
                let frequent = viewModel.frequentFoods(from: entries)
                if frequent.isEmpty {
                    emptyHistoryMessage("Log meals to see your frequent foods here")
                } else {
                    VStack(spacing: 0) {
                        ForEach(frequent) { item in
                            HistoryFoodRow(name: item.name, subtitle: "\(item.count)×", calories: item.calories)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    quantitySheetFood = item.food
                                }
                            if item.id != frequent.last?.id {
                                Divider().padding(.leading)
                            }
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func emptyHistoryMessage(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            let success = viewModel.saveMeal(to: modelContext)
            if success {
                if AppReviewManager.recordFoodLogAndCheckReview() {
                    requestReview()
                }
                showingSaveSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            }
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text(viewModel.basket.isEmpty ? "Add foods to save" : "Save Meal · \(viewModel.basketTotalCalories) cal")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .disabled(viewModel.basket.isEmpty)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Success Overlay

    private var saveSuccessOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Meal Saved!")
                .font(.title3.bold())
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.4), value: showingSaveSuccess)
    }
}

// MARK: - Food Result Row

struct FoodResultRow: View {
    let food: FoodSearchResult

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(food.name)
                        .font(.subheadline.weight(.medium))
                    if food.source == .ai {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                }
                Text("\(Int(food.caloriesPer100g)) cal / 100g · \(food.defaultServingLabel) ≈ \(food.calories(for: food.defaultServingSizeG)) cal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            MacroMiniStrip(food: food)

            Image(systemName: "plus.circle")
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Macro Mini Strip

private struct MacroMiniStrip: View {
    let food: FoodSearchResult

    var body: some View {
        HStack(spacing: 6) {
            if let p = food.proteinPer100g {
                macroChip("P", value: p, color: .blue)
            }
            if let c = food.carbsPer100g {
                macroChip("C", value: c, color: .orange)
            }
            if let f = food.fatPer100g {
                macroChip("F", value: f, color: .yellow)
            }
        }
    }

    private func macroChip(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(color)
            Text("\(Int(value))")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(width: 20)
    }
}

// MARK: - Basket Item Row

struct BasketItemRow: View {
    let item: BasketItem
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.food.name)
                    .font(.subheadline.weight(.medium))
                Text(item.portionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(item.calories) cal")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - History Food Row

struct HistoryFoodRow: View {
    let name: String
    let subtitle: String
    let calories: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(calories) cal")
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(systemName: "plus.circle")
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Food Quantity Sheet

struct FoodQuantitySheet: View {
    let food: FoodSearchResult
    let onAdd: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var gramsText: String
    @State private var servings: Double = 1.0
    @State private var isAdded = false
    @FocusState private var isGramsFocused: Bool

    init(food: FoodSearchResult, onAdd: @escaping (Double) -> Void) {
        self.food = food
        self.onAdd = onAdd
        _gramsText = State(initialValue: String(Int(food.defaultServingSizeG)))
    }

    private var grams: Double? {
        let cleaned = gramsText.trimmingCharacters(in: .whitespaces)
        return Double(cleaned).flatMap { $0 > 0 ? $0 : nil }
    }

    private var liveCalories: Int {
        guard let g = grams else { return 0 }
        return food.calories(for: g)
    }

    private var servingsLabel: String {
        let s = servings == servings.rounded(.down)
            ? String(Int(servings))
            : String(format: "%.1f", servings)
        return servings == 1 ? "1 serving" : "\(s) servings"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(food.name)
                            .font(.headline)
                        Spacer()
                        if food.source == .ai {
                            Label("AI", systemImage: "sparkles")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                    }
                } header: {
                    Text("Food")
                }

                Section {
                    Stepper(value: $servings, in: 0.5...20, step: 0.5) {
                        HStack {
                            Text(servingsLabel)
                            Spacer()
                            Text("\(Int((servings * food.defaultServingSizeG).rounded())) g")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: servings) { _, newValue in
                        gramsText = String(Int((newValue * food.defaultServingSizeG).rounded()))
                    }

                    HStack {
                        TextField("Custom grams", text: $gramsText)
                            .keyboardType(.decimalPad)
                            .focused($isGramsFocused)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }

                    Button("1 serving = \(food.defaultServingLabel) (\(Int(food.defaultServingSizeG)) g)") {
                        servings = 1.0
                        gramsText = String(Int(food.defaultServingSizeG))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Amount")
                }

                Section {
                    HStack {
                        Text("Calories")
                        Spacer()
                        Text("\(liveCalories) cal")
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }

                    macroRow("Protein", value: grams.flatMap { food.protein(for: $0) }, unit: "g", color: .blue)
                    macroRow("Carbs", value: grams.flatMap { food.carbs(for: $0) }, unit: "g", color: .orange)
                    macroRow("Fat", value: grams.flatMap { food.fat(for: $0) }, unit: "g", color: .yellow)
                    macroRow("Fiber", value: grams.flatMap { food.fiber(for: $0) }, unit: "g", color: .green)
                } header: {
                    Text("Nutrition")
                }
            }
            .navigationTitle("Add to Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isAdded)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guard let g = grams, !isAdded else { return }
                        isGramsFocused = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                            isAdded = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                            onAdd(g)
                        }
                    } label: {
                        ZStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .scaleEffect(isAdded ? 1 : 0.1)
                                .opacity(isAdded ? 1 : 0)

                            Text("Add")
                                .fontWeight(.semibold)
                                .scaleEffect(isAdded ? 0.1 : 1)
                                .opacity(isAdded ? 0 : 1)
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isAdded)
                    }
                    .disabled(grams == nil || isAdded)
                }
            }
            .onAppear { isGramsFocused = true }
        }
    }

    private func macroRow(_ label: String, value: Double?, unit: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 8, height: 8)
            Text(label)
            Spacer()
            if let v = value {
                Text(String(format: "%.1f \(unit)", v))
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ManualFoodLogView(entries: [])
        .modelContainer(for: MealEntry.self, inMemory: true)
}
