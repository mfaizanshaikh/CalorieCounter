import Foundation
import UIKit

enum LLaVAError: Error, LocalizedError {
    case modelNotLoaded
    case imageProcessingFailed
    case inferenceError(String)
    case parsingError

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
        hasAPIKey = true
        Task {
            try? await loadModel()
        }
    }

    func checkAPIKey() async {
        // Always true — proxy provides a key when the user has none
        await MainActor.run {
            self.hasAPIKey = true
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
            loadingStatus = "Connecting..."
        }

        try await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            loadingProgress = 1.0
            loadingStatus = "Ready (OpenAI Vision)"
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
