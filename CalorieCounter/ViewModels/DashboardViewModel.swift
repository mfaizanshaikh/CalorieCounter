import Foundation
import SwiftData
import Combine

enum DashboardFilter: String, CaseIterable {
    case today = "Today"
    case week = "1 Week"
    case month = "1 Month"
    case twoMonths = "2 Months"
    case threeMonths = "3 Months"
    case sixMonths = "6 Months"
    case year = "1 Year"
    case all = "All"

    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .today:        return calendar.startOfDay(for: now)
        case .week:         return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))
        case .month:        return calendar.date(byAdding: .month, value: -1, to: now)
        case .twoMonths:    return calendar.date(byAdding: .month, value: -2, to: now)
        case .threeMonths:  return calendar.date(byAdding: .month, value: -3, to: now)
        case .sixMonths:    return calendar.date(byAdding: .month, value: -6, to: now)
        case .year:         return calendar.date(byAdding: .year, value: -1, to: now)
        case .all:          return nil
        }
    }

    // Calendar component used for BarMark unit and data grouping
    var chartUnit: Calendar.Component {
        switch self {
        case .today:                            return .hour
        case .week, .month:                     return .day
        case .twoMonths, .threeMonths:          return .weekOfYear
        case .sixMonths, .year, .all:           return .month
        }
    }

    var axisDateFormat: Date.FormatStyle {
        switch self {
        case .today:                    return .dateTime.hour()
        case .week:                     return .dateTime.weekday(.abbreviated)
        case .month:                    return .dateTime.day()
        case .twoMonths, .threeMonths:  return .dateTime.month(.abbreviated).day()
        case .sixMonths, .year, .all:   return .dateTime.month(.abbreviated)
        }
    }

    var chartTitle: String {
        switch self {
        case .today:        return "Today"
        case .week:         return "Last 7 Days"
        case .month:        return "Last Month"
        case .twoMonths:    return "Last 2 Months"
        case .threeMonths:  return "Last 3 Months"
        case .sixMonths:    return "Last 6 Months"
        case .year:         return "Last Year"
        case .all:          return "All Time"
        }
    }
}

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var todayCalories: (min: Int, max: Int, avg: Int) = (0, 0, 0)
    @Published var chartData: [(date: Date, calories: Int)] = []
    @Published var mealTypeAverages: [MealType: Int] = [:]
    @Published var todayMealCount: Int = 0
    @Published var periodAverage: Int = 0
    @Published var periodTotal: Int = 0
    @Published var selectedFilter: DashboardFilter = .week {
        didSet { recomputeStats() }
    }

    private var allEntries: [MealEntry] = []
    private var settings = UserSettings.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        settings.$dailyCalorieGoal
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var dailyGoal: Int { settings.dailyCalorieGoal }
    var showCalorieRange: Bool { settings.showCalorieRange }

    var chartAvgLabel: String {
        selectedFilter == .today
            ? "Total: \(periodTotal) cal"
            : "Avg: \(periodAverage) cal/day"
    }

    func updateStats(entries: [MealEntry]) {
        allEntries = entries
        recomputeStats()
    }

    private func recomputeStats() {
        let filtered = filteredEntries()
        updateTodayStats(entries: allEntries)
        updateChartData(entries: filtered)
        updateMealTypeAverages(entries: allEntries)
        updatePeriodStats(entries: filtered)
    }

    private func filteredEntries() -> [MealEntry] {
        guard let start = selectedFilter.startDate else { return allEntries }
        return allEntries.filter { $0.date >= start }
    }

    private func updateTodayStats(entries: [MealEntry]) {
        let todayEntries = entries.filter { $0.date.isToday }
        todayCalories = CalorieCalculator.dailyTotal(from: todayEntries)
        todayMealCount = todayEntries.count
    }

    private func updateChartData(entries: [MealEntry]) {
        let calendar = Calendar.current
        let now = Date()

        switch selectedFilter {
        case .today:
            let startOfToday = calendar.startOfDay(for: now)
            var hourlyTotals: [Date: Int] = [:]
            for hour in 0..<24 {
                if let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfToday) {
                    hourlyTotals[hourDate] = 0
                }
            }
            for entry in entries {
                if let hourStart = calendar.dateInterval(of: .hour, for: entry.date)?.start {
                    hourlyTotals[hourStart, default: 0] += entry.totalCaloriesAvg
                }
            }
            chartData = hourlyTotals.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }

        case .week:
            let today = calendar.startOfDay(for: now)
            var dailyTotals: [Date: Int] = [:]
            for i in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                    dailyTotals[date] = 0
                }
            }
            for entry in entries {
                let day = calendar.startOfDay(for: entry.date)
                if dailyTotals[day] != nil {
                    dailyTotals[day]! += entry.totalCaloriesAvg
                }
            }
            chartData = dailyTotals.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }

        case .month:
            chartData = groupByDay(entries: entries)

        case .twoMonths, .threeMonths:
            chartData = groupByWeek(entries: entries)

        case .sixMonths, .year, .all:
            chartData = groupByMonth(entries: entries)
        }
    }

    private func groupByDay(entries: [MealEntry]) -> [(date: Date, calories: Int)] {
        let calendar = Calendar.current
        var totals: [Date: Int] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            totals[day, default: 0] += entry.totalCaloriesAvg
        }
        return totals.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private func groupByWeek(entries: [MealEntry]) -> [(date: Date, calories: Int)] {
        let calendar = Calendar.current
        var totals: [Date: Int] = [:]
        for entry in entries {
            if let weekStart = calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start {
                totals[weekStart, default: 0] += entry.totalCaloriesAvg
            }
        }
        return totals.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private func groupByMonth(entries: [MealEntry]) -> [(date: Date, calories: Int)] {
        let calendar = Calendar.current
        var totals: [Date: Int] = [:]
        for entry in entries {
            if let monthStart = calendar.dateInterval(of: .month, for: entry.date)?.start {
                totals[monthStart, default: 0] += entry.totalCaloriesAvg
            }
        }
        return totals.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private func updateMealTypeAverages(entries: [MealEntry]) {
        mealTypeAverages = CalorieCalculator.averagePerMealType(entries: entries)
    }

    private func updatePeriodStats(entries: [MealEntry]) {
        periodTotal = entries.reduce(0) { $0 + $1.totalCaloriesAvg }
        let calendar = Calendar.current
        let uniqueDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        periodAverage = uniqueDays.isEmpty ? 0 : periodTotal / uniqueDays.count
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
        case 0..<0.75: return "green"
        case 0.75..<1.0: return "yellow"
        case 1.0..<1.25: return "orange"
        default: return "red"
        }
    }

    var formattedDailyGoal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: settings.dailyCalorieGoal)) ?? "\(settings.dailyCalorieGoal)"
    }
}
