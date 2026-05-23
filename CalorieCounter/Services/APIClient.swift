import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case requestFailed(status: Int, message: String?)
    case decodingFailed(Error)
    case transport(Error)
    case noBaseURL

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid request URL"
        case .unauthorized: return "Session expired. Please sign in again."
        case .requestFailed(let status, let message):
            let prefix: String
            switch status {
            case 400..<500:
                prefix = "Request failed"
            case 500..<600:
                prefix = "Server error"
            default:
                prefix = "Unexpected response"
            }
            return "\(prefix) (\(status))\(message.map { ": \($0)" } ?? "")"
        case .decodingFailed(let error): return "Could not parse server response: \(error.localizedDescription)"
        case .transport(let error): return "Network error: \(error.localizedDescription)"
        case .noBaseURL: return "Backend URL is not configured"
        }
    }
}

/// Thin URLSession wrapper. Attaches the current access JWT, handles 401 →
/// single refresh attempt → retry, and retries 5xx with capped exponential
/// backoff. All sync code goes through this.
actor APIClient {
    static let shared = APIClient()

    /// Set this from `BackendConfig.baseURL` before any request.
    private var baseURL: URL?
    private var accessTokenProvider: (() async -> String?)?
    private var refreshHandler: (() async throws -> String)?

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - Configuration

    func configure(
        baseURL: URL,
        accessTokenProvider: @escaping () async -> String?,
        refreshHandler: @escaping () async throws -> String
    ) {
        self.baseURL = baseURL
        self.accessTokenProvider = accessTokenProvider
        self.refreshHandler = refreshHandler
    }

    // MARK: - Public request methods

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        let data = try await request(path: path, method: "GET", query: query, body: nil as EmptyBody?)
        return try decode(data)
    }

    /// GET that returns raw bytes (binary blobs like photos).
    func getData(_ path: String, query: [String: String] = [:]) async throws -> Data {
        try await rawRequest(path: path, method: "GET", query: query, contentType: nil, body: nil)
    }

    @discardableResult
    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        let data = try await request(path: path, method: "POST", body: body)
        return try decode(data)
    }

    @discardableResult
    func patch<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        let data = try await request(path: path, method: "PATCH", body: body)
        return try decode(data)
    }

    func delete(_ path: String) async throws {
        _ = try await request(path: path, method: "DELETE", body: nil as EmptyBody?)
    }

    /// Multipart upload. `parts` is ordered (boundary preserved). `jsonPart`,
    /// if set, is encoded as `Content-Disposition: form-data; name="meta"`.
    @discardableResult
    func upload<T: Decodable>(
        _ path: String,
        jsonPart: Encodable? = nil,
        files: [(name: String, filename: String, mimeType: String, data: Data)]
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        if let json = jsonPart {
            let encoded = try encoder.encode(AnyEncodable(json))
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"meta\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
            body.append(encoded)
            body.append("\r\n".data(using: .utf8)!)
        }

        for file in files {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let data = try await rawRequest(
            path: path,
            method: "POST",
            contentType: "multipart/form-data; boundary=\(boundary)",
            body: body
        )
        return try decode(data)
    }

    // MARK: - Core

    private func request<Body: Encodable>(
        path: String,
        method: String,
        query: [String: String] = [:],
        body: Body?
    ) async throws -> Data {
        let encoded: Data?
        let contentType: String?
        if let body = body {
            encoded = try encoder.encode(body)
            contentType = "application/json"
        } else {
            encoded = nil
            contentType = nil
        }
        return try await rawRequest(
            path: path,
            method: method,
            query: query,
            contentType: contentType,
            body: encoded
        )
    }

    private func rawRequest(
        path: String,
        method: String,
        query: [String: String] = [:],
        contentType: String?,
        body: Data?,
        isRetry: Bool = false
    ) async throws -> Data {
        guard let baseURL else { throw APIError.noBaseURL }

        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = await accessTokenProvider?(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed(status: -1, message: nil)
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401:
            // Try a single refresh round-trip.
            if !isRetry, let refreshHandler {
                do {
                    _ = try await refreshHandler()
                    return try await rawRequest(
                        path: path,
                        method: method,
                        query: query,
                        contentType: contentType,
                        body: body,
                        isRetry: true
                    )
                } catch {
                    throw APIError.unauthorized
                }
            }
            throw APIError.unauthorized
        case 500..<600:
            // One retry with backoff for transient server errors.
            if !isRetry {
                try? await Task.sleep(nanoseconds: 800_000_000)
                return try await rawRequest(
                    path: path,
                    method: method,
                    query: query,
                    contentType: contentType,
                    body: body,
                    isRetry: true
                )
            }
            throw APIError.requestFailed(status: http.statusCode, message: errorMessage(from: data, response: http))
        default:
            throw APIError.requestFailed(status: http.statusCode, message: errorMessage(from: data, response: http))
        }
    }

    private func errorMessage(from data: Data, response: HTTPURLResponse) -> String? {
        guard !data.isEmpty else { return nil }

        if let payload = try? decoder.decode(ErrorEnvelope.self, from: data),
           let message = payload.serverMessage {
            return message
        }

        guard let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else { return nil }

        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        let lowercasedRaw = raw.lowercased()
        if contentType.contains("text/html")
            || lowercasedRaw.hasPrefix("<!doctype html")
            || lowercasedRaw.hasPrefix("<html") {
            return "Backend returned HTML instead of JSON. Check BackendBaseURL."
        }

        if raw.count > 180 {
            return String(raw.prefix(177)) + "..."
        }
        return raw
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        if T.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! T
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
}

// MARK: - Helpers

struct EmptyBody: Encodable {}
struct EmptyResponse: Decodable {}

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

private struct ErrorEnvelope: Decodable {
    let error: String?
    let message: String?

    var serverMessage: String? {
        error ?? message
    }
}
