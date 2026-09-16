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
    func post(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let key = CredentialStore.read() else { throw APIError.missingKey }
        let endpoint = path.contains("http") ? path : "https://generativelanguage.googleapis.com/v1beta/models/" + path + "?key=" + key
        guard let url = URL(string: endpoint) else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw ProviderFailure(status: http.statusCode, body: data, reference: http.value(forHTTPHeaderField: "x-goog-request-id")) }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw APIError.invalidResponse }
        return json
    }
    func respond(instructions: String, input: String, schema: [String: Any]? = nil, search: Bool = false) async throws -> APIResult {
        var contents: [[String: Any]] = [
            ["role": "user", "parts": [["text": input]]]
        ]
        var generationConfig: [String: Any] = [
            "maxOutputTokens": schema == nil ? 1400 : 2200
        ]
        if let schema {
            generationConfig["responseMimeType"] = "application/json"
            generationConfig["responseSchema"] = schema
        }
        var body: [String: Any] = [
            "systemInstruction": ["parts": [["text": instructions]]],
            "contents": contents,
            "generationConfig": generationConfig
        ]
        if search {
            body["tools"] = [["googleSearch": [String: Any]()]]
        }
        let json = try await post("gemini-2.5-flash:generateContent", body: body)
        guard let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw APIError.incomplete
        }
        var text = ""
        for part in parts {
            if let partText = part["text"] as? String { text += partText }
        }
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
            usage.input = u["promptTokenCount"] as? Int ?? 0
            usage.output = u["candidatesTokenCount"] as? Int ?? 0
        }
        if let grounding = firstCandidate["groundingMetadata"] as? [String: Any],
           let queries = grounding["webSearchQueries"] as? [Any] {
            usage.searches = queries.count
        }
        guard !text.isEmpty else { throw APIError.incomplete }
        return APIResult(text: text, sources: sources, usage: usage)
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
            case .missingKey: "Add your Gemini key in Settings to begin."
            case .invalidResponse, .incomplete: "Gemini returned an incomplete response. Please try again."
            case .refused: "Mural couldn’t complete that request. Try a different topic."
            case .http(401), .http(403): "Your Gemini key wasn’t accepted. Check it in Settings."
            case .http(404): "This API key may not have access to the requested model. Check your Google AI Studio project."
            case .http(429): "Gemini’s usage or rate limit was reached. Check your project’s billing and limits."
            case .http(let status): "Gemini couldn’t complete the request (HTTP \(status)). Please try again."
            }
        }
    }
}