import Foundation

public struct WordState: Identifiable, Sendable {
    public var id: String
    public var lemma: String
    public var meaning: String
    public var form: String
    public var example: String
    /// Backward-compatible mastery indicator (0-3) derived from FSRS stability.
    public var bars: Int
    /// Number of understanding-kind observations (for persistence / export).
    public var understandingCount: Int
    /// Number of independent-kind observations (for persistence / export).
    public var independentCount: Int
    public var lastSeen: Date
    public var dueAt: Date
    /// Backward-compatible label derived from bars.
    public var label: String { FSRS.labelFromBars(bars) }
    /// Backward-compatible explanation derived from independentCount + bars.
    public var explanation: String { FSRS.explanation(independentCount: independentCount, bars: bars) }
}

public struct LearnerState: Sendable {
    public var challenge: Int
    public var observationCount: Int
    public var nextGoal: String
    public var capabilities: [String]
    public var words: [WordState]
    public var levelLabel: String {
        let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]
        return levels[min(5, max(0, challenge))]
    }
    public var fullLevelName: String {
        let descriptions = [
            "A1 · Débutant",
            "A2 · Élémentaire",
            "B1 · Intermédiaire",
            "B2 · Avancé",
            "C1 · Autonome / Médical",
            "C2 · Bilingue / Expert"
        ]
        return descriptions[min(5, max(0, challenge))]
    }
}

public enum LearningEngine {
    public static func validate(_ proposal: Assessment, session: SessionRecord) -> Assessment? {
        guard LanguageRegistry.module(for: session.languageID) != nil,
              let passage = session.passages.first(where: { $0.id == proposal.passageID && $0.speaker == .user }),
              passage.revisionKey == proposal.revisionKey,
              (0...5).contains(proposal.suggestedLevel), proposal.words.count <= 12 else { return nil }
        let allowed = Set(passage.fragments.map(\.id))
        var validated = proposal
        validated.nextGoal = String(validated.nextGoal.prefix(300))
        validated.capability = String(validated.capability.prefix(160))
        validated.words = proposal.words.compactMap { word in
            guard word.language == session.languageID,
                  !word.sourceIDs.isEmpty, Set(word.sourceIDs).isSubset(of: allowed),
                  word.confidence.isFinite, word.confidence >= 0.8, word.confidence <= 1,
                  !word.lemma.isEmpty, word.lemma.count < 100, !word.meaning.isEmpty, word.meaning.count < 180,
                  !word.form.isEmpty, !word.quote.isEmpty,
                  passage.text.localizedCaseInsensitiveContains(word.quote),
                  word.quote.localizedCaseInsensitiveContains(word.form) else { return nil }
            let refs = Passage.join(passage.fragments.filter { word.sourceIDs.contains($0.id) }.map(\.text))
            guard refs.localizedCaseInsensitiveContains(word.quote) else { return nil }
            var result = word
            if result.kind == .independent {
                // A visible meaning or immediate imitation is supporting evidence, never independent recall.
                let recentlyModeled = session.passages.contains {
                    $0.speaker == .assistant && $0.startMS <= passage.startMS && passage.startMS - $0.endMS < 90_000 &&
                    $0.text.localizedCaseInsensitiveContains(word.form)
                }
                if passage.fragments.contains(where: { $0.meaningVisible || $0.typed }) || recentlyModeled { result.kind = .assisted }
            }
            return result
        }
        return validated
    }

    public static func project(_ sessions: [SessionRecord], languageID: String = LanguageRegistry.defaultID, hiddenWords: [String] = [], userBaseCEFR: String = "B2", now: Date = .now) -> LearnerState {
        let levelMap = ["A1": 0, "A2": 1, "B1": 2, "B2": 3, "C1": 4, "C2": 5]
        var level = levelMap[userBaseCEFR.uppercased()] ?? 3
        var count = 0, successes = 0
        var nextGoal = "Pratique orale continue et progression de niveau."
        var capabilityEvidence: [String: Set<String>] = [:]
        var events: [String: [(WordProposal, Date, String, EvidenceKind)]] = [:]
        let calendar = Calendar(identifier: .gregorian)
        for session in sessions.filter({ $0.languageID == languageID }).sorted(by: { $0.startedAt < $1.startedAt }) {
            var seen = Set<String>()
            for raw in session.assessments.sorted(by: { $0.createdAt < $1.createdAt }) {
                guard !seen.contains(raw.passageID), let a = validate(raw, session: session) else { continue }
                seen.insert(raw.passageID)
                count += 1
                if a.outcome == .breakdown {
                    successes = max(0, successes - 1)
                } else if a.outcome == .success {
                    successes += 1
                    // After 3 successful observations demonstrating mastery, promote to next CEFR level!
                    if successes >= 3 {
                        level = min(5, level + 1)
                        successes = 0
                    }
                }
                if !a.nextGoal.isEmpty { nextGoal = a.nextGoal }
                if a.outcome == .success && !a.capability.isEmpty {
                    capabilityEvidence[a.capability, default: []].insert("\(calendar.startOfDay(for: a.createdAt))|\(a.context)")
                }
                var seenWords = Set<String>()
                for word in a.words where !hiddenWords.contains(word.key) && seenWords.insert(word.key).inserted {
                    events[word.key, default: []].append((word, a.createdAt, a.context, word.kind))
                }
            }
        }
        let words: [WordState] = events.compactMap { key, observations in
            guard let last = observations.last else { return nil }
            // FESRS computes difficulty, stability, and retrievability from the full observation history.
            let (difficulty, stability, understandingCount, independentCount, wasLapsed) = fsrsStateFromObservations(observations, now: now)

            let independent = observations.filter { $0.3 == .independent }
            let lastRecallDate = independent.last?.1 ?? last.1
            let elapsedDays = max(0, now.timeIntervalSince(lastRecallDate) / 86400)
            let retrievability = FSRS.retrievability(stability: stability, elapsedDays: elapsedDays)

            // Next interval: days until retrievability drops to desiredRetention.
            let nextIntervalDays = FSRS.nextInterval(stability: stability, targetRetention: FSRS.desiredRetention)
            let due = lastRecallDate.addingTimeInterval(nextIntervalDays * 86400)

            let bars = FSRS.barsFromStability(stability)

            return WordState(
                id: key,
                lemma: last.0.lemma,
                meaning: last.0.meaning,
                form: last.0.form,
                example: last.0.quote,
                bars: bars,
                understandingCount: understandingCount,
                independentCount: independentCount,
                lastSeen: last.1,
                dueAt: due
            )
        }.sorted { $0.lastSeen > $1.lastSeen }
        return LearnerState(challenge: level, observationCount: count, nextGoal: nextGoal,
                            capabilities: capabilityEvidence.filter { $0.value.count >= 3 }.keys.sorted(), words: words)
    }

    // MARK: - FSRS State Derivation from Observation History

    /// Derive FSRS parameters (difficulty 1-10, stability in days) from ordered observation history.
    /// - Returns: (difficulty, stability, understandingCount, independentCount, wasLapsed)
    private static func fsrsStateFromObservations(_ observations: [(WordProposal, Date, String, EvidenceKind)], now: Date) -> (Double, Double, Int, Int, Bool) {
        // Count by kind
        let understandingCount = observations.filter { $0.3 == .understanding }.count
        let independentCount = observations.filter { $0.3 == .independent }.count
        let lapseObservations = observations.filter { $0.3 == .lapse }

        // Default difficulty: 5 (medium). Harder if the word has many lapses relative to recollections.
        var difficulty: Double = 5.0
        if independentCount > 0 {
            let lapseRatio = Double(lapseObservations.count) / Double(independentCount + lapseObservations.count)
            difficulty = 5.0 + (lapseRatio - 0.1) * 5.0  // more lapses → higher difficulty
            difficulty = min(10.0, max(1.0, difficulty))
        } else if !observations.isEmpty {
            // No independent recall yet → treat as difficult
            difficulty = 7.0
        }

        // Compute stability from spaced independent recall events.
        var stability: Double = 1.0  // baseline fresh memory
        let independentSorted = independentObservations(from: observations).sorted(by: { $0.date < $1.date })

        if independentSorted.isEmpty {
            // No independent recall: low stability, governed by last observation type.
            if !lapseObservations.isEmpty, let lastLapse = lapseObservations.last?.date {
                let daysSinceLapse = max(0, now.timeIntervalSince(lastLapse) / 86400)
                if daysSinceLapse < 1.0 {
                    stability = 0.5  // very recent lapse
                } else {
                    stability = 1.0
                }
            } else {
                stability = 1.0
            }
        } else {
            // FSRS-like stability update across spaced recalls.
            for i in 1..<independentSorted.count {
                let prev = independentSorted[i - 1].date
                let curr = independentSorted[i].date
                let deltaDays = max(1, curr.timeIntervalSince(prev) / 86400)
                let r = FSRS.retrievability(stability: stability, elapsedDays: deltaDays)
                // Successful recall → update stability
                stability = FSRS.updateStability(stability: stability, difficulty: difficulty, retrievability: r, wasSuccessful: true)
                // Difficulty adapts: wider spacing = easier
                if deltaDays >= 2 {
                    difficulty = FSRS.updateDifficulty(difficulty: difficulty, wasSuccessful: true)
                }
            }
            // Final review: if last independent recall was recent, boost stability slightly.
            let lastRecall = independentSorted.last!.date
            let finalDelta = max(0, now.timeIntervalSince(lastRecall) / 86400)
            if finalDelta < 1.0 {
                // Still fresh from last review
                stability = max(stability, 1.5)
            }
        }

        // Cap stability to avoid absurd intervals
        stability = min(365.0, max(0.5, stability))

        let wasLapsed = !lapseObservations.isEmpty && lapseObservations.last!.date > (independentSorted.last?.date ?? .distantPast)

        return (difficulty, stability, understandingCount, independentCount, wasLapsed)
    }

    private static func independentObservations(from observations: [(WordProposal, Date, String, EvidenceKind)]) -> [(date: Date, kind: EvidenceKind)] {
        observations.filter { $0.3 == .independent }.map { (date: $0.1, kind: $0.3) }
    }
}
