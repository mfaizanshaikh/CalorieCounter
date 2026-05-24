import Foundation
import UIKit

// MARK: - OpenAI Responses API Models
struct OpenAIResponsesRequest: Encodable {
    let model: String
    let input: [OpenAIInputMessage]
    let maxOutputTokens: Int?
    let reasoning: OpenAIReasoningConfig?

    enum CodingKeys: String, CodingKey {
        case model, input, reasoning
        case maxOutputTokens = "max_output_tokens"
    }
}

struct OpenAIReasoningConfig: Encodable {
    let effort: String  // "low" | "medium" | "high" — only honored by reasoning models
}

struct OpenAIInputMessage: Encodable {
    let role: String
    let content: OpenAIInputContent

    static func system(_ text: String) -> OpenAIInputMessage {
        OpenAIInputMessage(role: "system", content: .text(text))
    }

    static func user(_ content: [OpenAIContentItem]) -> OpenAIInputMessage {
        OpenAIInputMessage(role: "user", content: .array(content))
    }
}

enum OpenAIInputContent: Encodable {
    case text(String)
    case array([OpenAIContentItem])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .array(let items):
            try container.encode(items)
        }
    }
}

struct OpenAIContentItem: Encodable {
    let type: String
    let text: String?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }

    static func text(_ text: String) -> OpenAIContentItem {
        OpenAIContentItem(type: "input_text", text: text, imageUrl: nil)
    }

    static func image(base64: String, mimeType: String = "image/jpeg") -> OpenAIContentItem {
        OpenAIContentItem(
            type: "input_image",
            text: nil,
            imageUrl: "data:\(mimeType);base64,\(base64)"
        )
    }
}

// MARK: - Response Models
struct OpenAIResponsesResponse: Decodable {
    let id: String?
    let output: [OpenAIOutputItem]
    let usage: OpenAIResponsesUsage?
    let error: OpenAIAPIErrorDetail?
}

struct OpenAIOutputItem: Decodable {
    let type: String?
    let id: String?
    let role: String?
    let content: [OpenAIOutputContent]?
    let text: String?
}

struct OpenAIOutputContent: Decodable {
    let type: String?
    let text: String?
}

struct OpenAIResponsesUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }
}

struct OpenAIAPIErrorResponse: Decodable {
    let error: OpenAIAPIErrorDetail
}

struct OpenAIAPIErrorDetail: Decodable {
    let message: String
    let type: String?
    let code: String?
}

// MARK: - OpenAI Service
actor OpenAIService {
    static let shared = OpenAIService()

    private let proxyBaseURL = "https://mfaizanshaikh.com/ai-calorie-coach/php-proxy/index.php"
    private let directBaseURL = "https://api.openai.com/v1/responses"
    private let model = "o3"
    private let fallbackModel = "gpt-4o-mini"  // Non-reasoning fallback if o3 returns unparseable JSON
    private let bundleID = Bundle.main.bundleIdentifier ?? "com.mfaizanshaikh.caloriecounter"

    /// Returns the user's own API key if configured, nil otherwise (uses proxy).
    private var userAPIKey: String? {
        let key = UserSettings.openAIAPIKey
        guard !key.isEmpty else { return nil }
        return key
    }

    private let systemPrompt = """
    You are a nutrition and health expert. Analyze the food image provided and estimate its nutritional content.

    IMPORTANT RULES:
    1. If the image does NOT contain food (e.g., shoes, electronics, people, animals, furniture, vehicles, etc.), respond with status "no_food_detected"
    2. If the image contains food, provide detailed nutritional estimates
    3. Consider visible portion sizes carefully
    4. Account for cooking methods (fried, grilled, steamed, etc.)
    5. If multiple food items are visible, list each separately
    6. ALL numeric fields MUST be actual numbers, NOT words (use 50, not "fifty")

    You MUST respond with valid JSON only, no other text. Use this exact structure:
    {
        "status": "food_detected" or "no_food_detected",
        "foods": [
            {
                "name": "Food name",
                "portionSize": "Estimated portion (e.g., '1 cup', '200g', '1 medium')",
                "caloriesMin": 100,
                "caloriesMax": 200,
                "caloriesAvg": 150,
                "protein": 10.5,
                "carbs": 25.0,
                "fat": 8.5,
                "fiber": 3.0,
                "sugar": 5.0,
                "saturatedFat": 2.5,
                "transFat": 0.0,
                "cholesterol": 45.0,
                "sodium": 300.0,
                "potassium": 200.0,
                "confidence": 0.85
            }
        ],
        "assumptions": ["List assumptions made about portions, ingredients, cooking methods"],
        "totalCaloriesMin": 100,
        "totalCaloriesMax": 200,
        "totalCaloriesAvg": 150
    }

    CRITICAL: All values for caloriesMin, caloriesMax, caloriesAvg, protein, carbs, fat, fiber, sugar, saturatedFat, transFat, cholesterol, sodium, potassium, confidence, totalCaloriesMin, totalCaloriesMax, and totalCaloriesAvg MUST be numeric values (integers or decimals), never words or text. Cholesterol, sodium, and potassium are in milligrams; all other nutrients are in grams.
    """

    private let userPrompt = """
    Analyze this food image and provide detailed nutritional estimates. Be as accurate as possible with portion sizes based on visual cues. If this is NOT food, set status to "no_food_detected".
    """

    private init() {}

    /// Always true — the proxy provides a key when the user has none.
    func hasAPIKey() -> Bool {
        return true
    }

    func analyzeFood(image: UIImage) async throws -> CalorieEstimation {
        guard let imageData = prepareImage(image),
              let base64String = imageData.base64EncodedString() as String? else {
            throw OpenAIServiceError.imageProcessingFailed
        }

        let input: [OpenAIInputMessage] = [
            .system(systemPrompt),
            .user([
                .text(userPrompt),
                .image(base64: base64String)
            ])
        ]

        // First attempt: o3 with low reasoning effort so the token budget
        // actually reaches the structured JSON output instead of being eaten
        // by reasoning tokens.
        let primaryRequest = OpenAIResponsesRequest(
            model: model,
            input: input,
            maxOutputTokens: 8192,
            reasoning: OpenAIReasoningConfig(effort: "low")
        )

        do {
            let response = try await makeRequest(primaryRequest)
            return try parseResponse(response)
        } catch let primaryError {
            // Only retry on parse / empty / image-text errors. Network and auth
            // failures should propagate as-is.
            guard shouldFallback(on: primaryError) else { throw primaryError }

#if DEBUG
            print("Primary model (\(model)) failed (\(primaryError.localizedDescription)) — retrying with \(fallbackModel)")
#endif

            let fallbackRequest = OpenAIResponsesRequest(
                model: fallbackModel,
                input: input,
                maxOutputTokens: 4096,
                reasoning: nil
            )

            let fallbackResponse = try await makeRequest(fallbackRequest)
            return try parseResponse(fallbackResponse)
        }
    }

    private func shouldFallback(on error: Error) -> Bool {
        guard let svcError = error as? OpenAIServiceError else { return false }
        switch svcError {
        case .emptyResponse, .parsingFailed:
            return true
        case .imageProcessingFailed, .invalidURL, .invalidResponse,
             .httpError, .apiError:
            return false
        }
    }

    private func prepareImage(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1024
        let originalSize = image.size

        let scale = min(
            maxDimension / originalSize.width,
            maxDimension / originalSize.height,
            1.0
        )

        let newSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        let targetSize = 500 * 1024
        let qualities: [CGFloat] = [0.7, 0.5, 0.4, 0.3, 0.2]

        for quality in qualities {
            if let data = resizedImage.jpegData(compressionQuality: quality) {
                if data.count <= targetSize || quality == qualities.last {
                    return data
                }
            }
        }

        return resizedImage.jpegData(compressionQuality: 0.2)
    }

    private func makeRequest(_ request: OpenAIResponsesRequest) async throws -> OpenAIResponsesResponse {
        let useDirectAPI = userAPIKey != nil
        let urlString = useDirectAPI ? directBaseURL : proxyBaseURL

        guard let url = URL(string: urlString) else {
            throw OpenAIServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120

        if let apiKey = userAPIKey {
            // User has their own key — call OpenAI directly
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else {
            // Use proxy — add identification headers (no API key sent)
            urlRequest.setValue(bundleID, forHTTPHeaderField: "X-Bundle-ID")
            let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            urlRequest.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        }

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(OpenAIAPIErrorResponse.self, from: data) {
                throw OpenAIServiceError.apiError(errorResponse.error.message)
            }
            throw OpenAIServiceError.httpError(httpResponse.statusCode)
        }

#if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("OpenAI API Raw Response: \(jsonString.prefix(500))...")
        }
#endif

        return try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
    }

    private func parseResponse(_ response: OpenAIResponsesResponse) throws -> CalorieEstimation {
        if let error = response.error {
            throw OpenAIServiceError.apiError(error.message)
        }

        var content: String?

        // First priority: message-type output (skip reasoning summaries)
        for output in response.output {
            guard output.type == "message" else { continue }
            if let contents = output.content {
                for c in contents {
                    if let text = c.text, !text.isEmpty {
                        content = text
                        break
                    }
                }
            }
            if content != nil { break }
        }

        // Fallback: any non-reasoning output
        if content == nil {
            for output in response.output {
                if output.type == "reasoning" { continue }
                if let contents = output.content {
                    for c in contents {
                        if let text = c.text, !text.isEmpty {
                            content = text
                            break
                        }
                    }
                }
                if content == nil, let text = output.text, !text.isEmpty {
                    content = text
                }
                if content != nil { break }
            }
        }

        guard let extractedContent = content, !extractedContent.isEmpty else {
#if DEBUG
            let outputTypes = response.output.map { $0.type ?? "nil" }.joined(separator: ", ")
            print("Failed to extract content. Output types: [\(outputTypes)]")
#endif
            throw OpenAIServiceError.emptyResponse
        }

#if DEBUG
        if let usage = response.usage {
            print("OpenAI API Usage — Input: \(usage.inputTokens), Output: \(usage.outputTokens), Total: \(usage.totalTokens)")
        }
#endif

        let jsonString = Self.extractJSON(from: extractedContent)

        guard let estimation = CalorieEstimation.parse(from: jsonString) else {
#if DEBUG
            print("Failed to parse OpenAI response: \(jsonString)")
#endif
            throw OpenAIServiceError.parsingFailed
        }

        return estimation
    }

    /// Pulls the JSON object out of a model response that may include code fences,
    /// preamble text ("Here's the analysis: { ... }"), or trailing commentary.
    /// Falls back progressively: strip fences → take first `{` to last `}` → return as-is.
    static func extractJSON(from raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if s.hasPrefix("```json") {
            s = String(s.dropFirst(7))
        } else if s.hasPrefix("```") {
            s = String(s.dropFirst(3))
        }
        if s.hasSuffix("```") {
            s = String(s.dropLast(3))
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        if let first = s.firstIndex(of: "{"), let last = s.lastIndex(of: "}"), first < last {
            return String(s[first...last])
        }

        return s
    }

    enum OpenAIServiceError: Error, LocalizedError {
        case imageProcessingFailed
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case apiError(String)
        case emptyResponse
        case parsingFailed

        var errorDescription: String? {
            switch self {
            case .imageProcessingFailed:
                return "Failed to process image for analysis"
            case .invalidURL:
                return "Invalid API URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let code):
                return "Server error (HTTP \(code))"
            case .apiError(let message):
                return "API error: \(message)"
            case .emptyResponse:
                return "Empty response from API"
            case .parsingFailed:
                return "Failed to parse nutritional data"
            }
        }
    }
}
