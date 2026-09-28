import Foundation

/// A target language's content and teaching policy. IDs are stable storage keys.
public struct LanguageModule: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let nativeName: String
    public let variety: String
    public let locale: String
    public let greeting: String
    public let greetingWord: String
    public let speechGuidance: String
    public let writingGuidance: String
    public let lemmaGuidance: String
    public let teachingFocus: [String]
    public let topicPlaceholder: String
    public let lookupUnavailableReply: String
    public let themeOverrides: [String: ConversationTheme]

    public var themes: [ConversationTheme] {
        ConversationTheme.shared.map { themeOverrides[$0.id] ?? $0 }
    }
    public var defaultTitle: String { "A little \(name)" }
    public var talkTitle: String { "A little everyday \(name)" }
    public var settingsTitle: String { "\(name) · \(variety)" }
    public var flag: String {
        switch id {
        case "de": return "🇩🇪"
        case "fr": return "🇫🇷"
        case "ro": return "🇷🇴"
        case "en-US": return "🇺🇸"
        case "en-GB": return "🇬🇧"
        case "es": return "🇪🇸"
        case "it": return "🇮🇹"
        case "ar": return "🇸🇦"
        case "he": return "🇮🇱"
        case "ja": return "🇯🇵"
        case "ru": return "🇷🇺"
        case "pt": return "🇵🇹"
        case "zh": return "🇨🇳"
        case "no": return "🇳🇴"
        default: return "🌐"
        }
    }
}

public enum LanguageRegistry {
    public static let defaultID = "de"
    public static let all: [LanguageModule] = [
        .german, .french, .romanian, .americanEnglish, .britishEnglish, .spanish, .italian,
        .arabic, .hebrew, .japanese, .russian, .portuguese, .mandarin, .norwegian
    ]
    public static func module(for id: String) -> LanguageModule? { all.first { $0.id == id } }
}

public enum MeaningLanguages {
    public static let all = ["Français", "English", "Deutsch", "Español", "Italiano", "Português", "Română", "العربية", "中文", "Polski", "Українська", "French", "German", "Spanish"]
    public static func greeting(in language: String) -> String {
        [
            "Français": "Salut !",
            "French": "Salut !",
            "English": "Hi!",
            "Deutsch": "Hallo!",
            "German": "Hallo!",
            "Español": "¡Hola!",
            "Spanish": "¡Hola!",
            "Italiano": "Ciao!",
            "Italian": "Ciao!",
            "Português": "Olá!",
            "Portuguese": "Olá!",
            "Română": "Bună!",
            "Norwegian": "Hei!",
            "Chinese (Simplified)": "你好！",
            "中文": "你好！",
            "Polski": "Cześć!",
            "Polish": "Cześć!",
            "Arabic": "مرحبًا!",
            "العربية": "مرحبًا!",
            "Ukrainian": "Привіт!",
            "Українська": "Привіт!"
        ][language] ?? "Salut !"
    }
}
