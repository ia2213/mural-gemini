import Foundation
import MuralCore

// MARK: - Document Vector Chunk Model

public struct VectorChunk: Identifiable, Codable, Sendable {
    public var id: UUID
    public var documentID: UUID
    public var documentTitle: String
    public var level: String
    public var text: String
    public var embedding: [Float]
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        documentID: UUID,
        documentTitle: String,
        level: String,
        text: String,
        embedding: [Float],
        createdAt: Date = .now
    ) {
        self.id = id
        self.documentID = documentID
        self.documentTitle = documentTitle
        self.level = level
        self.text = text
        self.embedding = embedding
        self.createdAt = createdAt
    }
}

// MARK: - Gemini Embedding & Semantic Search Manager

public final class GeminiEmbeddingManager: @unchecked Sendable {
    public static let shared = GeminiEmbeddingManager()
    
    private let vectorStoreURL: URL
    private var vectorCache: [VectorChunk] = []
    private let queue = DispatchQueue(label: "no.william.mural.embeddings")
    
    public init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = appSupport.appendingPathComponent("MuralEmbeddings", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.vectorStoreURL = dir.appendingPathComponent("vector_chunks.json")
        self.vectorCache = loadStoredChunks()
    }
    
    // MARK: - Generate Embedding via Gemini text-embedding-004 API
    public func getEmbedding(for text: String, apiKey: String) async throws -> [Float] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmbeddingError.missingAPIKey
        }
        
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { throw EmbeddingError.invalidEndpoint }
        
        let body: [String: Any] = [
            "model": "models/text-embedding-004",
            "content": [
                "parts": [
                    ["text": String(text.prefix(2000))]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw EmbeddingError.serverError
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let embeddingObj = json["embedding"] as? [String: Any],
              let values = embeddingObj["values"] as? [Double] else {
            throw EmbeddingError.invalidResponse
        }
        
        return values.map { Float($0) }
    }
    
    // MARK: - Index a Document into Vector Store
    public func indexDocument(_ document: StudyDocument, apiKey: String) async throws {
        let chunks = chunkText(document.rawContent, maxChars: 800)
        var newVectorChunks: [VectorChunk] = []
        
        for chunkText in chunks {
            if let emb = try? await getEmbedding(for: chunkText, apiKey: apiKey) {
                let vc = VectorChunk(
                    documentID: document.id,
                    documentTitle: document.title,
                    level: document.level,
                    text: chunkText,
                    embedding: emb
                )
                newVectorChunks.append(vc)
            }
        }
        
        queue.sync {
            // Remove old chunks of same doc
            vectorCache.removeAll { $0.documentID == document.id }
            vectorCache.append(contentsOf: newVectorChunks)
            saveStoredChunks(vectorCache)
        }
    }
    
    // MARK: - Semantic Vector Search (Cosine Similarity)
    public func search(query: String, levelFilter: String? = nil, apiKey: String, topK: Int = 3) async -> [VectorChunk] {
        guard let queryEmbedding = try? await getEmbedding(for: query, apiKey: apiKey) else {
            return []
        }
        
        let chunks = queue.sync { vectorCache }
        let filtered = chunks.filter { chunk in
            if let level = levelFilter, !level.isEmpty && level != "all" && level != "Autre" {
                return chunk.level == level
            }
            return true
        }
        
        let scored = filtered.map { chunk in
            (chunk: chunk, score: cosineSimilarity(queryEmbedding, chunk.embedding))
        }
        
        return scored.sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0.chunk }
    }
    
    // MARK: - Math Helpers
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? (dot / denom) : 0
    }
    
    private func chunkText(_ text: String, maxChars: Int = 800) -> [String] {
        var chunks: [String] = []
        let paragraphs = text.components(separatedBy: "\n\n")
        var current = ""
        
        for p in paragraphs {
            let clean = p.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            if current.count + clean.count > maxChars {
                if !current.isEmpty { chunks.append(current) }
                current = clean
            } else {
                current += (current.isEmpty ? "" : "\n\n") + clean
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
    
    // MARK: - Persistence
    private func loadStoredChunks() -> [VectorChunk] {
        guard let data = try? Data(contentsOf: vectorStoreURL),
              let chunks = try? JSONDecoder().decode([VectorChunk].self, from: data) else {
            return []
        }
        return chunks
    }
    
    private func saveStoredChunks(_ chunks: [VectorChunk]) {
        if let data = try? JSONEncoder().encode(chunks) {
            try? data.write(to: vectorStoreURL, options: .atomic)
        }
    }
}

public enum EmbeddingError: LocalizedError {
    case missingAPIKey
    case invalidEndpoint
    case serverError
    case invalidResponse
    
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Clé API Google manquante pour la recherche sémantique."
        case .invalidEndpoint: return "Endpoint d'embedding invalide."
        case .serverError: return "Erreur du serveur d'embedding Gemini."
        case .invalidResponse: return "Réponse d'embedding Gemini invalide."
        }
    }
}
