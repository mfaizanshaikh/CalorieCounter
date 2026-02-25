import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \MealEntry.date, order: .reverse) private var entries: [MealEntry]
    @StateObject private var viewModel = DashboardViewModel()
    @ScaledMetric private var caloriesFontSize: CGFloat = 56

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    NavigationLink(destination: TodayDetailView()) {
                        todayCard
                    }
                    .buttonStyle(.plain)

                    calorieTrendChart
                    mealDistributionCard
                    dailyAverageCard
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .onAppear {
                viewModel.updateStats(entries: entries)
            }
            .onChange(of: entries.count) { _, _ in
                viewModel.updateStats(entries: entries)
            }
        }
    }

    // MARK: - Today Card (always shows today regardless of filter)

    private var todayCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.todayMealCount) meals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text("\(viewModel.todayCalories.avg)")
                    .font(.system(size: caloriesFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .accessibilityLabel("\(viewModel.todayCalories.avg) calories consumed today")

                Text("calories consumed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.todayProgress)
                .tint(.green)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Goal")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(viewModel.formattedDailyGoal)")
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("Remaining")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(max(0, viewModel.dailyGoal - viewModel.todayCalories.avg))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(viewModel.todayCalories.avg >= viewModel.dailyGoal ? .red : .green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Progress")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(Int(viewModel.todayProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
            }

            if viewModel.showCalorieRange && viewModel.todayCalories.min > 0 {
                Text("\(viewModel.todayCalories.min) - \(viewModel.todayCalories.max) range")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Calorie Trend Chart (filtered)

    private var calorieTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Period", selection: $viewModel.selectedFilter) {
                    ForEach(DashboardFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .tint(.green)
                .font(.headline)
                .padding(.leading, -8)

                Spacer()

                Text(viewModel.chartAvgLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let nonZeroData = viewModel.chartData.filter { $0.calories > 0 }
            if nonZeroData.isEmpty && viewModel.selectedFilter != .today {
                Text("No data for this period")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                Chart(viewModel.chartData, id: \.date) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: viewModel.selectedFilter.chartUnit),
                        y: .value("Calories", item.calories)
                    )
                    .foregroundStyle(.green.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: viewModel.selectedFilter.axisDateFormat)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Meal Distribution (filtered)

    private var mealDistributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Average by Meal Type")
                .font(.headline)

            if viewModel.mealTypeAverages.isEmpty {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(MealType.allCases, id: \.self) { mealType in
                    if let avg = viewModel.mealTypeAverages[mealType], avg > 0 {
                        MealTypeRow(mealType: mealType, calories: avg)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Daily Average Card (filtered)

    private var dailyAverageCard: some View {
        StatCard(
            title: "Daily Average · \(viewModel.selectedFilter.rawValue)",
            value: "\(viewModel.periodAverage)",
            unit: "cal/day",
            icon: "chart.line.uptrend.xyaxis",
            color: .purple
        )
    }
}

struct MealTypeRow: View {
    let mealType: MealType
    let calories: Int

    private let maxCalories: CGFloat = 800

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: mealType.icon)
                .foregroundStyle(.green)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(mealType.rawValue)
                .font(.subheadline)

            Spacer()

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.green.opacity(0.2))

                    Capsule()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * min(CGFloat(calories) / maxCalories, 1.0))
                }
            }
            .frame(width: 100, height: 8)
            .accessibilityHidden(true)

            Text("\(calories)")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 50, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mealType.rawValue): \(calories) calories average")
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)

                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(unit)")
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: MealEntry.self, inMemory: true)
}
