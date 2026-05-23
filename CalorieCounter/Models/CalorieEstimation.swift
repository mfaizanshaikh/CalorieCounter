import Foundation

struct CalorieEstimation: Codable {
    let status: EstimationStatus
    let foods: [EstimatedFood]
    let assumptions: [String]
    let totalCaloriesMin: Int
    let totalCaloriesMax: Int
    let totalCaloriesAvg: Int

    enum EstimationStatus: String, Codable {
        case foodDetected = "food_detected"
        case noFoodDetected = "no_food_detected"

        init(from decoder: Decoder) throws {
            // Be lenient: the model occasionally returns variants like "detected",
            // "found", "no_food", uppercase, or wraps it in quotes. Map any
            // explicit "no food" signal to .noFoodDetected; default to
            // .foodDetected so the rest of the response (with actual food
            // entries) still flows through.
            let raw = (try? decoder.singleValueContainer().decode(String.self))?
                .lowercased()
                .trimmingCharacters(in: .whitespaces) ?? ""
            if raw.contains("no_food") || raw.contains("no food") || raw == "none" || raw == "empty" {
                self = .noFoodDetected
            } else {
                self = .foodDetected
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case status, foods, assumptions
        case totalCaloriesMin, totalCaloriesMax, totalCaloriesAvg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = (try? container.decode(EstimationStatus.self, forKey: .status)) ?? .foodDetected
        foods = (try? container.decode([EstimatedFood].self, forKey: .foods)) ?? []
        assumptions = (try? container.decode([String].self, forKey: .assumptions)) ?? []

        let minFromFoods = foods.reduce(0) { $0 + $1.caloriesMin }
        let maxFromFoods = foods.reduce(0) { $0 + $1.caloriesMax }
        let avgFromFoods = foods.reduce(0) { $0 + $1.caloriesAvg }

        totalCaloriesMin = LenientNumber.int(from: container, key: .totalCaloriesMin) ?? minFromFoods
        totalCaloriesMax = LenientNumber.int(from: container, key: .totalCaloriesMax) ?? maxFromFoods
        totalCaloriesAvg = LenientNumber.int(from: container, key: .totalCaloriesAvg) ?? avgFromFoods
    }

    init(
        status: EstimationStatus,
        foods: [EstimatedFood],
        assumptions: [String],
        totalCaloriesMin: Int,
        totalCaloriesMax: Int,
        totalCaloriesAvg: Int
    ) {
        self.status = status
        self.foods = foods
        self.assumptions = assumptions
        self.totalCaloriesMin = totalCaloriesMin
        self.totalCaloriesMax = totalCaloriesMax
        self.totalCaloriesAvg = totalCaloriesAvg
    }

    struct EstimatedFood: Codable {
        let name: String
        let portionSize: String
        let caloriesMin: Int
        let caloriesMax: Int
        let caloriesAvg: Int
        let confidence: Double

        // Additional nutritional info (optional, provided by OpenAI)
        let protein: Double?
        let carbs: Double?
        let fat: Double?
        let fiber: Double?
        let sugar: Double?
        let saturatedFat: Double?
        let transFat: Double?
        let cholesterol: Double?  // mg
        let sodium: Double?       // mg
        let potassium: Double?    // mg

        // Custom coding keys for flexibility
        enum CodingKeys: String, CodingKey {
            case name, portionSize
            case caloriesMin, caloriesMax, caloriesAvg
            case confidence
            case protein, carbs, fat, fiber
            case sugar, saturatedFat, transFat
            case cholesterol, sodium, potassium
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown food"
            portionSize = (try? container.decode(String.self, forKey: .portionSize)) ?? ""

            let rawMin = LenientNumber.int(from: container, key: .caloriesMin)
            let rawMax = LenientNumber.int(from: container, key: .caloriesMax)
            let rawAvg = LenientNumber.int(from: container, key: .caloriesAvg)

            // Backfill missing calorie fields from whichever sibling is present
            // so a partial response still produces a sensible row.
            let resolvedAvg = rawAvg ?? rawMin ?? rawMax ?? 0
            caloriesAvg = resolvedAvg
            caloriesMin = rawMin ?? resolvedAvg
            caloriesMax = rawMax ?? resolvedAvg

            confidence = LenientNumber.double(from: container, key: .confidence) ?? 0.7
            protein = LenientNumber.double(from: container, key: .protein)
            carbs = LenientNumber.double(from: container, key: .carbs)
            fat = LenientNumber.double(from: container, key: .fat)
            fiber = LenientNumber.double(from: container, key: .fiber)
            sugar = LenientNumber.double(from: container, key: .sugar)
            saturatedFat = LenientNumber.double(from: container, key: .saturatedFat)
            transFat = LenientNumber.double(from: container, key: .transFat)
            cholesterol = LenientNumber.double(from: container, key: .cholesterol)
            sodium = LenientNumber.double(from: container, key: .sodium)
            potassium = LenientNumber.double(from: container, key: .potassium)
        }

        init(name: String, portionSize: String, caloriesMin: Int, caloriesMax: Int, caloriesAvg: Int, confidence: Double, protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil, fiber: Double? = nil, sugar: Double? = nil, saturatedFat: Double? = nil, transFat: Double? = nil, cholesterol: Double? = nil, sodium: Double? = nil, potassium: Double? = nil) {
            self.name = name
            self.portionSize = portionSize
            self.caloriesMin = caloriesMin
            self.caloriesMax = caloriesMax
            self.caloriesAvg = caloriesAvg
            self.confidence = confidence
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
            self.fiber = fiber
            self.sugar = sugar
            self.saturatedFat = saturatedFat
            self.transFat = transFat
            self.cholesterol = cholesterol
            self.sodium = sodium
            self.potassium = potassium
        }
    }
}

extension CalorieEstimation {
    static var noFoodDetected: CalorieEstimation {
        CalorieEstimation(
            status: .noFoodDetected,
            foods: [],
            assumptions: [],
            totalCaloriesMin: 0,
            totalCaloriesMax: 0,
            totalCaloriesAvg: 0
        )
    }

    func toFoodItems() -> [FoodItem] {
        foods.map { food in
            FoodItem(
                name: food.name,
                caloriesMin: food.caloriesMin,
                caloriesMax: food.caloriesMax,
                caloriesAvg: food.caloriesAvg,
                portionSize: food.portionSize,
                confidence: food.confidence,
                protein: food.protein,
                carbs: food.carbs,
                fat: food.fat,
                fiber: food.fiber,
                sugar: food.sugar,
                saturatedFat: food.saturatedFat,
                transFat: food.transFat,
                cholesterol: food.cholesterol,
                sodium: food.sodium,
                potassium: food.potassium
            )
        }
    }

    // Computed properties for total macros
    var totalProtein: Double {
        foods.compactMap { $0.protein }.reduce(0, +)
    }

    var totalCarbs: Double {
        foods.compactMap { $0.carbs }.reduce(0, +)
    }

    var totalFat: Double {
        foods.compactMap { $0.fat }.reduce(0, +)
    }

    var totalFiber: Double {
        foods.compactMap { $0.fiber }.reduce(0, +)
    }

    var totalSugar: Double {
        foods.compactMap { $0.sugar }.reduce(0, +)
    }

    var totalSaturatedFat: Double {
        foods.compactMap { $0.saturatedFat }.reduce(0, +)
    }

    var totalTransFat: Double {
        foods.compactMap { $0.transFat }.reduce(0, +)
    }

    var totalCholesterol: Double {
        foods.compactMap { $0.cholesterol }.reduce(0, +)
    }

    var totalSodium: Double {
        foods.compactMap { $0.sodium }.reduce(0, +)
    }

    var totalPotassium: Double {
        foods.compactMap { $0.potassium }.reduce(0, +)
    }

    var hasMacroData: Bool {
        foods.contains { $0.protein != nil || $0.carbs != nil || $0.fat != nil }
    }
}

extension CalorieEstimation {
    static func parse(from jsonString: String) -> CalorieEstimation? {
        let decoder = JSONDecoder()
        let candidates = [
            sanitizeJson(jsonString),
            jsonString,
            sanitizeJson(repairTruncatedJson(jsonString)),
            repairTruncatedJson(jsonString)
        ]

        for (idx, candidate) in candidates.enumerated() {
            guard let data = candidate.data(using: .utf8) else { continue }
            do {
                return try decoder.decode(CalorieEstimation.self, from: data)
            } catch {
#if DEBUG
                if idx == candidates.count - 1 {
                    print("Failed to parse CalorieEstimation after all attempts: \(error)")
                }
#endif
                continue
            }
        }
        return nil
    }

    /// Attempts to repair JSON that was cut off mid-output (e.g. when the model
    /// hits its token cap). Strips a trailing partial token after the last comma,
    /// then appends matching `]` / `}` for unclosed arrays/objects so the
    /// decoder can at least recover the foods that did finish.
    private static func repairTruncatedJson(_ json: String) -> String {
        var s = json.trimmingCharacters(in: .whitespacesAndNewlines)

        if s.hasSuffix(",") { s.removeLast() }

        // Walk the string to compute unmatched `{` / `[`, ignoring chars inside
        // strings or escaped sequences. If we end mid-string, drop everything
        // back to the last structural boundary.
        var stack: [Character] = []
        var inString = false
        var escape = false
        var lastSafeIndex = s.startIndex

        for i in s.indices {
            let ch = s[i]
            if escape { escape = false; continue }
            if ch == "\\" { escape = true; continue }
            if ch == "\"" { inString.toggle(); continue }
            if inString { continue }

            switch ch {
            case "{", "[":
                stack.append(ch)
                lastSafeIndex = s.index(after: i)
            case "}":
                if stack.last == "{" { stack.removeLast() }
                lastSafeIndex = s.index(after: i)
            case "]":
                if stack.last == "[" { stack.removeLast() }
                lastSafeIndex = s.index(after: i)
            case ",", ":":
                lastSafeIndex = s.index(after: i)
            default:
                break
            }
        }

        if inString {
            // Truncate at the last safe structural boundary so we drop the
            // incomplete string literal entirely.
            s = String(s[..<lastSafeIndex])
            if s.hasSuffix(",") { s.removeLast() }
            // Recompute the stack on the truncated prefix.
            stack.removeAll()
            inString = false
            escape = false
            for ch in s {
                if escape { escape = false; continue }
                if ch == "\\" { escape = true; continue }
                if ch == "\"" { inString.toggle(); continue }
                if inString { continue }
                if ch == "{" || ch == "[" { stack.append(ch) }
                else if ch == "}" && stack.last == "{" { stack.removeLast() }
                else if ch == "]" && stack.last == "[" { stack.removeLast() }
            }
        }

        // Close any still-open structures (most-recent-open first).
        while let open = stack.popLast() {
            s.append(open == "{" ? "}" : "]")
        }

        return s
    }

    /// Sanitizes JSON response from AI model to fix common hallucinations
    /// like word numbers ("Fifty" instead of 50) or malformed values
    private static func sanitizeJson(_ json: String) -> String {
        var result = json

        // Dictionary of word numbers to their numeric values
        let wordNumbers: [String: String] = [
            "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
            "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
            "ten": "10", "eleven": "11", "twelve": "12", "thirteen": "13",
            "fourteen": "14", "fifteen": "15", "sixteen": "16", "seventeen": "17",
            "eighteen": "18", "nineteen": "19", "twenty": "20", "thirty": "30",
            "forty": "40", "fifty": "50", "sixty": "60", "seventy": "70",
            "eighty": "80", "ninety": "90", "hundred": "100"
        ]

        // Replace word numbers that appear as unquoted values after colons
        // Pattern: ": Word" or ":  Word" (with possible extra spaces)
        for (word, number) in wordNumbers {
            // Case insensitive replacement for unquoted word numbers
            // Matches ": Fifty," or ":  fifty," etc.
            let patterns = [
                ":\\s*\(word)\\s*,",      // : Fifty,
                ":\\s*\(word)\\s*}",      // : Fifty}
                ":\\s*\(word)\\s*\n",     // : Fifty\n
                ":\\s*\(word.capitalized)\\s*,",
                ":\\s*\(word.capitalized)\\s*}",
                ":\\s*\(word.capitalized)\\s*\n",
                ":\\s*\(word.uppercased())\\s*,",
                ":\\s*\(word.uppercased())\\s*}",
                ":\\s*\(word.uppercased())\\s*\n"
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(result.startIndex..., in: result)
                    // Determine the ending character from the pattern
                    let ending = pattern.last == "," ? "," : (pattern.last == "}" ? "}" : "\n")
                    result = regex.stringByReplacingMatches(
                        in: result,
                        options: [],
                        range: range,
                        withTemplate: ": \(number)\(ending)"
                    )
                }
            }
        }

        // Also handle combined numbers like "twenty-five" -> 25
        let combinedPatterns: [(String, String)] = [
            ("twenty[- ]?one", "21"), ("twenty[- ]?two", "22"), ("twenty[- ]?three", "23"),
            ("twenty[- ]?four", "24"), ("twenty[- ]?five", "25"), ("twenty[- ]?six", "26"),
            ("twenty[- ]?seven", "27"), ("twenty[- ]?eight", "28"), ("twenty[- ]?nine", "29"),
            ("thirty[- ]?one", "31"), ("thirty[- ]?two", "32"), ("thirty[- ]?three", "33"),
            ("thirty[- ]?four", "34"), ("thirty[- ]?five", "35"), ("thirty[- ]?six", "36"),
            ("thirty[- ]?seven", "37"), ("thirty[- ]?eight", "38"), ("thirty[- ]?nine", "39"),
            ("forty[- ]?one", "41"), ("forty[- ]?two", "42"), ("forty[- ]?three", "43"),
            ("forty[- ]?four", "44"), ("forty[- ]?five", "45"), ("forty[- ]?six", "46"),
            ("forty[- ]?seven", "47"), ("forty[- ]?eight", "48"), ("forty[- ]?nine", "49"),
            ("fifty[- ]?one", "51"), ("fifty[- ]?two", "52"), ("fifty[- ]?three", "53"),
            ("fifty[- ]?four", "54"), ("fifty[- ]?five", "55"), ("fifty[- ]?six", "56"),
            ("fifty[- ]?seven", "57"), ("fifty[- ]?eight", "58"), ("fifty[- ]?nine", "59"),
            ("sixty[- ]?one", "61"), ("sixty[- ]?two", "62"), ("sixty[- ]?three", "63"),
            ("sixty[- ]?four", "64"), ("sixty[- ]?five", "65"), ("sixty[- ]?six", "66"),
            ("sixty[- ]?seven", "67"), ("sixty[- ]?eight", "68"), ("sixty[- ]?nine", "69"),
            ("seventy[- ]?one", "71"), ("seventy[- ]?two", "72"), ("seventy[- ]?three", "73"),
            ("seventy[- ]?four", "74"), ("seventy[- ]?five", "75"), ("seventy[- ]?six", "76"),
            ("seventy[- ]?seven", "77"), ("seventy[- ]?eight", "78"), ("seventy[- ]?nine", "79"),
            ("eighty[- ]?one", "81"), ("eighty[- ]?two", "82"), ("eighty[- ]?three", "83"),
            ("eighty[- ]?four", "84"), ("eighty[- ]?five", "85"), ("eighty[- ]?six", "86"),
            ("eighty[- ]?seven", "87"), ("eighty[- ]?eight", "88"), ("eighty[- ]?nine", "89"),
            ("ninety[- ]?one", "91"), ("ninety[- ]?two", "92"), ("ninety[- ]?three", "93"),
            ("ninety[- ]?four", "94"), ("ninety[- ]?five", "95"), ("ninety[- ]?six", "96"),
            ("ninety[- ]?seven", "97"), ("ninety[- ]?eight", "98"), ("ninety[- ]?nine", "99")
        ]

        for (wordPattern, number) in combinedPatterns {
            let fullPattern = ":\\s*\(wordPattern)\\s*([,}\\n])"
            if let regex = try? NSRegularExpression(pattern: fullPattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: ": \(number)$1"
                )
            }
        }

        return result
    }
}

/// Decoders that accept numeric values encoded as Int, Double, *or* String
/// (e.g. `"caloriesAvg": "150"` or `"caloriesAvg": "150-200"`). Returns nil
/// for missing/null/unparseable fields so callers can supply a fallback.
enum LenientNumber {
    static func int<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        key: K
    ) -> Int? {
        if let v = try? container.decodeIfPresent(Int.self, forKey: key) { return v }
        if let v = try? container.decodeIfPresent(Double.self, forKey: key) { return Int(v.rounded()) }
        if let s = try? container.decodeIfPresent(String.self, forKey: key) { return parseInt(s) }
        return nil
    }

    static func double<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        key: K
    ) -> Double? {
        if let v = try? container.decodeIfPresent(Double.self, forKey: key) { return v }
        if let v = try? container.decodeIfPresent(Int.self, forKey: key) { return Double(v) }
        if let s = try? container.decodeIfPresent(String.self, forKey: key) { return parseDouble(s) }
        return nil
    }

    private static func parseInt(_ s: String) -> Int? {
        let cleaned = numericPrefix(of: s)
        if let i = Int(cleaned) { return i }
        if let d = Double(cleaned) { return Int(d.rounded()) }
        return nil
    }

    private static func parseDouble(_ s: String) -> Double? {
        Double(numericPrefix(of: s))
    }

    /// Pulls the leading numeric token out of strings like "150", "150 kcal",
    /// "150-200" (takes the lower bound), or "~150".
    private static func numericPrefix(of s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        var out = ""
        var seenDot = false
        for ch in trimmed {
            if ch.isNumber {
                out.append(ch)
            } else if ch == "." && !seenDot {
                out.append(ch)
                seenDot = true
            } else if (ch == "-" || ch == "+") && out.isEmpty {
                out.append(ch)
            } else {
                break
            }
        }
        return out
    }
}
