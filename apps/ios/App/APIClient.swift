import Foundation
import MuralCore

final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

struct APIUsage { var input = 0; var output = 0; var searches = 0 }
struct APIResult { var text: String; var sources: [SourceLink]; var usage: APIUsage }

@MainActor final class APIClient {
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 45; config.timeoutIntervalForResource = 60
        config.httpCookieStorage = nil; config.urlCache = nil
        session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
    }
    
    func postURL(_ urlString: String, body: [String: Any], apiKey: String = "") async throws -> [String: Any] {
        guard let url = URL(string: urlString) else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw ProviderFailure(status: http.statusCode, body: data, reference: http.value(forHTTPHeaderField: "x-request-id") ?? http.value(forHTTPHeaderField: "x-goog-request-id")) }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw APIError.invalidResponse }
        return json
    }

    func post(_ path: String, body: [String: Any], provider: AIProvider = .hermes, customEndpoint: String = "", customModel: String = "") async throws -> [String: Any] {
        let key = CredentialStore.read() ?? ""
        if path.contains("http") { return try await postURL(path, body: body, apiKey: key) }
        let endpoint: String = {
            if (provider == .custom || provider == .hermes) && !customEndpoint.isEmpty { return customEndpoint }
            return provider.defaultEndpoint
        }()
        return try await postURL(endpoint, body: body, apiKey: key)
    }

    func respond(instructions: String, input: String, schema: [String: Any]? = nil, search: Bool = false, provider: AIProvider = .hermes, customEndpoint: String = "", customModel: String = "") async throws -> APIResult {
        let key = CredentialStore.read() ?? ""
        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && provider != .hermes && provider != .custom {
            throw APIError.missingKey
        }
        let endpoint: String = {
            if !customEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return customEndpoint.trimmingCharacters(in: .whitespacesAndNewlines) }
            return provider.defaultEndpoint
        }()

        if provider == .gemini {
            let model = !customModel.isEmpty ? customModel : provider.defaultModel
            var contents: [[String: Any]] = [["role": "user", "parts": [["text": input]]]]
            var genConfig: [String: Any] = ["maxOutputTokens": schema == nil ? 1400 : 2200]
            if let schema { genConfig["responseMimeType"] = "application/json"; genConfig["responseSchema"] = schema }
            var body: [String: Any] = ["systemInstruction": ["parts": [["text": instructions]]], "contents": contents, "generationConfig": genConfig]
            if search { body["tools"] = [["googleSearch": [String: Any]()]] }

            let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)"
            let json = try await postURL(urlString, body: body, apiKey: key)
            
            guard let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else { throw APIError.incomplete }
            var text = ""
            for part in parts { if let partText = part["text"] as? String { text += partText } }
            var sources: [SourceLink] = []
            if let grounding = firstCandidate["groundingMetadata"] as? [String: Any],
               let chunks = grounding["groundingChunks"] as? [[String: Any]] {
                for chunk in chunks {
                    if let web = chunk["web"] as? [String: Any], let url = web["uri"] as? String {
                        let source = SourceLink(title: web["title"] as? String ?? "Source", url: url)
                        if source.safeURL != nil && !sources.contains(where: { $0.url == url }) { sources.append(source) }
                    }
                }
            }
            var usage = APIUsage()
            if let u = json["usageMetadata"] as? [String: Any] {
                usage.input = u["promptTokenCount"] as? Int ?? 0; usage.output = u["candidatesTokenCount"] as? Int ?? 0
            }
            if let grounding = firstCandidate["groundingMetadata"] as? [String: Any],
               let queries = grounding["webSearchQueries"] as? [Any] { usage.searches = queries.count }
            guard !text.isEmpty else { throw APIError.incomplete }
            return APIResult(text: text, sources: sources, usage: usage)
        } else {
            // OpenAI-compatible format (Hermes, Groq, OpenRouter, OpenAI, Custom)
            let model = !customModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? customModel.trimmingCharacters(in: .whitespacesAndNewlines) : provider.defaultModel
            let messages: [[String: Any]] = [
                ["role": "system", "content": instructions],
                ["role": "user", "content": input]
            ]
            let body: [String: Any] = [
                "model": model,
                "messages": messages,
                "max_tokens": schema == nil ? 1400 : 2200
            ]
            let json = try await postURL(endpoint, body: body, apiKey: key)
            guard let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let text = message["content"] as? String else { throw APIError.incomplete }
            var usage = APIUsage()
            if let u = json["usage"] as? [String: Any] {
                usage.input = u["prompt_tokens"] as? Int ?? 0
                usage.output = u["completion_tokens"] as? Int ?? 0
            }
            guard !text.isEmpty else { throw APIError.incomplete }
            return APIResult(text: text, sources: [], usage: usage)
        }
    }

    static func object(_ fields: [String: Any]) -> [String: Any] { ["type": "OBJECT", "properties": fields, "required": fields.keys.sorted()] }
    static let string: [String: Any] = ["type": "STRING"]
    static func assessmentSchema(language: LanguageModule) -> [String: Any] { object([
        "outcome": ["type": "STRING", "enum": ["success", "partial", "breakdown", "uncertain"]],
        "suggestedLevel": ["type": "INTEGER"], "nextGoal": string, "capability": string,
        "words": ["type": "ARRAY", "items": object([
            "lemma": string, "meaning": string, "form": string, "quote": string, "language": ["type": "STRING", "enum": Array(Set([language.id, "en", "mixed", "uncertain"])).sorted()],
            "kind": ["type": "STRING", "enum": ["exposure", "understanding", "assisted", "independent", "lapse"]],
            "confidence": ["type": "NUMBER"], "sourceIDs": ["type": "ARRAY", "items": string]
        ])]
    ]) }
    enum APIError: LocalizedError {
        case missingKey, invalidResponse, incomplete, refused, http(Int)
        var errorDescription: String? {
            switch self {
            case .missingKey: "Please enter your API Key for the selected provider in Settings."
            case .invalidResponse, .incomplete: "The AI provider returned an incomplete response. Please try again."
            case .refused: "Mural couldn’t complete that request. Try a different topic."
            case .http(401), .http(403): "Your API key or endpoint wasn’t accepted. Check Settings."
            case .http(404): "This model or endpoint was not found. Check your provider settings."
            case .http(429): "The provider's rate limit was reached. Try again shortly."
            case .http(let status): "The AI service couldn’t complete the request (HTTP \(status)). Please try again."
            }
        }
    }
}