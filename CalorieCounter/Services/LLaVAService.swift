import Foundation
import UIKit

enum LLaVAError: Error, LocalizedError {
    case modelNotLoaded
    case imageProcessingFailed
    case inferenceError(String)
    case parsingError
    case apiKeyMissing

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Analysis service is not ready"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .inferenceError(let message):
            return "Analysis error: \(message)"
        case .parsingError:
            return "Failed to parse analysis results"
        case .apiKeyMissing:
            return "OpenAI API key not configured. Please add your API key in Settings."
        }
    }
}

@MainActor
class LLaVAService: ObservableObject {
    static let shared = LLaVAService()

    @Published var isModelLoaded = false
    @Published var isProcessing = false
    @Published var loadingProgress: Double = 0
    @Published var loadingStatus: String = ""
    @Published var modelError: String?
    @Published var hasAPIKey = false

    private let openAIService = OpenAIService.shared

    private init() {
        Task {
            await checkAPIKey()
            try? await loadModel()
        }
    }

    func checkAPIKey() async {
        let hasKey = await openAIService.hasAPIKey()
        await MainActor.run {
            self.hasAPIKey = hasKey
        }
    }

    

    func loadModel() async throws {
        guard !isModelLoaded else { return }

        await MainActor.run {
            loadingProgress = 0.0
            loadingStatus = "Initializing..."
            modelError = nil
        }

        try await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            loadingProgress = 0.5
            loadingStatus = "Checking API configuration..."
        }

        await checkAPIKey()

        try await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            loadingProgress = 1.0
            if hasAPIKey {
                loadingStatus = "Ready (OpenAI GPT-5 Mini Vision)"
            } else {
                loadingStatus = "Ready (API key required for analysis)"
            }
            isModelLoaded = true
        }
    }

    func analyzeImage(_ image: UIImage) async throws -> CalorieEstimation {
        await MainActor.run {
            isProcessing = true
        }

        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }

        // Check for API key
        await checkAPIKey()

        guard hasAPIKey else {
            throw LLaVAError.apiKeyMissing
        }

        // Use OpenAI Vision API
        do {
            let result = try await openAIService.analyzeFood(image: image)
            return result
        } catch let error as OpenAIService.OpenAIServiceError {
            throw LLaVAError.inferenceError(error.localizedDescription)
        } catch {
            throw LLaVAError.inferenceError(error.localizedDescription)
        }
    }
}
