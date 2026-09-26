import Foundation
import UIKit
import PDFKit
import UniformTypeIdentifiers
import MuralCore

@MainActor
final class DocumentImportManager {
    static let shared = DocumentImportManager()
    
    // MARK: - Import Entire Folder (Recursive Scan with Levels)
    func importFolder(from folderURL: URL, targetLanguageID: String = "de") async throws -> [StudyDocument] {
        let isSecurityScoped = folderURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let rootFolderName = folderURL.lastPathComponent
        var documents: [StudyDocument] = []
        let fileManager = FileManager.default
        
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .nameKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw DocumentImportError.cannotOpenFolder
        }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  let isRegular = resourceValues.isRegularFile, isRegular else {
                continue
            }
            
            let ext = fileURL.pathExtension.lowercased()
            guard Self.supportedExtensions.contains(ext) else {
                continue
            }
            
            // Extract text from this individual file
            if let doc = try? await extractDocument(from: fileURL, parentFolder: rootFolderName, targetLanguageID: targetLanguageID) {
                documents.append(doc)
            }
        }
        
        guard !documents.isEmpty else {
            throw DocumentImportError.emptyFolder
        }
        
        return documents
    }
    
    // MARK: - Extract Single File (Universal Format Support)
    func importFile(from url: URL, targetLanguageID: String = "de") async throws -> StudyDocument {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return try await extractDocument(from: url, parentFolder: nil, targetLanguageID: targetLanguageID)
    }
    
    private func extractDocument(from url: URL, parentFolder: String?, targetLanguageID: String) async throws -> StudyDocument {
        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let pathString = url.path
        
        var textContent = ""
        var pageCount = 1
        var detectedFormat = "Texte"
        var detectedSource = parentFolder != nil ? "Dossier : \(parentFolder!)" : "Fichiers iOS"
        
        if pathString.contains("Google Drive") || pathString.contains("com.google.Drive") {
            detectedSource = "Google Drive"
        }
        
        // Auto-detect Level from filename and folder path
        let detectedLevel = StudyLevel.detect(from: "\(pathString)/\(filename)").rawValue
        
        switch ext {
        case "pdf":
            detectedFormat = "PDF"
            guard let pdfDoc = PDFDocument(url: url) else {
                throw DocumentImportError.cannotOpenPDF
            }
            pageCount = pdfDoc.pageCount
            var pagesText: [String] = []
            for i in 0..<pdfDoc.pageCount {
                if let page = pdfDoc.page(at: i), let pageString = page.string {
                    let clean = pageString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        pagesText.append("--- Page \(i + 1) ---\n" + clean)
                    }
                }
            }
            textContent = pagesText.joined(separator: "\n\n")
            
        case "docx", "doc", "rtf", "rtfd", "html", "htm":
            detectedFormat = ext.uppercased()
            if let attributed = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
                textContent = attributed.string
            } else if let raw = try? String(contentsOf: url, encoding: .utf8) {
                textContent = raw
            } else if let raw = try? String(contentsOf: url, encoding: .isoLatin1) {
                textContent = raw
            }
            
        case "png", "jpg", "jpeg", "webp", "heic":
            detectedFormat = "Image (OCR)"
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                textContent = try await VisionOCRManager.shared.extractTextWithVision(from: img, targetLanguageCode: targetLanguageID)
            }
            
        case "epub":
            detectedFormat = "ePub"
            if let raw = try? String(contentsOf: url, encoding: .utf8) {
                textContent = raw
            }
            
        default: // txt, md, markdown, json, csv, tsv, xml
            detectedFormat = ext.isEmpty ? "Texte" : ext.uppercased()
            if let str = try? String(contentsOf: url, encoding: .utf8) {
                textContent = str
            } else if let str = try? String(contentsOf: url, encoding: .isoLatin1) {
                textContent = str
            } else {
                throw DocumentImportError.unsupportedFormat
            }
        }
        
        guard !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DocumentImportError.emptyFile
        }
        
        let title = filename.replacingOccurrences(of: ".\(ext)", with: "")
        
        return StudyDocument(
            title: title,
            source: detectedSource,
            rawContent: textContent,
            pageCount: pageCount,
            summary: "Document de cours importé (\(detectedFormat) • Niveau \(detectedLevel)).",
            targetLanguageID: targetLanguageID,
            level: detectedLevel,
            folderName: parentFolder,
            fileType: detectedFormat
        )
    }
    
    // MARK: - Analyze Document with AI
    func analyzeDocument(
        document: inout StudyDocument,
        apiClient: APIClient,
        preferences: Preferences
    ) async throws {
        let targetLang = LanguageRegistry.module(for: document.targetLanguageID)?.name ?? "German"
        let instructions = DocumentTeacherPolicy.documentAnalysisPrompt(title: document.title, targetLanguage: targetLang)
        let sampleContent = String(document.rawContent.prefix(5000))
        let history = [
            ["role": "user", "content": "Document : \(document.title)\nNiveau suggéré : \(document.level)\n\nContenu :\n\(sampleContent)"]
        ]
        
        let result = try await apiClient.respondHistory(instructions: instructions, history: history, preferences: preferences)
        
        var cleanJSON = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanJSON.hasPrefix("```json") { cleanJSON = cleanJSON.replacingOccurrences(of: "```json", with: "") }
        if cleanJSON.hasPrefix("```") { cleanJSON = cleanJSON.replacingOccurrences(of: "```", with: "") }
        cleanJSON = cleanJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let data = cleanJSON.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            if let summary = dict["summary"] as? String {
                document.summary = summary
            }
            if let lvl = dict["level"] as? String, !lvl.isEmpty {
                document.level = lvl
            }
            
            if let rawConcepts = dict["keyConcepts"] as? [[String: Any]] {
                var concepts: [StudyConcept] = []
                for item in rawConcepts {
                    let term = item["term"] as? String ?? ""
                    let def = item["definition"] as? String ?? ""
                    let ex = item["example"] as? String
                    if !term.isEmpty {
                        concepts.append(StudyConcept(term: term, definition: def, example: ex))
                    }
                }
                document.keyConcepts = concepts
            }
            
            if let rawQuiz = dict["quizQuestions"] as? [[String: Any]] {
                var questions: [StudyQuizQuestion] = []
                for item in rawQuiz {
                    let q = item["question"] as? String ?? ""
                    let choices = item["choices"] as? [String]
                    let answer = item["correctAnswer"] as? String ?? ""
                    let exp = item["explanation"] as? String
                    if !q.isEmpty {
                        questions.append(StudyQuizQuestion(question: q, choices: choices, correctAnswer: answer, explanation: exp))
                    }
                }
                document.quizQuestions = questions
            }
            
            // Index into Vector Store using Gemini text-embedding-004
            let googleKey = preferences.googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !googleKey.isEmpty {
                let docToIndex = document
                Task.detached {
                    try? await GeminiEmbeddingManager.shared.indexDocument(docToIndex, apiKey: googleKey)
                }
            }
        }
    }
    
    private static let supportedExtensions: Set<String> = [
        "pdf", "docx", "doc", "rtf", "rtfd", "txt", "md", "markdown",
        "epub", "html", "htm", "png", "jpg", "jpeg", "webp", "heic",
        "json", "csv", "tsv", "pptx", "xlsx"
    ]
}

public enum DocumentImportError: LocalizedError {
    case cannotOpenFolder
    case cannotOpenPDF
    case unsupportedFormat
    case emptyFile
    case emptyFolder
    
    public var errorDescription: String? {
        switch self {
        case .cannotOpenFolder: return "Impossible d'accéder à ce dossier. Vérifiez les autorisations."
        case .cannotOpenPDF: return "Impossible d'ouvrir ce fichier PDF ou le document est protégé."
        case .unsupportedFormat: return "Format de fichier non pris en charge."
        case .emptyFile: return "Le fichier sélectionné ne contient aucun texte exploitable."
        case .emptyFolder: return "Ce dossier ne contient aucun fichier de cours pris en charge."
        }
    }
}

// MARK: - Anki & Google Drive Sync Manager
@MainActor
final class AnkiGoogleDriveManager {
    static let shared = AnkiGoogleDriveManager()
    
    // MARK: - Export to Anki TSV (Deck File)
    func exportToAnkiTSV(words: [WordState], language: String = "Allemand") -> URL? {
        var lines: [String] = [
            "#separator:tab",
            "#html:true",
            "#tags column:4"
        ]
        
        let tag = "Fluence::\(language.replacingOccurrences(of: " ", with: "_"))"
        
        for word in words {
            let front = word.lemma.replacingOccurrences(of: "\t", with: " ")
            let back = word.meaning.replacingOccurrences(of: "\t", with: " ")
            let example = word.example.isEmpty ? "" : "<i>« \(word.example.replacingOccurrences(of: "\t", with: " ")) »</i>"
            let explanation = word.explanation.isEmpty ? "" : "<br><small>\(word.explanation.replacingOccurrences(of: "\t", with: " "))</small>"
            
            let backField = "\(back)\(explanation)\(example.isEmpty ? "" : "<br>" + example)"
            lines.append("\(front)\t\(backField)\t\(word.example)\t\(tag)")
        }
        
        let content = lines.joined(separator: "\n")
        let filename = "Fluence_\(language)_Anki_Deck.txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to write Anki export:", error)
            return nil
        }
    }
    
    // MARK: - Export to JSON (Google Drive & Backup)
    func exportToJSON(words: [WordState], language: String = "Allemand") -> URL? {
        let exportData: [[String: Any]] = words.map { word in
            [
                "term": word.lemma,
                "meaning": word.meaning,
                "example": word.example,
                "explanation": word.explanation,
                "level": word.label,
                "independentCount": word.independentCount,
                "lastSeen": ISO8601DateFormatter().string(from: word.lastSeen),
                "language": language
            ]
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted) else {
            return nil
        }
        
        let filename = "Fluence_\(language)_Vocabulaire_Drive.json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to write JSON export:", error)
            return nil
        }
    }
    
    // MARK: - Import from Anki / Drive / CSV / TXT / JSON
    func importVocabulary(from url: URL, store: LearningStore, languageID: String = "de") async throws -> Int {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let ext = url.pathExtension.lowercased()
        var importedCount = 0
        
        if ext == "json" {
            let data = try Data(contentsOf: url)
            if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for item in array {
                    let term = item["term"] as? String ?? item["lemma"] as? String ?? item["front"] as? String ?? ""
                    let meaning = item["meaning"] as? String ?? item["back"] as? String ?? ""
                    let example = item["example"] as? String ?? ""
                    let explanation = item["explanation"] as? String ?? ""
                    
                    if !term.isEmpty && !meaning.isEmpty {
                        let proposal = WordProposal(
                            lemma: term.trimmingCharacters(in: .whitespacesAndNewlines),
                            meaning: meaning.trimmingCharacters(in: .whitespacesAndNewlines),
                            form: term,
                            kind: .vocabulary,
                            confidence: 1.0,
                            sourceIDs: [url.lastPathComponent],
                            quote: example.isEmpty ? term : example,
                            language: languageID
                        )
                        store.propose(proposal)
                        FSRSStoreManager.shared.addOrUpdateItem(term: term, meaning: meaning, languageID: languageID)
                        importedCount += 1
                    }
                }
            }
        } else {
            // Text / TSV / CSV Parsing
            let content: String
            if let str = try? String(contentsOf: url, encoding: .utf8) {
                content = str
            } else if let str = try? String(contentsOf: url, encoding: .isoLatin1) {
                content = str
            } else {
                throw DocumentImportError.emptyFile
            }
            
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                
                // Determine delimiter: Tab, Semicolon, or Comma
                let delimiter: Character
                if trimmed.contains("\t") { delimiter = "\t" }
                else if trimmed.contains(";") { delimiter = ";" }
                else if trimmed.contains(",") { delimiter = "," }
                else { continue }
                
                let parts = trimmed.split(separator: delimiter, maxSplits: 4, omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                if parts.count >= 2 {
                    let rawFront = parts[0]
                    let rawBack = parts[1]
                    let example = parts.count >= 3 ? parts[2] : ""
                    
                    // Strip HTML tags like <b>, <i>, <br>
                    let front = rawFront.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                    let back = rawBack.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !front.isEmpty && !back.isEmpty {
                        let proposal = WordProposal(
                            lemma: front,
                            meaning: back,
                            form: front,
                            kind: .vocabulary,
                            confidence: 1.0,
                            sourceIDs: [url.lastPathComponent],
                            quote: example.isEmpty ? front : example,
                            language: languageID
                        )
                        store.propose(proposal)
                        FSRSStoreManager.shared.addOrUpdateItem(term: front, meaning: back, languageID: languageID)
                        importedCount += 1
                    }
                }
            }
        }
        
        guard importedCount > 0 else {
            throw DocumentImportError.emptyFile
        }
        
        return importedCount
    }
}
