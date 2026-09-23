import Foundation
import MuralCore

// MARK: - Hermes VPS Orchestrator Models

public struct HermesUserProfile: Codable, Sendable {
    public var targetLanguage: String
    public var nativeLanguage: String
    public var cefrLevel: String
    public var interests: [String]
    public var focusAreas: [String] // e.g. ["Allemand Médical", "Grammaire B2 - Subordonnées", "Déclinaisons"]
    public var fsrsRetentionRate: Double
    public var totalSpokenMinutes: Double
    
    public init(
        targetLanguage: String = "de",
        nativeLanguage: String = "fr",
        cefrLevel: String = "B2",
        interests: [String] = ["Médecine", "Neurologie", "Conversation"],
        focusAreas: [String] = ["Allemand Médical (Assistenzarzt)", "Subordonnées (weil, obwohl, dass)", "Passif & Konjunktiv II"],
        fsrsRetentionRate: Double = 0.90,
        totalSpokenMinutes: Double = 0
    ) {
        self.targetLanguage = targetLanguage
        self.nativeLanguage = nativeLanguage
        self.cefrLevel = cefrLevel
        self.interests = interests
        self.focusAreas = focusAreas
        self.fsrsRetentionRate = fsrsRetentionRate
        self.totalSpokenMinutes = totalSpokenMinutes
    }
}

public struct HermesSyncPayload: Codable, Sendable {
    public var profile: HermesUserProfile
    public var fsrsItems: [FSRSItem]
    public var fsrsParams: FSRSParameters
    public var timestamp: Date
    
    public init(profile: HermesUserProfile, fsrsItems: [FSRSItem], fsrsParams: FSRSParameters, timestamp: Date = .now) {
        self.profile = profile
        self.fsrsItems = fsrsItems
        self.fsrsParams = fsrsParams
        self.timestamp = timestamp
    }
}

// MARK: - Hermes VPS Client & Orchestrator

public final class HermesOrchestratorClient: @unchecked Sendable {
    public static let shared = HermesOrchestratorClient()
    
    private let userProfileKey = "MuralHermesUserProfile"
    private var cachedProfile: HermesUserProfile
    
    public init() {
        if let data = UserDefaults.standard.data(forKey: userProfileKey),
           let profile = try? JSONDecoder().decode(HermesUserProfile.self, from: data) {
            self.cachedProfile = profile
        } else {
            self.cachedProfile = HermesUserProfile()
        }
    }
    
    public func getProfile() -> HermesUserProfile {
        return cachedProfile
    }
    
    public func saveProfile(_ profile: HermesUserProfile) {
        self.cachedProfile = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: userProfileKey)
        }
    }
    
    // MARK: - Sync with Hermes VPS Gateway
    public func syncWithVPS(endpoint: String, token: String) async throws -> HermesSyncPayload {
        guard !endpoint.isEmpty, let url = URL(string: endpoint.hasSuffix("/") ? "\(endpoint)api/fsrs/sync" : "\(endpoint)/api/fsrs/sync") else {
            throw OrchestratorError.invalidEndpoint
        }
        
        let localItems = FSRSStoreManager.shared.loadAllItems()
        let localParams = FSRSStoreManager.shared.loadParameters()
        let payload = HermesSyncPayload(profile: cachedProfile, fsrsItems: localItems, fsrsParams: localParams)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OrchestratorError.serverError
        }
        
        let serverPayload = try JSONDecoder().decode(HermesSyncPayload.self, from: data)
        
        // Merge server items into local FSRS store
        FSRSStoreManager.shared.saveItems(serverPayload.fsrsItems)
        FSRSStoreManager.shared.saveParameters(serverPayload.fsrsParams)
        self.saveProfile(serverPayload.profile)
        
        return serverPayload
    }
}

public enum OrchestratorError: LocalizedError {
    case invalidEndpoint
    case serverError
    
    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return "Adresse du VPS Hermes invalide."
        case .serverError: return "Le serveur Hermes VPS n'a pas répondu favorablement."
        }
    }
}
