import SwiftUI
import SwiftData

// Editable wrapper for food items
struct EditableFoodItem: Identifiable {
    let id = UUID()
    var name: String
    var portionSize: String
    var calories: Int  // User-editable calories (starts as avg)
    var originalMin: Int
    var originalMax: Int
    var originalAvg: Int
    var confidence: Double
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double?

    init(from food: CalorieEstimation.EstimatedFood) {
        self.name = food.name
        self.portionSize = food.portionSize
        self.calories = food.caloriesAvg
        self.originalMin = food.caloriesMin
        self.originalMax = food.caloriesMax
        self.originalAvg = food.caloriesAvg
        self.confidence = food.confidence
        self.protein = food.protein
        self.carbs = food.carbs
        self.fat = food.fat
        self.fiber = food.fiber
    }

    var hasBeenEdited: Bool {
        calories != originalAvg
    }
}

@MainActor
class AnalysisViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisResult: CalorieEstimation?
    @Published var errorMessage: String?
    @Published var suggestedMealType: MealType = .lunch
    @Published var selectedMealType: MealType = .lunch

    // Editable food items (readonly display)
    @Published var editableFoods: [EditableFoodItem] = []

    // User-edited total calories
    @Published var userEditedTotalCalories: Int = 0

    private let llavaService = LLaVAService.shared

    init() {
        updateSuggestedMealType()
    }

    func updateSuggestedMealType() {
        let (type, _) = MealClassifier.suggestedMealType()
        suggestedMealType = type
        selectedMealType = type
    }

    // Original total calories from analysis
    var originalTotalCalories: Int {
        editableFoods.reduce(0) { $0 + $1.originalAvg }
    }

    // The total calories to display/save (user-edited value)
    var totalEditedCalories: Int {
        userEditedTotalCalories
    }

    var hasEdits: Bool {
        userEditedTotalCalories != originalTotalCalories
    }

    // Slider range - allow adjustment from 50% to 200% of original
    var sliderMin: Double {
        max(0, Double(originalTotalCalories) * 0.5)
    }

    var sliderMax: Double {
        max(100, Double(originalTotalCalories) * 2.0)
    }

    func analyzeImage(_ image: UIImage) async {
        isAnalyzing = true
        errorMessage = nil
        analysisResult = nil
        editableFoods = []
        userEditedTotalCalories = 0

        do {
            let result = try await llavaService.analyzeImage(image)
            analysisResult = result
            // Initialize editable foods from result
            editableFoods = result.foods.map { EditableFoodItem(from: $0) }
            // Initialize user-edited total with the sum of individual calories
            userEditedTotalCalories = editableFoods.reduce(0) { $0 + $1.originalAvg }
        } catch {
            errorMessage = error.localizedDescription
#if DEBUG
            print("Analysis error: \(error)")
#endif
        }

        isAnalyzing = false
    }

    func resetAllToOriginal() {
        userEditedTotalCalories = originalTotalCalories
    }

    func saveMealEntry(
        image: UIImage?,
        to modelContext: ModelContext
    ) -> MealEntry? {
        guard let result = analysisResult,
              result.status == .foodDetected else {
            return nil
        }

        let imageData = image.flatMap { ImageProcessor.compressForStorage($0) }

        // Create food items from editable foods (with user's edited calories)
        let foodItems = editableFoods.map { editableFood in
            FoodItem(
                name: editableFood.name,
                caloriesMin: editableFood.hasBeenEdited ? editableFood.calories : editableFood.originalMin,
                caloriesMax: editableFood.hasBeenEdited ? editableFood.calories : editableFood.originalMax,
                caloriesAvg: editableFood.calories,
                portionSize: editableFood.portionSize,
                confidence: editableFood.confidence,
                protein: editableFood.protein,
                carbs: editableFood.carbs,
                fat: editableFood.fat,
                fiber: editableFood.fiber
            )
        }

        // Use edited total or original
        let totalCalories = totalEditedCalories

        let entry = MealEntry(
            date: Date(),
            mealType: selectedMealType,
            totalCaloriesMin: hasEdits ? totalCalories : result.totalCaloriesMin,
            totalCaloriesMax: hasEdits ? totalCalories : result.totalCaloriesMax,
            totalCaloriesAvg: totalCalories,
            imageData: imageData,
            foodItems: foodItems,
            assumptions: result.assumptions
        )

        modelContext.insert(entry)

        do {
            try modelContext.save()
            return entry
        } catch {
            errorMessage = "Failed to save meal: \(error.localizedDescription)"
#if DEBUG
            print("Save error: \(error)")
#endif
            return nil
        }
    }

    func reset() {
        isAnalyzing = false
        analysisResult = nil
        errorMessage = nil
        editableFoods = []
        userEditedTotalCalories = 0
        updateSuggestedMealType()
    }
}
