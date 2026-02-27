import Foundation

// MARK: - Local Food Entry (JSON model, used only for pre-filling)

struct LocalFoodEntry: Decodable {
    let name: String
    let caloriesPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let fiberPer100g: Double
    let sodiumPer100g: Double
    let servingSizeG: Double
    let servingLabel: String

    enum CodingKeys: String, CodingKey {
        case name
        case caloriesPer100g = "calories_per_100g"
        case proteinPer100g = "protein_per_100g"
        case carbsPer100g = "carbs_per_100g"
        case fatPer100g = "fat_per_100g"
        case fiberPer100g = "fiber_per_100g"
        case sodiumPer100g = "sodium_per_100g"
        case servingSizeG = "serving_size_g"
        case servingLabel = "serving_label"
    }
}

// MARK: - Search Result

struct FoodSearchResult: Identifiable, Sendable {
    let id: UUID
    let name: String
    let caloriesPer100g: Double
    let proteinPer100g: Double?
    let carbsPer100g: Double?
    let fatPer100g: Double?
    let fiberPer100g: Double?
    let sodiumPer100g: Double?
    let defaultServingSizeG: Double
    let defaultServingLabel: String
    let source: SearchSource

    init(from local: LocalFoodEntry) {
        self.id = UUID()
        self.name = local.name
        self.caloriesPer100g = local.caloriesPer100g
        self.proteinPer100g = local.proteinPer100g
        self.carbsPer100g = local.carbsPer100g
        self.fatPer100g = local.fatPer100g
        self.fiberPer100g = local.fiberPer100g
        self.sodiumPer100g = local.sodiumPer100g
        self.defaultServingSizeG = local.servingSizeG
        self.defaultServingLabel = local.servingLabel
        self.source = .local
    }

    init(id: UUID = UUID(), name: String, caloriesPer100g: Double,
         proteinPer100g: Double?, carbsPer100g: Double?, fatPer100g: Double?,
         fiberPer100g: Double?, sodiumPer100g: Double?,
         defaultServingSizeG: Double, defaultServingLabel: String,
         source: SearchSource) {
        self.id = id
        self.name = name
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.sodiumPer100g = sodiumPer100g
        self.defaultServingSizeG = defaultServingSizeG
        self.defaultServingLabel = defaultServingLabel
        self.source = source
    }

    func calories(for grams: Double) -> Int {
        Int((caloriesPer100g * grams / 100).rounded())
    }

    func protein(for grams: Double) -> Double? { proteinPer100g.map { $0 * grams / 100 } }
    func carbs(for grams: Double) -> Double?   { carbsPer100g.map  { $0 * grams / 100 } }
    func fat(for grams: Double) -> Double?     { fatPer100g.map    { $0 * grams / 100 } }
    func fiber(for grams: Double) -> Double?   { fiberPer100g.map  { $0 * grams / 100 } }
    func sodium(for grams: Double) -> Double?  { sodiumPer100g.map { $0 * grams / 100 } }
}

enum SearchSource: Sendable {
    case local
    case ai
}

// MARK: - AI Response Model (internal)

private struct AIFoodResponse: Decodable {
    let name: String
    // All numeric fields optional — a single null from the model won't fail the whole array
    let calories_per_100g: Double?
    let protein_per_100g: Double?
    let carbs_per_100g: Double?
    let fat_per_100g: Double?
    let fiber_per_100g: Double?
    let sodium_per_100g: Double?
    let serving_size_g: Double?
    let serving_label: String?
}

// MARK: - FoodSearchService (AI-only)

actor FoodSearchService {
    static let shared = FoodSearchService()
    private init() {}

    // MARK: - Bundled Food Loader (for pre-fill)

    static func loadBundledFoods() -> [LocalFoodEntry] {
        guard let url = Bundle.main.url(forResource: "FoodDatabase", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([LocalFoodEntry].self, from: data) else {
#if DEBUG
            print("FoodSearchService: Failed to load FoodDatabase.json")
#endif
            return []
        }
        return entries
    }

    // MARK: - AI Search

    /// Queries gpt-4o-mini for food nutrition data. Returns up to 7 results.
    /// Only called when the user explicitly taps "Search Online".
    func searchWithAI(query: String, excluding names: [String] = []) async throws -> [FoodSearchResult] {
        let apiKey = UserSettings.openAIAPIKey
        guard !apiKey.isEmpty else { throw FoodSearchError.noAPIKey }

        let excludeNote = names.isEmpty ? "" : " Do not include: \(names.prefix(10).joined(separator: ", "))."
        let userPrompt = """
        Return up to 7 foods matching "\(query)".\(excludeNote)
        Use these exact JSON keys: name, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fiber_per_100g, sodium_per_100g, serving_size_g, serving_label.
        All nutrient values must be numbers. serving_label is a string like "1 cup" or "100 g".
        """

        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw FoodSearchError.invalidURL
        }

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "input": [
                ["role": "system", "content": "You are a nutrition database API. Always respond with a raw JSON array only. No markdown, no code fences, no explanation — just the JSON array starting with [ and ending with ]."],
                ["role": "user", "content": userPrompt]
            ],
            "max_output_tokens": 1500
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 25
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
#if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                print("FoodSearchService AI: HTTP error — \(body.prefix(300))")
            }
#endif
            throw FoodSearchError.httpError
        }

        guard let rawText = extractText(from: data) else {
#if DEBUG
            print("FoodSearchService AI: could not extract text from response")
#endif
            throw FoodSearchError.emptyResponse
        }

        guard let arrayString = extractJSONArray(from: rawText) else {
#if DEBUG
            print("FoodSearchService AI: no JSON array found in — \(rawText.prefix(300))")
#endif
            throw FoodSearchError.parseFailed
        }

        guard let jsonData = arrayString.data(using: .utf8),
              let items = try? JSONDecoder().decode([AIFoodResponse].self, from: jsonData) else {
#if DEBUG
            print("FoodSearchService AI: decode failed for — \(arrayString.prefix(300))")
#endif
            throw FoodSearchError.parseFailed
        }

        return items.compactMap { item in
            // Skip entries with no calorie data
            guard let cal = item.calories_per_100g else { return nil }
            return FoodSearchResult(
                name: item.name,
                caloriesPer100g: cal,
                proteinPer100g: item.protein_per_100g,
                carbsPer100g: item.carbs_per_100g,
                fatPer100g: item.fat_per_100g,
                fiberPer100g: item.fiber_per_100g,
                sodiumPer100g: item.sodium_per_100g,
                defaultServingSizeG: item.serving_size_g ?? 100,
                defaultServingLabel: item.serving_label ?? "100 g",
                source: .ai
            )
        }
    }

    // MARK: - Private Helpers

    /// Pulls the assistant text out of a Responses API payload.
    private func extractText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [[String: Any]] else { return nil }
        // Prefer message-type output
        for item in output {
            if (item["type"] as? String) == "message",
               let contents = item["content"] as? [[String: Any]] {
                for c in contents {
                    if let text = c["text"] as? String, !text.isEmpty { return text }
                }
            }
        }
        // Fallback: any content with a text field
        for item in output {
            if let contents = item["content"] as? [[String: Any]] {
                for c in contents {
                    if let text = c["text"] as? String, !text.isEmpty { return text }
                }
            }
        }
        return nil
    }

    /// Finds the outermost `[…]` in a string, stripping code fences and surrounding prose.
    private func extractJSONArray(from text: String) -> String? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code fences (``` or ```json) including the trailing newline
        for fence in ["```json", "```"] {
            if s.hasPrefix(fence) {
                s = String(s.dropFirst(fence.count))
                if s.hasPrefix("\n") { s = String(s.dropFirst()) }
                break
            }
        }
        if s.hasSuffix("```") { s = String(s.dropLast(3)) }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract the outermost [ … ] so surrounding prose is ignored
        guard let start = s.firstIndex(of: "["),
              let end   = s.lastIndex(of: "]") else { return nil }
        return String(s[start...end])
    }

    // MARK: - Errors

    enum FoodSearchError: LocalizedError {
        case noAPIKey, invalidURL, httpError, emptyResponse, parseFailed

        var errorDescription: String? {
            switch self {
            case .noAPIKey:     return "Add an API key in Settings to search online."
            case .invalidURL:   return "Invalid URL."
            case .httpError:    return "Server error. Try again."
            case .emptyResponse: return "No response from AI."
            case .parseFailed:  return "Could not read AI response."
            }
        }
    }
}
