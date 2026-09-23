import Foundation
import PDFKit
import UniformTypeIdentifiers
import MuralCore

@MainActor
public final class DocumentImportManager {
    public static let shared = DocumentImportManager()
    
    // MARK: - Extract Content from Security-Scoped URL
    public func importFile(from url: URL, targetLanguageID: String = "de") async throws -> StudyDocument {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        
        var textContent = ""
        var pageCount = 1
        var detectedSource = "Fichiers iOS"
        
        if url.path.contains("Google Drive") || url.path.contains("com.google.Drive") {
            detectedSource = "Google Drive"
        }
        
        if ext == "pdf" {
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
        } else {
            // Text, Markdown, CSV, etc.
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
            summary: "Document importé avec succès (\(pageCount) page(s)).",
            targetLanguageID: targetLanguageID
        )
    }
    
    // MARK: - Analyze Document with AI
    public func analyzeDocument(
        document: inout StudyDocument,
        apiClient: APIClient,
        preferences: Preferences
    ) async throws {
        let targetLang = LanguageRegistry.module(for: document.targetLanguageID)?.name ?? "German"
        let instructions = DocumentTeacherPolicy.documentAnalysisPrompt(title: document.title, targetLanguage: targetLang)
        let sampleContent = String(document.rawContent.prefix(5000))
        let history = [
            ["role": "user", "content": "Document : \(document.title)\n\nContenu :\n\(sampleContent)"]
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
        }
    }
}

public enum DocumentImportError: LocalizedError {
    case cannotOpenPDF
    case unsupportedFormat
    case emptyFile
    
    public var errorDescription: String? {
        switch self {
        case .cannotOpenPDF: return "Impossible d'ouvrir ce fichier PDF ou le document est protégé."
        case .unsupportedFormat: return "Format de fichier non pris en charge. Veuillez choisir un PDF ou un fichier texte."
        case .emptyFile: return "Le fichier sélectionné ne contient aucun texte exploitable."
        }
    }
}
