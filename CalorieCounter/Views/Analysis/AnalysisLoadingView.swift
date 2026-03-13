import SwiftUI

// MARK: - Analysis Steps

enum AnalysisStep: Int, CaseIterable {
    case uploading
    case detecting
    case estimatingPortions
    case calculatingCalories
    case preparingReport

    var label: String {
        switch self {
        case .uploading: return "Uploading image"
        case .detecting: return "Detecting food items"
        case .estimatingPortions: return "Estimating portion sizes"
        case .calculatingCalories: return "Calculating calories"
        case .preparingReport: return "Preparing nutrition report"
        }
    }
}

// MARK: - Scanning Overlay

struct ScanningOverlayView: View {
    @State private var scanOffset: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.12)

                GridPattern()
                    .stroke(Color.green.opacity(0.2), lineWidth: 0.5)

                // Glow region above scan line
                LinearGradient(
                    colors: [.green.opacity(0.1), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: max(0, (scanOffset + 1) / 2 * geo.size.height))
                .frame(maxHeight: .infinity, alignment: .top)

                // Scan line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0), .green.opacity(0.9), .green.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .shadow(color: .green.opacity(0.6), radius: 8)
                    .shadow(color: .green.opacity(0.3), radius: 24)
                    .offset(y: scanOffset * geo.size.height / 2)

                // Corner brackets
                CornerBrackets()
                    .stroke(Color.green.opacity(0.8), lineWidth: 2)
                    .padding(8)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.5)
                .repeatForever(autoreverses: true)
            ) {
                scanOffset = 1
            }
        }
    }
}

// MARK: - Grid Pattern

struct GridPattern: Shape {
    let spacing: CGFloat = 25

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }
        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }
        return path
    }
}

// MARK: - Corner Brackets

struct CornerBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let len: CGFloat = 20
        var path = Path()
        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        // Top-right
        path.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        return path
    }
}

// MARK: - Step Progress

struct AnalysisStepProgressView: View {
    @State private var currentStep = 0
    let timer = Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(AnalysisStep.allCases.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 12) {
                    Group {
                        if index < currentStep {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                        } else if index == currentStep {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.green)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.quaternary)
                        }
                    }
                    .frame(width: 20, height: 20)

                    Text(step.label)
                        .font(.subheadline)
                        .foregroundStyle(index <= currentStep ? .primary : .quaternary)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentStep)
            }
        }
        .onReceive(timer) { _ in
            if currentStep < AnalysisStep.allCases.count - 1 {
                currentStep += 1
            }
        }
    }
}

// MARK: - Health Tip Carousel

struct HealthTipCarouselView: View {
    private static let tips = [
        // Hydration
        "Drinking water before meals can reduce calorie intake by up to 13%",
        "Even mild dehydration can slow your metabolism by up to 3%",
        "Thirst is often mistaken for hunger — try water first",
        "Herbal teas count toward your daily water intake",
        "Adding lemon to water can aid digestion and boost vitamin C",

        // Protein
        "Protein keeps you feeling full longer than carbs or fats",
        "Your body burns more calories digesting protein than any other macronutrient",
        "Spreading protein intake across meals supports muscle repair all day",
        "Greek yogurt has nearly twice the protein of regular yogurt",
        "Eggs are one of the most complete protein sources available",
        "Lentils pack about 18g of protein per cooked cup",

        // Fiber
        "Fiber-rich foods help maintain steady blood sugar levels",
        "An apple provides about 4g of dietary fiber",
        "Most adults only get about half the recommended daily fiber",
        "Chia seeds expand in your stomach, helping you feel full longer",
        "Oats contain beta-glucan, a fiber that can lower cholesterol",
        "Black beans provide about 15g of fiber per cup",

        // Healthy Fats
        "Healthy fats help your body absorb vitamins A, D, E, and K",
        "Avocados contain more potassium than bananas",
        "Extra virgin olive oil is rich in heart-protective antioxidants",
        "Omega-3 fatty acids support brain health and reduce inflammation",
        "Walnuts are one of the best plant sources of omega-3 fats",
        "Coconut oil contains MCTs that your body can quickly use for energy",

        // Fruits & Vegetables
        "Blueberries are among the most antioxidant-rich fruits",
        "Orange vegetables are rich in beta-carotene for eye health",
        "Bananas are a great source of potassium for heart health",
        "Dark leafy greens are packed with iron and calcium",
        "Eating a variety of colorful vegetables ensures a broad range of nutrients",
        "Frozen fruits and vegetables retain most of their nutrients",
        "Tomatoes become more nutritious when cooked — it releases lycopene",
        "Broccoli contains almost as much vitamin C as an orange",
        "Sweet potatoes are loaded with vitamin A and fiber",
        "Spinach loses volume when cooked, making it easy to eat more nutrients",

        // Nuts & Seeds
        "A handful of almonds packs about 6g of protein",
        "Pumpkin seeds are one of the best natural sources of magnesium",
        "Brazil nuts are the richest dietary source of selenium",
        "Flaxseeds are high in omega-3s but must be ground to absorb them",

        // Eating Habits
        "Eating slowly gives your brain time to register fullness",
        "Smaller plates can trick your brain into feeling satisfied with less food",
        "Eating at consistent times helps regulate your metabolism",
        "Chewing food thoroughly improves nutrient absorption",
        "Mindful eating can help reduce overeating and improve digestion",
        "Eating breakfast can jumpstart your metabolism for the day",
        "Late-night snacking can disrupt sleep quality and digestion",

        // Metabolism & Energy
        "Spicy foods can temporarily boost your metabolic rate",
        "Green tea contains catechins that may help increase fat burning",
        "Getting enough sleep is crucial for maintaining a healthy metabolism",
        "Muscle burns more calories at rest than fat tissue",
        "Short walks after meals can improve blood sugar regulation",
        "Cold water may slightly boost calorie burn as your body warms it",

        // Micronutrients
        "Vitamin D from sunlight helps your body absorb calcium",
        "Iron absorption improves when paired with vitamin C-rich foods",
        "Magnesium supports over 300 biochemical reactions in your body",
        "Potassium helps regulate blood pressure and fluid balance",
        "Zinc plays a key role in immune function and wound healing",
        "B vitamins help convert food into usable energy",
    ]

    @State private var currentIndex = Int.random(in: 0..<tips.count)
    @State private var isVisible = true
    let timer = Timer.publish(every: 7.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 6) {
            Text("DID YOU KNOW?")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.green)
                .tracking(1)

            Text(Self.tips[currentIndex])
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(isVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.4), value: isVisible)
                .frame(minHeight: 34)
        }
        .padding(.horizontal, 8)
        .onReceive(timer) { _ in
            isVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                currentIndex = (currentIndex + 1) % Self.tips.count
                isVisible = true
            }
        }
    }
}
