import Foundation

// MARK: - CEFR Study Levels

public enum StudyLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case all = "all"
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case other = "Autre"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .all: return "Tous les niveaux"
        case .a1: return "Niveau A1 (Débutant)"
        case .a2: return "Niveau A2 (Élémentaire)"
        case .b1: return "Niveau B1 (Intermédiaire)"
        case .b2: return "Niveau B2 (Avancé / Médical)"
        case .c1: return "Niveau C1 (Autonome)"
        case .other: return "Non classé"
        }
    }
    
    public var shortLabel: String {
        switch self {
        case .all: return "Tous"
        case .a1: return "A1"
        case .a2: return "A2"
        case .b1: return "B1"
        case .b2: return "B2"
        case .c1: return "C1"
        case .other: return "Autre"
        }
    }
    
    public static func detect(from pathOrName: String) -> StudyLevel {
        let upper = pathOrName.uppercased()
        if upper.contains("B2") || upper.contains("NIVEAU B2") || upper.contains("LEVEL B2") { return .b2 }
        if upper.contains("B1") || upper.contains("NIVEAU B1") || upper.contains("LEVEL B1") { return .b1 }
        if upper.contains("A1") || upper.contains("NIVEAU A1") || upper.contains("LEVEL A1") { return .a1 }
        if upper.contains("A2") || upper.contains("NIVEAU A2") || upper.contains("LEVEL A2") { return .a2 }
        if upper.contains("C1") || upper.contains("NIVEAU C1") || upper.contains("LEVEL C1") { return .c1 }
        return .other
    }
}

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
    public var level: String
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
        level: String = "B2",
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
        self.level = level
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
    public var source: String // "Google Drive", "Fichiers iOS", "Dossier Niveau B2", "Texte / Note", "PDF"
    public var rawContent: String
    public var pageCount: Int
    public var summary: String
    public var targetLanguageID: String
    public var level: String // "A1", "A2", "B1", "B2", "C1", "Autre"
    public var folderName: String?
    public var fileType: String // "PDF", "Word", "PowerPoint", "Image / OCR", "Texte"
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
        level: String = "B2",
        folderName: String? = nil,
        fileType: String = "PDF",
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
        self.level = level
        self.folderName = folderName
        self.fileType = fileType
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
        Tu es le Professeur Fluence dédié à l'apprentissage selon la méthode Assimil.
        Langue cible enseignée : \(targetLang).
        Langue de support / explications : Français.
        Titre de la leçon : \(lesson.title) (Leçon \(lesson.lessonNumber.map(String.init) ?? "1") - Niveau \(lesson.level)).
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
        2. Quand tu parles en \(targetLang), utilise une formulation authentique et naturelle adaptée au niveau \(lesson.level).
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
          "level": "B2",
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

// MARK: - Interactive Q&A Course Tutor Policy ("Cours en Questions")

public enum CourseQAPolicy {
    public static func socraticCoursePrompt(
        document: StudyDocument,
        level: String,
        correctionLevel: String = "medium"
    ) -> String {
        let targetLang = LanguageRegistry.module(for: document.targetLanguageID)?.name ?? "German"
        
        return """
        Tu es le Professeur Fluence d'Allemand. Tu animes un COURS INTERACTIF EN QUESTIONS (méthode socratique et questions-réponses orales/écrites) basé sur le cours sélectionné.
        
        PARAMÈTRES DU COURS :
        - Document : « \(document.title) » (Dossier : \(document.folderName ?? "Général") • Format : \(document.fileType))
        - Niveau visé : \(level) (ex: B2 Allemand / Vocabulaire médical et quotidien)
        - Langue cible : \(targetLang)
        - Langue de guidage & explications : Français
        - Rigueur de correction : \(correctionLevel.uppercased())
        
        CONTENU DU COURS À ENSEIGNER :
        \"\"\"
        \(String(document.rawContent.prefix(8000)))
        \"\"\"
        
        MÉTHODE PÉDAGOGIQUE DU COURS EN QUESTIONS :
        1. **Pas de longs monologues passifs** : L'élève apprend en répondant à tes questions !
        2. **Déroulement d'une session** :
           - **Étape 1 : Question de mise en contexte** (Pose une première question en allemand ou en français sur un point clé du cours).
           - **Étape 2 : Analyse de la réponse de l'élève** :
             * Si la réponse est correcte : Félicite brièvement, donne une nuance ou un synonyme plus avancé de niveau \(level), puis pose la question suivante.
             * Si la réponse contient une erreur (grammaire, déclinaison, cas Akkusativ/Dativ, ordre des verbes, vocabulaire) : Explique clairement la règle en français avec bienveillance, donne la formulation correcte en \(targetLang), et demande-lui de reformuler ou pose une question d'application directe.
           - **Étape 3 : Progression structurée** : Aborde successivement le vocabulaire, la syntaxe des phrases complexes (weil, obwohl, dass, Konjunktiv, Passiv), et des mises en situation pratiques.
        
        3. **Format des interventions** :
           - Reste concis (2 à 4 phrases max par tour).
           - Termine TOUJOURS par une QUESTION CLAIRE à laquelle l'élève doit répondre.
        """
    }

    public static func levelFolderMasteryPrompt(
        level: String,
        documents: [StudyDocument],
        correctionLevel: String = "medium"
    ) -> String {
        let titles = documents.map { "• \($0.title) (\($0.fileType))" }.joined(separator: "\n")
        
        return """
        Tu es le Professeur Fluence en charge de l'entraînement intensif au niveau \(level).
        L'élève a sélectionné son dossier complet de cours de niveau \(level) comprenant :
        \(titles)
        
        MISSION :
        Anime un cours interactif complet en questions de niveau \(level). Interroge l'élève sur les notions clés réparties dans ces différents fichiers de cours. Valide ses réponses, corrige ses erreurs en direct et fais-le progresser à l'oral et à l'écrit !
        """
    }
}

public enum DocumentTeacherPolicy {
    public static func systemPrompt(doc: StudyDocument, mode: String = "interactive", correctionLevel: String = "medium") -> String {
        let targetLang = LanguageRegistry.module(for: doc.targetLanguageID)?.name ?? "German"
        
        return """
        Tu es le Professeur Fluence spécialisé dans l'apprentissage basé sur des documents et cours choisis par l'élève (provenant de Google Drive ou de ses fichiers).
        Langue cible d'apprentissage : \(targetLang).
        Langue d'échange : Français et \(targetLang).
        Titre du document : \(doc.title) (Source : \(doc.source) • Niveau : \(doc.level)).
        Niveau de correction : \(correctionLevel.uppercased()).
        
        CONTENU DU DOCUMENT ÉTUDIÉ :
        \"\"\"
        \(String(doc.rawContent.prefix(8000)))
        \"\"\"
        
        RÔLE DU PROFESSEUR FLUENCE :
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
          "level": "B2",
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
        let fluenceDir = appSupport.appendingPathComponent("FluenceStudy", isDirectory: true)
        try? fm.createDirectory(at: fluenceDir, withIntermediateDirectories: true)
        
        self.lessonsFileURL = fluenceDir.appendingPathComponent("assimil_lessons.json")
        self.docsFileURL = fluenceDir.appendingPathComponent("study_documents.json")
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
    
    public func saveDocuments(_ newDocs: [StudyDocument]) {
        var docs = loadDocuments()
        for doc in newDocs {
            if let idx = docs.firstIndex(where: { $0.id == doc.id || ($0.title == doc.title && $0.folderName == doc.folderName) }) {
                docs[idx] = doc
            } else {
                docs.insert(doc, at: 0)
            }
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

// MARK: - Pre-Built German Curriculum (A1 to B2)
public struct DefaultGermanCurriculum {
    public static func seedLessons() -> [AssimilLesson] {
        [
            // LESSON 1 (A1)
            AssimilLesson(
                lessonNumber: 1,
                title: "Premiers contacts et salutations",
                targetLanguageID: "de",
                nativeLanguageID: "fr",
                rawExtractedText: "Guten Tag! Wie heißen Sie? Ich heiße Marc.",
                dialogue: [
                    AssimilLine(lineIndex: 0, speaker: "Anna", targetText: "Guten Tag! Wie heißen Sie?", phonetic: "Gou-ten Tak! Vi haï-ssen zi?", nativeTranslation: "Bonjour ! Comment vous appelez-vous ?"),
                    AssimilLine(lineIndex: 1, speaker: "Marc", targetText: "Guten Tag! Ich heiße Marc. Und Sie?", phonetic: "Gou-ten Tak! Ikh haï-sse Marc. Ound zi?", nativeTranslation: "Bonjour ! Je m'appelle Marc. Et vous ?"),
                    AssimilLine(lineIndex: 2, speaker: "Anna", targetText: "Ich bin Anna. Freut mich, Sie kennenzulernen!", phonetic: "Ikh bin Anna. Froït mikh, zi ken-nen-tsou-ler-nen!", nativeTranslation: "Je suis Anna. Enchantée de faire votre connaissance !"),
                    AssimilLine(lineIndex: 3, speaker: "Marc", targetText: "Gleichfalls! Sprechen Sie Französisch?", phonetic: "Glaïkh-fals! Chpre-khen zi fran-tsœ-zich?", nativeTranslation: "De même ! Parlez-vous français ?"),
                    AssimilLine(lineIndex: 4, speaker: "Anna", targetText: "Ein bisschen, aber ich lerne lieber Deutsch mit Ihnen.", nativeTranslation: "Un peu, mais je préfère apprendre l'allemand avec vous.")
                ],
                grammarNotes: [
                    "« Sie » avec majuscule est la formule de politesse (vouvoiement).",
                    "Le verbe se place toujours en deuxième position dans une phrase déclarative principale.",
                    "« Freut mich » est la formule courante pour dire « enchanté(e) »."
                ],
                exercises: [
                    AssimilExercise(title: "Mise en pratique orale", instructions: "Traduisez ou répondez en allemand à haute voix.", items: [
                        AssimilExerciseItem(itemIndex: 0, prompt: "Comment dites-vous « Bonjour, je m'appelle Marc » ?", expectedAnswer: "Guten Tag, ich heiße Marc.", explanation: "Le verbe « heiße » s'accorde avec « ich »."),
                        AssimilExerciseItem(itemIndex: 1, prompt: "Comment demandez-vous poliment « Parlez-vous allemand ? »", expectedAnswer: "Sprechen Sie Deutsch?", explanation: "Inversion verbe-sujet pour la question fermée.")
                    ])
                ],
                level: "A1"
            ),
            
            // LESSON 2 (A1)
            AssimilLesson(
                lessonNumber: 2,
                title: "Commander au café et au restaurant",
                targetLanguageID: "de",
                nativeLanguageID: "fr",
                rawExtractedText: "Ich möchte bitte einen Kaffee und ein Wasser.",
                dialogue: [
                    AssimilLine(lineIndex: 0, speaker: "Kellner", targetText: "Guten Abend! Was möchten Sie bestellen?", nativeTranslation: "Bonsoir ! Que désirez-vous commander ?"),
                    AssimilLine(lineIndex: 1, speaker: "Marc", targetText: "Ich möchte bitte einen Kaffee und ein Glas Wasser.", nativeTranslation: "J'aimerais s'il vous plaît un café et un verre d'eau."),
                    AssimilLine(lineIndex: 2, speaker: "Kellner", targetText: "Mit Milch und Zucker?", nativeTranslation: "Avec du lait et du sucre ?"),
                    AssimilLine(lineIndex: 3, speaker: "Marc", targetText: "Nur mit ein wenig Milch, danke.", nativeTranslation: "Seulement avec un peu de lait, merci."),
                    AssimilLine(lineIndex: 4, speaker: "Marc", targetText: "Wir möchten bitte bezahlen. Zusammen oder getrennt?", nativeTranslation: "Nous aimerions payer s'il vous plaît. Ensemble ou séparément ?")
                ],
                grammarNotes: [
                    "« Ich möchte » (j'aimerais) est la formule polie indispensable pour commander.",
                    "L'accusatif masculin : « einen Kaffee » (der Kaffee ➔ einen Kaffee).",
                    "« Zusammen oder getrennt? » est la question rituelle en Allemagne pour payer."
                ],
                level: "A1"
            ),
            
            // LESSON 3 (A2)
            AssimilLesson(
                lessonNumber: 3,
                title: "Raconter sa journée et le passé (Perfekt)",
                targetLanguageID: "de",
                nativeLanguageID: "fr",
                rawExtractedText: "Heute habe ich viel gearbeitet und Deutsch gelernt.",
                dialogue: [
                    AssimilLine(lineIndex: 0, speaker: "Anna", targetText: "Wie war dein Tag heute, Marc?", nativeTranslation: "Comment était ta journée aujourd'hui, Marc ?"),
                    AssimilLine(lineIndex: 1, speaker: "Marc", targetText: "Sehr intensiv! Ich bin früh aufgestanden und habe den ganzen Tag gelernt.", nativeTranslation: "Très intense ! Je me suis levé tôt et j'ai étudié toute la journée."),
                    AssimilLine(lineIndex: 2, speaker: "Anna", targetText: "Hast du auch den Deutschkurs wiederholt?", nativeTranslation: "As-tu aussi révisé le cours d'allemand ?"),
                    AssimilLine(lineIndex: 3, speaker: "Marc", targetText: "Ja, ich habe neue Vokabeln mit Fluence geübt.", nativeTranslation: "Oui, j'ai exercé de nouveaux mots de vocabulaire avec Fluence.")
                ],
                grammarNotes: [
                    "Le parfait (Perfekt) se forme avec haben/sein + participe passé à la fin de la phrase.",
                    "Les verbes de mouvement ou de changement d'état utilisent « sein » (ich bin aufgestanden).",
                    "Le participe passé des verbes faibles commence par « ge- » et finit par « -t » (gearbeitet, gelernt)."
                ],
                level: "A2"
            ),
            
            // LESSON 4 (B1)
            AssimilLesson(
                lessonNumber: 4,
                title: "Exprimer son opinion et justifier son choix",
                targetLanguageID: "de",
                nativeLanguageID: "fr",
                rawExtractedText: "Meiner Meinung nach ist kontinuierliche Übung der Schlüssel zum Erfolg.",
                dialogue: [
                    AssimilLine(lineIndex: 0, speaker: "Anna", targetText: "Was hältst du von täglichem Sprechtraining?", nativeTranslation: "Que penses-tu de l'entraînement oral quotidien ?"),
                    AssimilLine(lineIndex: 1, speaker: "Marc", targetText: "Meiner Meinung nach ist das die effektivste Methode, weil man die Hemmungen abbaut.", nativeTranslation: "À mon avis, c'est la méthode la plus efficace, parce qu'on élimine les blocages."),
                    AssimilLine(lineIndex: 2, speaker: "Anna", targetText: "Da stimme ich dir vollkommen zu. Man muss einfach anfangen zu sprechen.", nativeTranslation: "Je suis entièrement d'accord avec toi. Il faut simplement commencer à parler.")
                ],
                grammarNotes: [
                    "« Meiner Meinung nach » (à mon avis) entraîne l'inversion verbe-sujet.",
                    "La conjonction subordonnée « weil » rejette le verbe conjugué tout à la fin de la proposition."
                ],
                level: "B1"
            ),
            
            // LESSON 5 (B2 Médical)
            AssimilLesson(
                lessonNumber: 5,
                title: "Communication médicale & Anamnèse patient (Assistenzarzt)",
                targetLanguageID: "de",
                nativeLanguageID: "fr",
                rawExtractedText: "Guten Tag, Herr Weber. Ich bin der Assistenzarzt. Was führt Sie zu uns?",
                dialogue: [
                    AssimilLine(lineIndex: 0, speaker: "Arzt", targetText: "Guten Tag, Herr Weber. Ich bin der zuständige Assistenzarzt. Was führt Sie zu uns?", nativeTranslation: "Bonjour Monsieur Weber. Je suis l'interne responsable. Qu'est-ce qui vous amène chez nous ?"),
                    AssimilLine(lineIndex: 1, speaker: "Patient", targetText: "Ich habe seit gestern starke stechende Kopfschmerzen und Schwindelgefühl.", nativeTranslation: "J'ai depuis hier de violents maux de tête lancinants et des vertiges."),
                    AssimilLine(lineIndex: 2, speaker: "Arzt", targetText: "Können Sie die Schmerzen auf einer Skala von eins bis zehn beschreiben?", nativeTranslation: "Pouvez-vous décrire la douleur sur une échelle de un à dix ?"),
                    AssimilLine(lineIndex: 3, speaker: "Patient", targetText: "Etwa bei sieben. Besonders bei Licht wird es schlimmer.", nativeTranslation: "Environ sept. C'est particulièrement pire avec la lumière."),
                    AssimilLine(lineIndex: 4, speaker: "Arzt", targetText: "Verstehe. Wir werden eine neurologische Untersuchung durchführen und die Vitalparameter überprüfen.", nativeTranslation: "Je comprends. Nous allons réaliser un examen neurologique et vérifier les paramètres vitaux.")
                ],
                grammarNotes: [
                    "Vocabulaire médical B2 : stechende Schmerzen (douleurs lancinantes), Schwindelgefühl (vertiges), Vitalparameter (paramètres vitaux).",
                    "Le vouvoiement et l'empathie professionnelle : « Verstehe. Wir werden... ».",
                    "Structure de l'anamnèse clinique en Allemagne / Suisse / Autriche."
                ],
                level: "B2"
            )
        ]
    }
    
    public static func seedVocabulary() -> [FSRSItem] {
        [
            // A1 Vocab
            FSRSItem(term: "Hallo", meaning: "bonjour / salut", example: "Hallo! Wie geht es dir?", contextCategory: "Salutations", level: "A1", languageID: "de"),
            FSRSItem(term: "Guten Tag", meaning: "bonjour (formel)", example: "Guten Tag, wie heißen Sie?", contextCategory: "Salutations", level: "A1", languageID: "de"),
            FSRSItem(term: "Danke schön", meaning: "merci beaucoup", example: "Danke schön für Ihre Hilfe.", contextCategory: "Politesse", level: "A1", languageID: "de"),
            FSRSItem(term: "Bitte sehr", meaning: "je vous en prie / de rien", example: "Bitte sehr, gern geschehen!", contextCategory: "Politesse", level: "A1", languageID: "de"),
            FSRSItem(term: "Ich heiße...", meaning: "je m'appelle...", example: "Ich heiße Marc.", contextCategory: "Présentation", level: "A1", languageID: "de"),
            FSRSItem(term: "Ich lerne Deutsch", meaning: "j'apprends l'allemand", example: "Ich lerne Deutsch mit Freude.", contextCategory: "Quotidien", level: "A1", languageID: "de"),
            FSRSItem(term: "der Kaffee", meaning: "le café", example: "Ich möchte einen Kaffee trinken.", contextCategory: "Restaurant", level: "A1", languageID: "de"),
            FSRSItem(term: "das Wasser", meaning: "l'eau", example: "Ein Glas Wasser, bitte.", contextCategory: "Restaurant", level: "A1", languageID: "de"),
            FSRSItem(term: "die Rechnung", meaning: "l'addition / la facture", example: "Die Rechnung, bitte!", contextCategory: "Restaurant", level: "A1", languageID: "de"),
            FSRSItem(term: "Sprechen Sie Französisch?", meaning: "parlez-vous français ?", example: "Entschuldigung, sprechen Sie Französisch?", contextCategory: "Communication", level: "A1", languageID: "de"),
            
            // A2 Vocab
            FSRSItem(term: "aufstehen", meaning: "se lever", example: "Ich bin um 7 Uhr aufgestanden.", contextCategory: "Routine", level: "A2", languageID: "de"),
            FSRSItem(term: "arbeiten", meaning: "travailler", example: "Er hat heute viel gearbeitet.", contextCategory: "Travail", level: "A2", languageID: "de"),
            FSRSItem(term: "der Termin", meaning: "le rendez-vous", example: "Ich habe einen Termin beim Arzt.", contextCategory: "Santé", level: "A2", languageID: "de"),
            FSRSItem(term: "die Wohnung", meaning: "l'appartement", example: "Die Wohnung hat drei Zimmer.", contextCategory: "Logement", level: "A2", languageID: "de"),
            FSRSItem(term: "der Bahnhof", meaning: "la gare", example: "Wo ist der Hauptbahnhof?", contextCategory: "Transport", level: "A2", languageID: "de"),
            
            // B1 Vocab
            FSRSItem(term: "meiner Meinung nach", meaning: "à mon avis", example: "Meiner Meinung nach ist das wichtig.", contextCategory: "Opinion", level: "B1", languageID: "de"),
            FSRSItem(term: "zustimmen", meaning: "être d'accord / approuver", example: "Ich stimme dir vollkommen zu.", contextCategory: "Débat", level: "B1", languageID: "de"),
            FSRSItem(term: "die Erfahrung", meaning: "l'expérience", example: "Ich habe viel klinische Erfahrung.", contextCategory: "Professionnel", level: "B1", languageID: "de"),
            FSRSItem(term: "die Bewerbung", meaning: "la candidature", example: "Ich schicke meine Bewerbung als Assistenzarzt.", contextCategory: "Emploi", level: "B1", languageID: "de"),
            
            // B2 Médical Vocab
            FSRSItem(term: "der Assistenzarzt", meaning: "médecin assistant / interne", example: "Ich bewerbe mich als Assistenzarzt für Neurochirurgie.", contextCategory: "Médecine", level: "B2", languageID: "de"),
            FSRSItem(term: "die Anamnese", meaning: "l'anamnèse (histoire médicale du patient)", example: "Wir erheben die Anamnese des Patienten.", contextCategory: "Médecine", level: "B2", languageID: "de"),
            FSRSItem(term: "die Kopfschmerzen", meaning: "maux de tête / céphalées", example: "Der Patient klagt über starke Kopfschmerzen.", contextCategory: "Symptômes", level: "B2", languageID: "de"),
            FSRSItem(term: "das Schwindelgefühl", meaning: "sensation de vertige", example: "Haben Sie auch Schwindelgefühl?", contextCategory: "Symptômes", level: "B2", languageID: "de"),
            FSRSItem(term: "die Untersuchung", meaning: "l'examen clinique / exploration", example: "Die körperliche Untersuchung ist unauffällig.", contextCategory: "Clinique", level: "B2", languageID: "de"),
            FSRSItem(term: "die Behandlung", meaning: "le traitement / la prise en charge", example: "Die Behandlung schlägt gut an.", contextCategory: "Thérapeutique", level: "B2", languageID: "de")
        ]
    }
}
