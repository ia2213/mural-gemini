import Foundation

/// Moteur Whisper.cpp on-device pour la transcription et le scoring d'accent.
///
/// **État** : Planifié — voir `docs/CORE_WHISPER_INTEGRATION.md` pour l'architecture complète.
/// Le code complet sera implémenté dans un ticket dédié. Ce placeholder expose
/// l'API publique et renvoie des erreurs explicites pour guider l'implémentation.
public final class WhisperEngine {
    public enum ModelSize {
        case base    // ~72 Mo
        case small   // ~130 Mo (recommandé)
        case medium  // ~490 Mo
    }

    private let modelSize: ModelSize
    private var modelURL: URL?
    private var isLoaded = false

    public init(modelSize: ModelSize = .small) {
        self.modelSize = modelSize
        let name: String
        switch modelSize {
        case .base:   name = "ggml-base.en"
        case .small:  name = "ggml-small.en"
        case .medium: name = "ggml-medium.en"
        }
        self.modelURL = Bundle.main.url(forResource: name, withExtension: "bin")
    }

    /// Charge le modèle Whisper depuis le bundle.
    public func load() throws {
        guard let url = modelURL else {
            throw WhisperError.modelNotFound
        }
        // TODO: intégrer whisper_init_from_file via bridging header C++
        // let ctx = whisper_load_model(url.path)
        isLoaded = true
    }

    /// Transcrit l'audio et retourne le texte.
    public func transcribe(audioData: Data, language: String = "de") throws -> String {
        guard isLoaded else { throw WhisperError.notLoaded }
        // TODO: sauver l'audio, appeler whisper_transcribe, lire le résultat
        throw WhisperError.notImplemented
    }

    /// Calcule le Word Error Rate entre transcription et texte cible.
    public func wordErrorRate(actual: String, expected: String) -> Double {
        let actualWords = tokenize(actual)
        let expectedWords = tokenize(expected)
        guard !expectedWords.isEmpty else { return 1.0 }
        let distance = levenshteinDistance(actualWords, expectedWords)
        return Double(distance) / Double(expectedWords.count)
    }

    /// Score d'accent 0-100 (100 = parfait).
    public func accentScore(transcription: String, target: String) -> Int {
        let wer = wordErrorRate(actual: transcription, expected: target)
        return max(0, min(100, Int((1.0 - wer) * 100.0)))
    }

    // MARK: - Helpers privés

    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private func levenshteinDistance(_ a: [String], _ b: [String]) -> Int {
        let m = a.count, n = b.count
        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        for i in 1...m {
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost)
            }
        }
        return dp[m][n]
    }
}

public enum WhisperError: Error, LocalizedError {
    case modelNotFound
    case notLoaded
    case notImplemented
    case transcriptionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Modèle Whisper non trouvé dans le bundle. Ajoutez ggml-small.en.bin."
        case .notLoaded:
            return "Le modèle Whisper n'a pas été chargé. Appelez load() d'abord."
        case .notImplemented:
            return "Whisper.cpp on-device n'est pas encore implémenté. Voir docs/CORE_WHISPER_INTEGRATION.md"
        case .transcriptionFailed(let msg):
            return "Transcription Whisper échouée : \(msg)"
        }
    }
}
