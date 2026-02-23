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

        // Custom coding keys for flexibility
        enum CodingKeys: String, CodingKey {
            case name, portionSize
            case caloriesMin, caloriesMax, caloriesAvg
            case confidence
            case protein, carbs, fat, fiber
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            portionSize = try container.decode(String.self, forKey: .portionSize)
            caloriesMin = try container.decode(Int.self, forKey: .caloriesMin)
            caloriesMax = try container.decode(Int.self, forKey: .caloriesMax)
            caloriesAvg = try container.decode(Int.self, forKey: .caloriesAvg)
            confidence = try container.decode(Double.self, forKey: .confidence)
            protein = try container.decodeIfPresent(Double.self, forKey: .protein)
            carbs = try container.decodeIfPresent(Double.self, forKey: .carbs)
            fat = try container.decodeIfPresent(Double.self, forKey: .fat)
            fiber = try container.decodeIfPresent(Double.self, forKey: .fiber)
        }

        init(name: String, portionSize: String, caloriesMin: Int, caloriesMax: Int, caloriesAvg: Int, confidence: Double, protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil, fiber: Double? = nil) {
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
                fiber: food.fiber
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

    var hasMacroData: Bool {
        foods.contains { $0.protein != nil || $0.carbs != nil || $0.fat != nil }
    }
}

extension CalorieEstimation {
    static func parse(from jsonString: String) -> CalorieEstimation? {
        // Sanitize the JSON to fix common model hallucinations
        let sanitizedJson = sanitizeJson(jsonString)

        guard let data = sanitizedJson.data(using: .utf8) else { return nil }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(CalorieEstimation.self, from: data)
        } catch {
#if DEBUG
            print("Failed to parse CalorieEstimation: \(error)")
#endif
            // Try with original string as fallback
            if let originalData = jsonString.data(using: .utf8) {
                return try? decoder.decode(CalorieEstimation.self, from: originalData)
            }
            return nil
        }
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
