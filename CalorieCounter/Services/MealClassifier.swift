import Foundation

struct MealClassifier {
    static func classify(for date: Date = Date()) -> MealType {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 5...11:
            return .breakfast
        case 12...16:
            return .lunch
        case 17...23:
            return .dinner
        default:
            return .lateSnack
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
