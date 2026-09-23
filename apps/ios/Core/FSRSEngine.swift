import Foundation

// MARK: - FSRS (Free Spaced Repetition Scheduler) Implementation

public enum FSRSRating: Int, Codable, Sendable, CaseIterable {
    case again = 1  // Échec / Oubli complet
    case hard = 2   // Difficile / Hésitation
    case good = 3   // Réussi / Correct
    case easy = 4   // Parfait / Immédiat & fluide
    
    public var label: String {
        switch self {
        case .again: return "À revoir"
        case .hard: return "Difficile"
        case .good: return "Bien"
        case .easy: return "Facile"
        }
    }
}

public enum FSRSState: Int, Codable, Sendable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

public struct FSRSItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var term: String            // Terme ou expression en allemand (ex: "obwohl", "sich gewöhnen an")
    public var meaning: String         // Sens / explication en français
    public var example: String?        // Exemple d'usage en phrase complète
    public var contextCategory: String // "Vocabulaire", "Grammaire", "Médical", "Assimil", "Drive"
    public var level: String           // "A1", "A2", "B1", "B2", "C1"
    public var languageID: String      // "de", etc.
    
    // FSRS Mathematical Parameters
    public var state: FSRSState
    public var stability: Double       // S : Stabilité en jours
    public var difficulty: Double      // D : Difficulté (1.0 à 10.0)
    public var elapsedDays: Double
    public var scheduledDays: Double
    public var reps: Int
    public var lapses: Int
    public var lastReview: Date?
    public var due: Date
    public var history: [FSRSRepetition]
    
    public init(
        id: UUID = UUID(),
        term: String,
        meaning: String,
        example: String? = nil,
        contextCategory: String = "Général",
        level: String = "B2",
        languageID: String = "de",
        state: FSRSState = .new,
        stability: Double = 0.4,
        difficulty: Double = 5.0,
        elapsedDays: Double = 0,
        scheduledDays: Double = 0,
        reps: Int = 0,
        lapses: Int = 0,
        lastReview: Date? = nil,
        due: Date = .now,
        history: [FSRSRepetition] = []
    ) {
        self.id = id
        self.term = term
        self.meaning = meaning
        self.example = example
        self.contextCategory = contextCategory
        self.level = level
        self.languageID = languageID
        self.state = state
        self.stability = max(0.1, stability)
        self.difficulty = min(10.0, max(1.0, difficulty))
        self.elapsedDays = elapsedDays
        self.scheduledDays = scheduledDays
        self.reps = reps
        self.lapses = lapses
        self.lastReview = lastReview
        self.due = due
        self.history = history
    }
    
    /// Calcul de la rétention actuelle (Retrievability R) selon la courbe d'oubli FSRS
    public func retrievability(at now: Date = .now) -> Double {
        guard let last = lastReview else { return 0.0 }
        let daysSince = max(0.0, now.timeIntervalSince(last) / 86400.0)
        if daysSince == 0 { return 1.0 }
        // R(t, S) = (1 + factor * t / S)^(-0.5) où factor = 19/81 ≈ 0.2346
        let factor = 19.0 / 81.0
        return pow(1.0 + factor * (daysSince / max(0.1, stability)), -0.5)
    }
    
    /// Indique si l'élément doit être révisé aujourd'hui
    public func isDue(at now: Date = .now, targetRetention: Double = 0.90) -> Bool {
        if state == .new { return true }
        if now >= due { return true }
        return retrievability(at: now) < targetRetention
    }
}

public struct FSRSRepetition: Codable, Equatable, Sendable {
    public var date: Date
    public var rating: FSRSRating
    public var reviewDurationSeconds: Double
    public var preReviewStability: Double
    public var preReviewDifficulty: Double
    public var note: String?
    
    public init(date: Date = .now, rating: FSRSRating, reviewDurationSeconds: Double = 0, preReviewStability: Double, preReviewDifficulty: Double, note: String? = nil) {
        self.date = date
        self.rating = rating
        self.reviewDurationSeconds = reviewDurationSeconds
        self.preReviewStability = preReviewStability
        self.preReviewDifficulty = preReviewDifficulty
        self.note = note
    }
}

// MARK: - FSRS Weights & Parameters (Self-Adjusting over time)

public struct FSRSParameters: Codable, Sendable {
    public var w: [Double]
    public var targetRetention: Double
    public var maximumIntervalDays: Double
    public var totalReviewsCount: Int
    
    public static let defaultWeights: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, // Initial stabilities for ratings 1,2,3,4
        7.1949, 0.5345, 1.4604, 0.0046,     // Initial & updated difficulty weights
        1.54575, 0.1192, 1.01925,           // Recall stability modifiers
        1.9395, 0.11, 0.29605, 0.22695,     // Lapse stability modifiers
        0.2315, 2.9898                      // Short-term learning & interval bounds
    ]
    
    public init(
        w: [Double] = FSRSParameters.defaultWeights,
        targetRetention: Double = 0.90,
        maximumIntervalDays: Double = 365.0,
        totalReviewsCount: Int = 0
    ) {
        self.w = w
        self.targetRetention = targetRetention
        self.maximumIntervalDays = maximumIntervalDays
        self.totalReviewsCount = totalReviewsCount
    }
    
    /// Ajustement automatique adaptatif des poids selon l'historique d'apprentissage réel de l'utilisateur
    public mutating func autoTune(observedSuccessRate: Double, sampleSize: Int) {
        guard sampleSize >= 10 else { return }
        totalReviewsCount += sampleSize
        
        // Si l'utilisateur réussit plus que la rétention cible (ex: 95% vs 90%), on augmente la stabilité initiale
        // pour espacer davantage les révisions et ne pas surcharger.
        let diff = observedSuccessRate - targetRetention
        let adjustmentFactor = 1.0 + (diff * 0.15) // Variation douce
        
        w[0] = max(0.1, min(2.0, w[0] * adjustmentFactor))
        w[1] = max(0.5, min(5.0, w[1] * adjustmentFactor))
        w[2] = max(1.5, min(10.0, w[2] * adjustmentFactor))
        w[3] = max(5.0, min(30.0, w[3] * adjustmentFactor))
    }
}

// MARK: - Core FSRS Scheduling Algorithm

public enum FSRSScheduler {
    
    /// Calcule le prochain état et les dates de révision suite à une note
    public static func review(
        item: FSRSItem,
        rating: FSRSRating,
        params: FSRSParameters = FSRSParameters(),
        now: Date = .now,
        duration: Double = 0,
        note: String? = nil
    ) -> FSRSItem {
        var updated = item
        let rep = FSRSRepetition(
            date: now,
            rating: rating,
            reviewDurationSeconds: duration,
            preReviewStability: item.stability,
            preReviewDifficulty: item.difficulty,
            note: note
        )
        updated.history.append(rep)
        updated.reps += 1
        
        let w = params.w
        let g = Double(rating.rawValue)
        
        if item.state == .new {
            // Initialisation
            let initStability = w[rating.rawValue - 1]
            let initDifficulty = min(10.0, max(1.0, w[4] - exp(w[5] * (g - 1.0)) + 1.0))
            
            updated.stability = initStability
            updated.difficulty = initDifficulty
            updated.state = rating == .again ? .learning : .review
            updated.scheduledDays = nextInterval(stability: initStability, targetRetention: params.targetRetention, maxInterval: params.maximumIntervalDays)
        } else {
            // Mise à jour de la difficulté
            let d0 = min(10.0, max(1.0, w[4] - exp(w[5] * (g - 1.0)) + 1.0))
            let nextD = w[6] * item.difficulty + (1.0 - w[6]) * d0
            // Mean reversion vers la difficulté moyenne (Good=3)
            let meanD = min(10.0, max(1.0, w[4] - exp(w[5] * 2.0) + 1.0))
            let finalD = min(10.0, max(1.0, w[7] * meanD + (1.0 - w[7]) * nextD))
            updated.difficulty = finalD
            
            let r = item.retrievability(at: now)
            
            if rating == .again {
                // Échec / Lapse
                updated.lapses += 1
                updated.state = .relearning
                let lapseStability = max(0.1, w[11] * pow(finalD, -w[12]) * (pow(item.stability + 1.0, w[13]) - 1.0) * exp(w[14] * (1.0 - r)))
                updated.stability = min(item.stability, lapseStability)
                updated.scheduledDays = 1.0
            } else {
                // Réussite (Hard, Good, Easy)
                updated.state = .review
                let hardPenalty = rating == .hard ? w[15] : 1.0
                let easyBonus = rating == .easy ? w[16] : 1.0
                
                let recallStability = item.stability * (1.0 + exp(w[8]) * (11.0 - finalD) * pow(item.stability, -w[9]) * (exp(w[10] * (1.0 - r)) - 1.0) * hardPenalty * easyBonus)
                updated.stability = max(item.stability + 0.1, recallStability)
                updated.scheduledDays = nextInterval(stability: updated.stability, targetRetention: params.targetRetention, maxInterval: params.maximumIntervalDays)
            }
        }
        
        updated.lastReview = now
        updated.due = Calendar.current.date(byAdding: .second, value: Int(updated.scheduledDays * 86400.0), to: now) ?? now.addingTimeInterval(updated.scheduledDays * 86400.0)
        
        return updated
    }
    
    public static func nextInterval(stability: Double, targetRetention: Double, maxInterval: Double) -> Double {
        // I = (S / factor) * (R^(-1/0.5) - 1) = (S / (19/81)) * (R^(-2) - 1)
        let factor = 19.0 / 81.0
        let interval = (stability / factor) * (pow(targetRetention, -2.0) - 1.0)
        return min(maxInterval, max(1.0, round(interval)))
    }
}

// MARK: - FSRS Local Store & Learning Coordinator

public final class FSRSStoreManager: @unchecked Sendable {
    public static let shared = FSRSStoreManager()
    
    private let itemsFileURL: URL
    private let paramsFileURL: URL
    
    public init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = appSupport.appendingPathComponent("MuralFSRS", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        
        self.itemsFileURL = dir.appendingPathComponent("fsrs_items.json")
        self.paramsFileURL = dir.appendingPathComponent("fsrs_params.json")
    }
    
    public func loadParameters() -> FSRSParameters {
        guard let data = try? Data(contentsOf: paramsFileURL),
              let params = try? JSONDecoder().decode(FSRSParameters.self, from: data) else {
            return FSRSParameters()
        }
        return params
    }
    
    public func saveParameters(_ params: FSRSParameters) {
        if let data = try? JSONEncoder().encode(params) {
            try? data.write(to: paramsFileURL, options: .atomic)
        }
    }
    
    public func loadItems(for languageID: String = "de") -> [FSRSItem] {
        guard let data = try? Data(contentsOf: itemsFileURL),
              let items = try? JSONDecoder().decode([FSRSItem].self, from: data) else {
            return []
        }
        return items.filter { $0.languageID == languageID }
    }
    
    public func loadAllItems() -> [FSRSItem] {
        guard let data = try? Data(contentsOf: itemsFileURL),
              let items = try? JSONDecoder().decode([FSRSItem].self, from: data) else {
            return []
        }
        return items
    }
    
    public func saveItem(_ item: FSRSItem) {
        var items = loadAllItems()
        if let idx = items.firstIndex(where: { $0.id == item.id || ($0.term.lowercased() == item.term.lowercased() && $0.languageID == item.languageID) }) {
            items[idx] = item
        } else {
            items.insert(item, at: 0)
        }
        persistItems(items)
    }
    
    public func saveItems(_ newItems: [FSRSItem]) {
        var items = loadAllItems()
        for item in newItems {
            if let idx = items.firstIndex(where: { $0.id == item.id || ($0.term.lowercased() == item.term.lowercased() && $0.languageID == item.languageID) }) {
                items[idx] = item
            } else {
                items.insert(item, at: 0)
            }
        }
        persistItems(items)
    }
    
    public func recordReview(itemId: UUID, rating: FSRSRating, duration: Double = 0, note: String? = nil) {
        var items = loadAllItems()
        var params = loadParameters()
        
        guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return }
        let current = items[idx]
        let updated = FSRSScheduler.review(item: current, rating: rating, params: params, duration: duration, note: note)
        items[idx] = updated
        
        // Auto-tuning périodique : calcul du taux de succès sur les 20 dernières répétitions
        let recentReps = items.flatMap(\.history).suffix(20)
        if recentReps.count >= 10 {
            let successes = recentReps.filter { $0.rating != .again }.count
            let rate = Double(successes) / Double(recentReps.count)
            params.autoTune(observedSuccessRate: rate, sampleSize: recentReps.count)
            saveParameters(params)
        }
        
        persistItems(items)
    }
    
    /// Récupère la liste des éléments prioritaires à réviser aujourd'hui (classés par rétention décroissante)
    public func getDueItems(for languageID: String = "de", limit: Int = 10, now: Date = .now) -> [FSRSItem] {
        let items = loadItems(for: languageID)
        let params = loadParameters()
        
        let dueItems = items.filter { $0.isDue(at: now, targetRetention: params.targetRetention) }
        
        // On trie : les plus oubliés en premier (R minimal), puis les nouveaux
        return Array(dueItems.sorted { a, b in
            let rA = a.retrievability(at: now)
            let rB = b.retrievability(at: now)
            return rA < rB
        }.prefix(limit))
    }
    
    private func persistItems(_ items: [FSRSItem]) {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: itemsFileURL, options: .atomic)
        }
    }
}

// MARK: - Voice-First FSRS Conversation Prompt Policy ("Tout en vocal, pas d'écrit")

public enum FSRSPromptPolicy {
    
    /// Injecte naturellement les notions FSRS dues dans le prompt vocal du professeur
    public static func buildVoiceConversationPrompt(
        basePolicyPrompt: String,
        languageID: String = "de",
        level: String = "B2",
        now: Date = .now
    ) -> String {
        let dueItems = FSRSStoreManager.shared.getDueItems(for: languageID, limit: 4, now: now)
        
        var fsrsDirectives = ""
        if !dueItems.isEmpty {
            let termsList = dueItems.map { item in
                let r = Int(item.retrievability(at: now) * 100)
                return "- « \(item.term) » (\(item.meaning)) [Rétention FSRS : \(r)% - Niveau: \(item.level)]"
            }.joined(separator: "\n")
            
            fsrsDirectives = """
            
            ══════════════════════════════════════════════════════════════════
            MÉMOIRE & RÉPÉTITION ESPACÉE FSRS ACTIVE (100% VOCAL & NATUREL) :
            ══════════════════════════════════════════════════════════════════
            L'algorithme FSRS a détecté que l'élève doit réactiver ces termes/expressions clés :
            \(termsList)
            
            CONSIGNES D'ENSEIGNEMENT VOCAL NATUREL :
            1. **ZÉRO ÉCRIT / 100% ORAL ET FLUIDE** :
               Ne fais jamais d'interro formelle ou scolaire écrite.
               Glisse NATURELLEMENT l'une de ces notions dans le fil de la conversation orale.
               Exemples :
               - Pose une question de mise en situation exigeant l'emploi d'un de ces mots.
               - Utilise le mot dans une phrase allemande naturelle et demande à l'élève de rebondir ou d'expliquer ce qu'il a compris.
               - Demande-lui : « Dis-moi, comment tu formulerais [situation] en utilisant [mot/expression] ? »
            
            2. **FEEDBACK ORAL EN DIRECT** :
               - Si l'élève utilise ou comprend parfaitement : Félicite brièvement et poursuis la conversation.
               - Si l'élève hésite ou fait une faute : Explique oralement la nuance en français (déclinaison, place du verbe, etc.), donne la phrase modèle allemande à haute voix, et demande-lui de la répéter.
            
            3. **AUTO-ÉVALUATION SILENCIEUSE FSRS** :
               À la fin de ta réponse, insère sur une nouvelle ligne une balise invisible pour enregistrer le résultat de l'élève si un terme a été testé :
               `[FSRS_REVIEW: {"term": "terme_testé", "rating": 1|2|3|4}]`
               (1=Again/Oublié, 2=Hard/Hésitant, 3=Good/Correct, 4=Easy/Fluide parfait).
            ══════════════════════════════════════════════════════════════════
            """
        }
        
        return basePolicyPrompt + fsrsDirectives
    }
}
