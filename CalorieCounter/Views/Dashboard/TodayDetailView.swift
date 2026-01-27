import SwiftUI
import SwiftData

struct TodayDetailView: View {
    @Query(sort: \MealEntry.date, order: .reverse) private var allEntries: [MealEntry]
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.modelContext) private var modelContext

    private var todayEntries: [MealEntry] {
        allEntries.filter { $0.date.isToday }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard

                if todayEntries.isEmpty {
                    emptyState
                } else {
                    mealsSection
                }
            }
            .padding()
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.updateStats(entries: allEntries)
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("\(viewModel.todayCalories.avg)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)

                Text("calories consumed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.todayProgress)
                .tint(.green)
                .scaleEffect(y: 1.5)
                .padding(.horizontal)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.formattedDailyGoal) cal")
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Text("Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(viewModel.todayProgress * 100))%")
                        .font(.headline)
                        .foregroundStyle(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(max(0, viewModel.dailyGoal - viewModel.todayCalories.avg)) cal")
                        .font(.headline)
                        .foregroundStyle(viewModel.todayCalories.avg >= viewModel.dailyGoal ? .red : .primary)
                }
            }

            if viewModel.showCalorieRange && viewModel.todayCalories.min > 0 {
                Divider()
                HStack {
                    Text("Calorie Range")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.todayCalories.min) - \(viewModel.todayCalories.max)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No meals logged today")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Capture your first meal to start tracking!")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Meals")
                    .font(.headline)

                Spacer()

                Text("\(todayEntries.count) logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(todayEntries) { entry in
                NavigationLink(destination: MealDetailView(entry: entry)) {
                    TodayMealRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct TodayMealRow: View {
    let entry: MealEntry

    var body: some View {
        HStack(spacing: 12) {
            if let imageData = entry.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: entry.mealType.icon)
                    .font(.title2)
                    .foregroundStyle(.green)
                    .frame(width: 60, height: 60)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.mealType.rawValue)
                    .font(.headline)

                Text(entry.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(entry.foodItems.count) items")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.totalCaloriesAvg)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)

                Text("cal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        TodayDetailView()
    }
    .modelContainer(for: MealEntry.self, inMemory: true)
}
