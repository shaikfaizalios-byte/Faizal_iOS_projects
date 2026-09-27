import Foundation

enum APIError: Error, Equatable {
    case invalidResponse
    case unauthorized
    case server(status: Int, message: String?)
    case decoding(String)
    case transport(String)
}

/// A thin, dependency-free client. URLSession rather than a third-party
/// networking library: in a regulated codebase every external dependency is
/// something the security team has to review and keep patched.
struct APIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func get<Response: Decodable>(_ path: String, as type: Response.Type) async throws -> Response {
        try await send(request: makeRequest(path: path, method: "GET", body: nil, headers: [:]))
    }

    func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        headers: [String: String] = [:],
        as type: Response.Type
    ) async throws -> Response {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(body)
        return try await send(request: makeRequest(path: path, method: "POST", body: data, headers: headers))
    }

    private func makeRequest(
        path: String,
        method: String,
        body: Data?,
        headers: [String: String]
    ) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    private func send<Response: Decodable>(request: URLRequest) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw APIError.decoding(String(describing: error))
            }
        case 401, 403:
            throw APIError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8)
            throw APIError.server(status: http.statusCode, message: message)
        }
    }
}
