import Foundation

/// Nettoyeur HTML pour les cartes Anki importées.
/// Supprime les balises, décode les entités et normalise le texte.
public final class HTMLSanitizer {
    public static let shared = HTMLSanitizer()
    private init() {}

    /// Nettoie une chaîne HTML en texte brut.
    public func clean(_ html: String?) -> String {
        guard let html, !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        var result = html
        // Supprimer les commentaires
        result = result.replacingOccurrences(of: "<!--.*?-->", with: "", options: .regularExpression)
        // Supprimer les balises
        result = result.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
        // Décodage des entités
        let entities = [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&apos;", "'")]
        for (entity, decoded) in entities {
            result = result.replacingOccurrences(of: entity, with: decoded, options: .caseInsensitive)
        }
        // Décodage des entités numériques
        if let regex = try? NSRegularExpression(pattern: "&#(\\d+);", options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "\$1")
        }
        // Normalisation
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\n\\s*\\n", with: "\n\n", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Nettoie les champs d'une carte Anki.
    public func cleanFields(_ fields: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in fields {
            result[key] = clean(value)
        }
        return result
    }

    /// Traitement d'une carte Anki complète.
    public func processAnkiCard(_ cardData: [String: String]) -> [String: String] {
        return cleanFields(cardData)
    }
}
