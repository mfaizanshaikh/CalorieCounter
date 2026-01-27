import Foundation
import SwiftData
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var todayCalories: (min: Int, max: Int, avg: Int) = (0, 0, 0)
    @Published var weeklyData: [(date: Date, calories: Int)] = []
    @Published var mealTypeAverages: [MealType: Int] = [:]
    @Published var todayMealCount: Int = 0
    @Published var weeklyAverage: Int = 0
    @Published var monthlyTotal: Int = 0

    private var settings = UserSettings.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Listen for goal changes
        settings.$dailyCalorieGoal
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var dailyGoal: Int {
        settings.dailyCalorieGoal
    }

    var showCalorieRange: Bool {
        settings.showCalorieRange
    }

    func updateStats(entries: [MealEntry]) {
        updateTodayStats(entries: entries)
        updateWeeklyData(entries: entries)
        updateMealTypeAverages(entries: entries)
        updateMonthlyTotal(entries: entries)
    }

    private func updateTodayStats(entries: [MealEntry]) {
        let todayEntries = entries.filter { $0.date.isToday }
        todayCalories = CalorieCalculator.dailyTotal(from: todayEntries)
        todayMealCount = todayEntries.count
    }

    private func updateWeeklyData(entries: [MealEntry]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var dailyTotals: [Date: Int] = [:]

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                dailyTotals[date] = 0
            }
        }

        let weekStart = today.daysAgo(6)
        let weekEntries = entries.filter { $0.date >= weekStart }

        for entry in weekEntries {
            let entryDay = calendar.startOfDay(for: entry.date)
            if dailyTotals[entryDay] != nil {
                dailyTotals[entryDay]! += entry.totalCaloriesAvg
            }
        }

        weeklyData = dailyTotals.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }

        let totalWeekCalories = weeklyData.reduce(0) { $0 + $1.calories }
        let daysWithData = weeklyData.filter { $0.calories > 0 }.count
        weeklyAverage = daysWithData > 0 ? totalWeekCalories / daysWithData : 0
    }

    private func updateMealTypeAverages(entries: [MealEntry]) {
        mealTypeAverages = CalorieCalculator.averagePerMealType(entries: entries)
    }

    private func updateMonthlyTotal(entries: [MealEntry]) {
        let monthStart = Date().startOfMonth
        let monthEntries = entries.filter { $0.date >= monthStart }
        monthlyTotal = monthEntries.reduce(0) { $0 + $1.totalCaloriesAvg }
    }

    var todayProgress: Double {
        let goal = Double(settings.dailyCalorieGoal)
        guard goal > 0 else { return 0 }
        return min(Double(todayCalories.avg) / goal, 1.0)
    }

    var todayProgressColor: String {
        let goal = settings.dailyCalorieGoal
        let current = todayCalories.avg
        let percentage = Double(current) / Double(goal)

        switch percentage {
        case 0..<0.75:
            return "green"
        case 0.75..<1.0:
            return "yellow"
        case 1.0..<1.25:
            return "orange"
        default:
            return "red"
        }
    }

    var formattedDailyGoal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: settings.dailyCalorieGoal)) ?? "\(settings.dailyCalorieGoal)"
    }
}
