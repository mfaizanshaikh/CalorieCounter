import Foundation
import UIKit

// MARK: - OpenAI Responses API Models
struct OpenAIResponsesRequest: Encodable {
    let model: String
    let input: [OpenAIInputMessage]
    let maxOutputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model, input
        case maxOutputTokens = "max_output_tokens"
    }
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
    let text: String?  // Some responses have text directly on output item
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

    private let baseURL = "https://api.openai.com/v1/responses"
    private let model = "gpt-5-mini" // Latest cost-effective vision model

    private var apiKey: String? {
        let key = UserSettings.openAIAPIKey
        guard !key.isEmpty && key != "YOUR_OPENAI_API_KEY_HERE" else {
            return nil
        }
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
                "confidence": 0.85
            }
        ],
        "assumptions": ["List assumptions made about portions, ingredients, cooking methods"],
        "totalCaloriesMin": 100,
        "totalCaloriesMax": 200,
        "totalCaloriesAvg": 150
    }

    CRITICAL: All values for caloriesMin, caloriesMax, caloriesAvg, protein, carbs, fat, fiber, confidence, totalCaloriesMin, totalCaloriesMax, and totalCaloriesAvg MUST be numeric values (integers or decimals), never words or text.
    """

    private let userPrompt = """
    Analyze this food image and provide detailed nutritional estimates. Be as accurate as possible with portion sizes based on visual cues. If this is NOT food, set status to "no_food_detected".
    """

    private init() {}

    func hasAPIKey() -> Bool {
        return apiKey != nil
    }

    func analyzeFood(image: UIImage) async throws -> CalorieEstimation {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw OpenAIServiceError.missingAPIKey
        }

        // Resize and encode image
        guard let imageData = prepareImage(image),
              let base64String = imageData.base64EncodedString() as String? else {
            throw OpenAIServiceError.imageProcessingFailed
        }

        // Build request using Responses API format
        // Use higher token limit to allow for reasoning + response
        let request = OpenAIResponsesRequest(
            model: model,
            input: [
                .system(systemPrompt),
                .user([
                    .text(userPrompt),
                    .image(base64: base64String)
                ])
            ],
            maxOutputTokens: 16384
        )

        // Make API call
        let response = try await makeRequest(request, apiKey: apiKey)

        // Parse response
        return try parseResponse(response)
    }

    private func prepareImage(_ image: UIImage) -> Data? {
        // iPhone cameras can produce 12-48MP images (4-15MB+)
        // We need to resize and compress aggressively for API upload

        // Target max dimension - 1024px is good balance between detail and size
        let maxDimension: CGFloat = 1024
        let originalSize = image.size

        // Calculate scale factor
        let scale = min(
            maxDimension / originalSize.width,
            maxDimension / originalSize.height,
            1.0  // Don't upscale
        )

        let newSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        // Use UIGraphicsImageRenderer for better memory efficiency
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // Use 1x scale to avoid retina multiplication

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        // Target file size: under 500KB for fast upload
        let targetSize = 500 * 1024  // 500KB in bytes

        // Try progressively lower quality until we hit target size
        let qualities: [CGFloat] = [0.7, 0.5, 0.4, 0.3, 0.2]

        for quality in qualities {
            if let data = resizedImage.jpegData(compressionQuality: quality) {
                print("Image compressed: \(originalSize.width)x\(originalSize.height) -> \(newSize.width)x\(newSize.height), quality: \(quality), size: \(data.count / 1024)KB")

                if data.count <= targetSize || quality == qualities.last {
                    return data
                }
            }
        }

        // Fallback: return lowest quality
        return resizedImage.jpegData(compressionQuality: 0.2)
    }

    private func makeRequest(_ request: OpenAIResponsesRequest, apiKey: String) async throws -> OpenAIResponsesResponse {
        guard let url = URL(string: baseURL) else {
            throw OpenAIServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 120  // Longer timeout for reasoning models

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(OpenAIAPIErrorResponse.self, from: data) {
                throw OpenAIServiceError.apiError(errorResponse.error.message)
            }
            throw OpenAIServiceError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()

        // Debug: print raw response for troubleshooting
        if let jsonString = String(data: data, encoding: .utf8) {
            print("OpenAI API Raw Response: \(jsonString.prefix(500))...")
        }

        return try decoder.decode(OpenAIResponsesResponse.self, from: data)
    }

    private func parseResponse(_ response: OpenAIResponsesResponse) throws -> CalorieEstimation {
        // Check for API error in response
        if let error = response.error {
            throw OpenAIServiceError.apiError(error.message)
        }

        // Extract text content from the response output
        // GPT-5 models output "reasoning" first, then "message" with the actual content
        var content: String?

        // First priority: Look for "message" type output (skip "reasoning")
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

        // Fallback: Try any output with content
        if content == nil {
            for output in response.output {
                // Skip reasoning outputs
                if output.type == "reasoning" { continue }

                if let contents = output.content {
                    for c in contents {
                        if let text = c.text, !text.isEmpty {
                            content = text
                            break
                        }
                    }
                }

                // Check direct text field
                if content == nil, let text = output.text, !text.isEmpty {
                    content = text
                }

                if content != nil { break }
            }
        }

        guard let extractedContent = content, !extractedContent.isEmpty else {
            // Log output types for debugging
            let outputTypes = response.output.map { $0.type ?? "nil" }.joined(separator: ", ")
            print("Failed to extract content. Output types: [\(outputTypes)]")
            print("Full output: \(response.output)")
            throw OpenAIServiceError.emptyResponse
        }

        // Log token usage for cost tracking
        if let usage = response.usage {
            print("OpenAI API Usage - Input: \(usage.inputTokens), Output: \(usage.outputTokens), Total: \(usage.totalTokens)")
            let estimatedCost = Double(usage.totalTokens) * 0.00000010 // gpt-5-mini pricing estimate
            print("Estimated cost: $\(String(format: "%.4f", estimatedCost))")
        }

        // Clean up the response (remove markdown code blocks if present)
        var jsonString = extractedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse the JSON
        guard let estimation = CalorieEstimation.parse(from: jsonString) else {
            print("Failed to parse OpenAI response: \(jsonString)")
            throw OpenAIServiceError.parsingFailed
        }

        return estimation
    }

    enum OpenAIServiceError: Error, LocalizedError {
        case missingAPIKey
        case imageProcessingFailed
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case apiError(String)
        case emptyResponse
        case parsingFailed

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "OpenAI API key not configured. Please set your API key in UserSettings.swift"
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
