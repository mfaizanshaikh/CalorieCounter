import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \MealEntry.date, order: .reverse) private var entries: [MealEntry]
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    NavigationLink(destination: TodayDetailView()) {
                        todayCard
                    }
                    .buttonStyle(.plain)

                    weeklyChart
                    mealDistributionCard
                    statsGrid
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
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)

                Text("calories consumed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.todayProgress)
                .tint(.green)

            HStack {
                Text("Goal: \(viewModel.formattedDailyGoal) cal")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(viewModel.todayProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
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

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.headline)

                Spacer()

                Text("Avg: \(viewModel.weeklyAverage) cal/day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(viewModel.weeklyData, id: \.date) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Calories", item.calories)
                )
                .foregroundStyle(.green.gradient)
                .cornerRadius(4)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

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

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "This Month",
                value: "\(viewModel.monthlyTotal)",
                unit: "cal total",
                icon: "calendar",
                color: .blue
            )

            StatCard(
                title: "Weekly Avg",
                value: "\(viewModel.weeklyAverage)",
                unit: "cal/day",
                icon: "chart.line.uptrend.xyaxis",
                color: .purple
            )
        }
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

            Text("\(calories)")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 50, alignment: .trailing)
        }
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
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: MealEntry.self, inMemory: true)
}
