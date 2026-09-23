import Foundation

// MARK: - Assimil Study Models

public struct AssimilLine: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var lineIndex: Int
    public var speaker: String?
    public var targetText: String
    public var phonetic: String?
    public var nativeTranslation: String
    public var notes: String?
    
    public init(id: UUID = UUID(), lineIndex: Int, speaker: String? = nil, targetText: String, phonetic: String? = nil, nativeTranslation: String, notes: String? = nil) {
        self.id = id
        self.lineIndex = lineIndex
        self.speaker = speaker
        self.targetText = targetText
        self.phonetic = phonetic
        self.nativeTranslation = nativeTranslation
        self.notes = notes
    }
}

public struct AssimilExerciseItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var itemIndex: Int
    public var prompt: String
    public var hint: String?
    public var expectedAnswer: String
    public var explanation: String?
    
    public init(id: UUID = UUID(), itemIndex: Int, prompt: String, hint: String? = nil, expectedAnswer: String, explanation: String? = nil) {
        self.id = id
        self.itemIndex = itemIndex
        self.prompt = prompt
        self.hint = hint
        self.expectedAnswer = expectedAnswer
        self.explanation = explanation
    }
}

public struct AssimilExercise: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var instructions: String
    public var items: [AssimilExerciseItem]
    
    public init(id: UUID = UUID(), title: String, instructions: String = "", items: [AssimilExerciseItem] = []) {
        self.id = id
        self.title = title
        self.instructions = instructions
        self.items = items
    }
}

public struct AssimilLesson: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var lessonNumber: Int?
    public var title: String
    public var targetLanguageID: String
    public var nativeLanguageID: String
    public var rawExtractedText: String
    public var dialogue: [AssimilLine]
    public var grammarNotes: [String]
    public var exercises: [AssimilExercise]
    public var createdAt: Date
    public var lastStudiedAt: Date?
    public var completedSteps: [String]
    
    public init(
        id: UUID = UUID(),
        lessonNumber: Int? = nil,
        title: String,
        targetLanguageID: String = "de",
        nativeLanguageID: String = "fr",
        rawExtractedText: String = "",
        dialogue: [AssimilLine] = [],
        grammarNotes: [String] = [],
        exercises: [AssimilExercise] = [],
        createdAt: Date = .now,
        lastStudiedAt: Date? = nil,
        completedSteps: [String] = []
    ) {
        self.id = id
        self.lessonNumber = lessonNumber
        self.title = title
        self.targetLanguageID = targetLanguageID
        self.nativeLanguageID = nativeLanguageID
        self.rawExtractedText = rawExtractedText
        self.dialogue = dialogue
        self.grammarNotes = grammarNotes
        self.exercises = exercises
        self.createdAt = createdAt
        self.lastStudiedAt = lastStudiedAt
        self.completedSteps = completedSteps
    }
}

// MARK: - Document & Google Drive Study Models

public struct StudyConcept: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var term: String
    public var definition: String
    public var example: String?
    
    public init(id: UUID = UUID(), term: String, definition: String, example: String? = nil) {
        self.id = id
        self.term = term
        self.definition = definition
        self.example = example
    }
}

public struct StudyQuizQuestion: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var question: String
    public var choices: [String]?
    public var correctAnswer: String
    public var explanation: String?
    
    public init(id: UUID = UUID(), question: String, choices: [String]? = nil, correctAnswer: String, explanation: String? = nil) {
        self.id = id
        self.question = question
        self.choices = choices
        self.correctAnswer = correctAnswer
        self.explanation = explanation
    }
}

public struct StudyDocument: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var source: String // "Google Drive", "Fichiers iOS", "Texte / Note", "PDF"
    public var rawContent: String
    public var pageCount: Int
    public var summary: String
    public var targetLanguageID: String
    public var keyConcepts: [StudyConcept]
    public var quizQuestions: [StudyQuizQuestion]
    public var createdAt: Date
    public var lastStudiedAt: Date?
    
    public init(
        id: UUID = UUID(),
        title: String,
        source: String = "Google Drive",
        rawContent: String,
        pageCount: Int = 1,
        summary: String = "",
        targetLanguageID: String = "de",
        keyConcepts: [StudyConcept] = [],
        quizQuestions: [StudyQuizQuestion] = [],
        createdAt: Date = .now,
        lastStudiedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.rawContent = rawContent
        self.pageCount = pageCount
        self.summary = summary
        self.targetLanguageID = targetLanguageID
        self.keyConcepts = keyConcepts
        self.quizQuestions = quizQuestions
        self.createdAt = createdAt
        self.lastStudiedAt = lastStudiedAt
    }
}

// MARK: - Study Pedagogical Policies

public enum AssimilTeacherPolicy {
    public static func systemPrompt(lesson: AssimilLesson, step: String, correctionLevel: String = "medium") -> String {
        let targetLang = LanguageRegistry.module(for: lesson.targetLanguageID)?.name ?? "German"
        let dialogueText = lesson.dialogue.enumerated().map { (idx, line) in
            "\(idx + 1). [\(targetLang)]: \(line.targetText) | [Traduction]: \(line.nativeTranslation)"
        }.joined(separator: "\n")
        
        let grammarText = lesson.grammarNotes.joined(separator: "\n- ")
        let exercisesText = lesson.exercises.map { ex in
            "Exercice: \(ex.title)\n" + ex.items.map { " - \($0.prompt) -> Attendu: \($0.expectedAnswer)" }.joined(separator: "\n")
        }.joined(separator: "\n\n")

        return """
        Tu es le Professeur Mural dédié à l'apprentissage selon la méthode Assimil.
        Langue cible enseignée : \(targetLang).
        Langue de support / explications : Français.
        Titre de la leçon : \(lesson.title) (Leçon \(lesson.lessonNumber.map(String.init) ?? "1")).
        Niveau de rigueur de correction : \(correctionLevel.uppercased()).
        
        CONTENU OFFICIEL DE LA LEÇON ASSIMIL SCANNÉE :
        --- DIALOGUE ---
        \(dialogueText.isEmpty ? lesson.rawExtractedText : dialogueText)
        
        --- REMARQUES DE GRAMMAIRE & VOCABULAIRE ---
        \(grammarText.isEmpty ? "Pas de notes spécifiques." : grammarText)
        
        --- EXERCICES DE LA LEÇON ---
        \(exercisesText.isEmpty ? "Pas d'exercices formels détectés." : exercisesText)
        
        MISSION & RÔLE ACTUEL (\(step.uppercased())) :
        - Si étape 'dialogue' (Répétition & Prononciation) :
          Guide l'élève phrase par phrase dans le dialogue. Lis la phrase en \(targetLang), donne la traduction si besoin, demande à l'élève de répéter à l'oral ou de traduire. Analyse sa réponse et donne un retour encourageant avec des conseils de prononciation et de syntaxe.
        - Si étape 'grammar' (Explications & Points clés) :
          Explique de manière vivante et concise les règles grammaticales, les déclinaisons, l'ordre des mots et le vocabulaire nouveau de cette leçon. Pose une question d'application pour vérifier la compréhension.
        - Si étape 'exercises' (Exercices interactifs & Pratique) :
          Fais passer les exercices de la leçon un par un à l'élève. Valide ses réponses, corrige immédiatement les fautes et donne la solution avec l'explication.
        - Si étape 'conversation' (Mise en situation) :
          Joue un jeu de rôle ou converse naturellement en \(targetLang) en réutilisant exactement les structures et mots clés appris dans cette leçon Assimil.
        
        RÈGLES D'OR DU PROFESSEUR ASSIMIL :
        1. Sois chaleureux, pédagogue et concis (pas de longs monologues, favorise l'interactivité).
        2. Quand tu parles en \(targetLang), utilise une formulation authentique et naturelle.
        3. Fais progresser l'élève pas à pas et encourage chaque effort.
        """
    }

    public static func ocrStructuringPrompt(targetLanguage: String = "German") -> String {
        """
        Tu es un expert en traitement de manuels de langues (notamment la méthode Assimil).
        Voici le texte brut extrait par OCR d'une page de livre de cours.
        
        Analyse ce texte et convertis-le rigoureusement en un objet JSON valide au format exact suivant :
        {
          "lessonNumber": 1,
          "title": "Titre de la leçon",
          "dialogue": [
            {
              "lineIndex": 1,
              "speaker": "Nom ou null",
              "targetText": "Phrase dans la langue cible (\(targetLanguage))",
              "phonetic": "Guide phonétique si présent ou null",
              "nativeTranslation": "Traduction française en regard",
              "notes": "Renvoi de note ou remarque si présent ou null"
            }
          ],
          "grammarNotes": [
            "Explication grammaticale ou remarque de vocabulaire"
          ],
          "exercises": [
            {
              "title": "Exercice 1 / Übung 1",
              "instructions": "Consigne",
              "items": [
                {
                  "itemIndex": 1,
                  "prompt": "Phrase à traduire ou texte à trous",
                  "expectedAnswer": "Réponse attendue / corrigé"
                }
              ]
            }
          ]
        }
        
        Réponds UNIQUEMENT avec le JSON valide, sans balises superflues ni texte avant ou après.
        """
    }
}

public enum DocumentTeacherPolicy {
    public static func systemPrompt(doc: StudyDocument, mode: String = "interactive", correctionLevel: String = "medium") -> String {
        let targetLang = LanguageRegistry.module(for: doc.targetLanguageID)?.name ?? "German"
        
        return """
        Tu es le Professeur Mural spécialisé dans l'apprentissage basé sur des documents et cours choisis par l'élève (provenant de Google Drive ou de ses fichiers).
        Langue cible d'apprentissage : \(targetLang).
        Langue d'échange : Français et \(targetLang).
        Titre du document : \(doc.title) (Source : \(doc.source)).
        Niveau de correction : \(correctionLevel.uppercased()).
        
        CONTENU DU DOCUMENT ÉTUDIÉ :
        \"\"\"
        \(String(doc.rawContent.prefix(8000)))
        \"\"\"
        
        RÔLE DU PROFESSEUR MURAL :
        1. Tu agis comme un tuteur particulier expert sur le sujet du document.
        2. Tu aides l'élève à comprendre le texte, le vocabulaire technique ou spécialisé, et les concepts clés.
        3. Tu poses des questions de compréhension progressives et interactives (méthode socratique).
        4. Tu proposes des mini-quiz et des exercices de formulation orale / écrite basés sur les passages du document.
        5. Tu corriges avec bienveillance et précision toutes les erreurs de langue.
        
        Garde tes réponses dynamiques, interactives et adaptées au rythme de l'élève !
        """
    }

    public static func documentAnalysisPrompt(title: String, targetLanguage: String = "German") -> String {
        """
        Analyse le texte de ce document pour un apprenant en langue (\(targetLanguage)).
        Génère un résumé pédagogique, les concepts clés et 3-5 questions de vérification de compréhension.
        
        Format JSON strict attendu :
        {
          "summary": "Résumé clair et structuré en 2-3 paragraphes",
          "keyConcepts": [
            {
              "term": "Terme ou notion clé",
              "definition": "Définition simple et claire",
              "example": "Exemple d'utilisation dans la langue cible"
            }
          ],
          "quizQuestions": [
            {
              "question": "Question de compréhension sur le texte",
              "choices": ["Option A", "Option B", "Option C"],
              "correctAnswer": "Option A",
              "explanation": "Pourquoi c'est la bonne réponse"
            }
          ]
        }
        
        Réponds UNIQUEMENT avec le JSON valide.
        """
    }
}

// MARK: - Study Local Persistence Store

public final class StudyStoreManager: @unchecked Sendable {
    public static let shared = StudyStoreManager()
    
    private let lessonsFileURL: URL
    private let docsFileURL: URL
    
    public init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let muralDir = appSupport.appendingPathComponent("MuralStudy", isDirectory: true)
        try? fm.createDirectory(at: muralDir, withIntermediateDirectories: true)
        
        self.lessonsFileURL = muralDir.appendingPathComponent("assimil_lessons.json")
        self.docsFileURL = muralDir.appendingPathComponent("study_documents.json")
    }
    
    public func loadLessons() -> [AssimilLesson] {
        guard let data = try? Data(contentsOf: lessonsFileURL),
              let lessons = try? JSONDecoder().decode([AssimilLesson].self, from: data) else {
            return []
        }
        return lessons.sorted { $0.createdAt > $1.createdAt }
    }
    
    public func saveLesson(_ lesson: AssimilLesson) {
        var lessons = loadLessons()
        if let idx = lessons.firstIndex(where: { $0.id == lesson.id }) {
            lessons[idx] = lesson
        } else {
            lessons.insert(lesson, at: 0)
        }
        if let data = try? JSONEncoder().encode(lessons) {
            try? data.write(to: lessonsFileURL, options: .atomic)
        }
    }
    
    public func deleteLesson(id: UUID) {
        var lessons = loadLessons()
        lessons.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(lessons) {
            try? data.write(to: lessonsFileURL, options: .atomic)
        }
    }
    
    public func loadDocuments() -> [StudyDocument] {
        guard let data = try? Data(contentsOf: docsFileURL),
              let docs = try? JSONDecoder().decode([StudyDocument].self, from: data) else {
            return []
        }
        return docs.sorted { $0.createdAt > $1.createdAt }
    }
    
    public func saveDocument(_ doc: StudyDocument) {
        var docs = loadDocuments()
        if let idx = docs.firstIndex(where: { $0.id == doc.id }) {
            docs[idx] = doc
        } else {
            docs.insert(doc, at: 0)
        }
        if let data = try? JSONEncoder().encode(docs) {
            try? data.write(to: docsFileURL, options: .atomic)
        }
    }
    
    public func deleteDocument(id: UUID) {
        var docs = loadDocuments()
        docs.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(docs) {
            try? data.write(to: docsFileURL, options: .atomic)
        }
    }
}
