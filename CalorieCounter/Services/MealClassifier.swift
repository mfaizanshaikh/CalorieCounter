import Foundation

struct MealClassifier {
    static func classify(for date: Date = Date()) -> MealType {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 5...10:
            return .breakfast
        case 11...15:
            return .lunch
        case 16...21:
            return .dinner
        default:
            return .snack  // 22–4 (late night counts as snack; lateSnack kept for legacy data)
        }
    }

    static func suggestedMealType(for date: Date = Date()) -> (type: MealType, description: String) {
        let mealType = classify(for: date)
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let timeString = formatter.string(from: date)
        let description = "Based on the time (\(timeString)), this appears to be \(mealType.rawValue.lowercased())."

        return (mealType, description)
    }
}
