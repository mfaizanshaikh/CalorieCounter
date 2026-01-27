import Foundation

struct CalorieCalculator {
    static func calculateTotals(from foods: [CalorieEstimation.EstimatedFood]) -> (min: Int, max: Int, avg: Int) {
        let totalMin = foods.reduce(0) { $0 + $1.caloriesMin }
        let totalMax = foods.reduce(0) { $0 + $1.caloriesMax }
        let totalAvg = foods.reduce(0) { $0 + $1.caloriesAvg }

        return (totalMin, totalMax, totalAvg)
    }

    static func dailyTotal(from entries: [MealEntry]) -> (min: Int, max: Int, avg: Int) {
        let totalMin = entries.reduce(0) { $0 + $1.totalCaloriesMin }
        let totalMax = entries.reduce(0) { $0 + $1.totalCaloriesMax }
        let totalAvg = entries.reduce(0) { $0 + $1.totalCaloriesAvg }

        return (totalMin, totalMax, totalAvg)
    }

    static func averagePerMealType(entries: [MealEntry]) -> [MealType: Int] {
        var mealTypeTotals: [MealType: (sum: Int, count: Int)] = [:]

        for entry in entries {
            let current = mealTypeTotals[entry.mealType] ?? (sum: 0, count: 0)
            mealTypeTotals[entry.mealType] = (current.sum + entry.totalCaloriesAvg, current.count + 1)
        }

        var averages: [MealType: Int] = [:]
        for (mealType, data) in mealTypeTotals {
            averages[mealType] = data.count > 0 ? data.sum / data.count : 0
        }

        return averages
    }

    static func weeklyTrend(entries: [MealEntry]) -> [(date: Date, calories: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var dailyTotals: [Date: Int] = [:]

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                dailyTotals[date] = 0
            }
        }

        for entry in entries {
            let entryDay = calendar.startOfDay(for: entry.date)
            if let _ = dailyTotals[entryDay] {
                dailyTotals[entryDay]! += entry.totalCaloriesAvg
            }
        }

        return dailyTotals.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
}
