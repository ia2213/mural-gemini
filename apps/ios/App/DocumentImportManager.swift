import Foundation
import UIKit
import PDFKit
import UniformTypeIdentifiers
import AuthenticationServices
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
        var importedItems: [(term: String, meaning: String, example: String)] = []
        
        if ext == "json" {
            let data = try Data(contentsOf: url)
            if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for item in array {
                    let term = item["term"] as? String ?? item["lemma"] as? String ?? item["front"] as? String ?? ""
                    let meaning = item["meaning"] as? String ?? item["back"] as? String ?? ""
                    let example = item["example"] as? String ?? ""
                    
                    if !term.isEmpty && !meaning.isEmpty {
                        importedItems.append((term: term.trimmingCharacters(in: .whitespacesAndNewlines), meaning: meaning.trimmingCharacters(in: .whitespacesAndNewlines), example: example.trimmingCharacters(in: .whitespacesAndNewlines)))
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
                        importedItems.append((term: front, meaning: back, example: example))
                    }
                }
            }
        }
        
        guard !importedItems.isEmpty else {
            throw DocumentImportError.emptyFile
        }
        
        var proposals: [WordProposal] = []
        for item in importedItems {
            let proposal = WordProposal(
                lemma: item.term,
                meaning: item.meaning,
                form: item.term,
                kind: .independent,
                confidence: 1.0,
                sourceIDs: [url.lastPathComponent],
                quote: item.example.isEmpty ? item.term : item.example,
                language: languageID
            )
            proposals.append(proposal)
            
            let fsrsItem = FSRSItem(
                term: item.term,
                meaning: item.meaning,
                example: item.example.isEmpty ? nil : item.example,
                contextCategory: "Anki / Drive",
                level: "A1",
                languageID: languageID
            )
            FSRSStoreManager.shared.saveItem(fsrsItem)
        }
        
        var importSession = SessionRecord(languageID: languageID, themeID: nil, title: "Import Anki / Drive (\(url.lastPathComponent))")
        importSession.endReason = "Import Anki / Google Drive (\(url.lastPathComponent))"
        let frag = Fragment(speaker: .assistant, text: "Importation Anki : \(importedItems.count) mots enregistrés.", startMS: 0, endMS: 1000)
        importSession.append(frag)
        let assessment = Assessment(
            passageID: frag.id,
            revisionKey: "1",
            outcome: .success,
            suggestedLevel: 1,
            nextGoal: "Pratique orale",
            capability: "Vocabulaire Anki",
            words: proposals
        )
        importSession.assessments.append(assessment)
        store.save(importSession)
        
        return importedItems.count
    }
}

// MARK: - Google Drive File Model
public struct GoogleDriveFile: Identifiable, Codable, Sendable {
    public var id: String
    public var name: String
    public var mimeType: String
    public var size: String?
    public var modifiedTime: String?
    
    public var isFolder: Bool {
        mimeType == "application/vnd.google-apps.folder"
    }
    
    public var iconName: String {
        if isFolder { return "folder.fill" }
        if mimeType.contains("pdf") { return "doc.richtext.fill" }
        if mimeType.contains("spreadsheet") || mimeType.contains("csv") { return "tablecells.fill" }
        if mimeType.contains("text") || mimeType.contains("json") { return "doc.text.fill" }
        if mimeType.contains("image") { return "photo.fill" }
        return "doc.fill"
    }
}

// MARK: - Google Drive Direct API Service
@MainActor
final class GoogleDriveDirectService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleDriveDirectService()
    
    @Published var isAuthenticated = false
    @Published var userEmail: String?
    @Published var files: [GoogleDriveFile] = []
    @Published var isLoading = false
    @Published var currentFolderID = "root"
    @Published var folderBreadcrumbs: [(id: String, name: String)] = [("root", "Mon Drive")]
    @Published var errorMessage: String?
    
    private let tokenKey = "FluenceGoogleDriveAccessToken"
    private let emailKey = "FluenceGoogleDriveUserEmail"
    private var accessToken: String?
    
    // Google OAuth Config
    private let clientId = "1055745422479-h0knfqn93sgh2gq0k12r6923j15d3i0b.apps.googleusercontent.com"
    private let redirectUri = "com.googleusercontent.apps.1055745422479-h0knfqn93sgh2gq0k12r6923j15d3i0b:/oauth2redirect"
    private let callbackScheme = "com.googleusercontent.apps.1055745422479-h0knfqn93sgh2gq0k12r6923j15d3i0b"
    
    override init() {
        super.init()
        if let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty {
            self.accessToken = token
            self.userEmail = UserDefaults.standard.string(forKey: emailKey)
            self.isAuthenticated = true
        }
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }
    
    // MARK: - OAuth 2.0 Sign-In
    func signIn() async throws {
        let scopes = [
            "https://www.googleapis.com/auth/drive.readonly",
            "https://www.googleapis.com/auth/userinfo.email",
            "https://www.googleapis.com/auth/userinfo.profile"
        ].joined(separator: " ")
        
        guard let encodedScopes = scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedRedirect = redirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let authURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientId)&redirect_uri=\(encodedRedirect)&response_type=token&scope=\(encodedScopes)&prompt=consent") else {
            throw DocumentImportError.cannotOpenFolder
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: self.callbackScheme) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: DocumentImportError.cannotOpenFolder)
                    return
                }
                
                // Parse access_token from URL fragment
                let fragment = callbackURL.fragment ?? callbackURL.query ?? ""
                let params = fragment.components(separatedBy: "&").reduce(into: [String: String]()) { dict, item in
                    let pair = item.components(separatedBy: "=")
                    if pair.count == 2 {
                        dict[pair[0]] = pair[1].removingPercentEncoding
                    }
                }
                
                if let token = params["access_token"], !token.isEmpty {
                    self.accessToken = token
                    UserDefaults.standard.set(token, forKey: self.tokenKey)
                    self.isAuthenticated = true
                    
                    Task { @MainActor in
                        await self.fetchUserInfo()
                        try? await self.fetchFiles(folderId: "root")
                    }
                    continuation.resume()
                } else {
                    continuation.resume(throwing: DocumentImportError.cannotOpenFolder)
                }
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }
    
    func signOut() {
        self.accessToken = nil
        self.userEmail = nil
        self.isAuthenticated = false
        self.files = []
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
    }
    
    // MARK: - Fetch User Profile Email
    private func fetchUserInfo() async {
        guard let token = accessToken, let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, _) = try? await URLSession.shared.data(for: request),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let email = obj["email"] as? String {
            self.userEmail = email
            UserDefaults.standard.set(email, forKey: emailKey)
        }
    }
    
    // MARK: - Fetch Files & Folders in Drive
    func fetchFiles(folderId: String = "root", search: String = "") async throws {
        guard let token = accessToken else { throw DocumentImportError.cannotOpenFolder }
        self.isLoading = true
        defer { self.isLoading = false }
        
        var query = "trashed = false"
        if !search.isEmpty {
            query += " and name contains '\(search.replacingOccurrences(of: "'", with: "\\'"))'"
        } else {
            query += " and '\(folderId)' in parents"
        }
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.googleapis.com/drive/v3/files?q=\(encodedQuery)&fields=files(id,name,mimeType,size,modifiedTime)&orderBy=folder,name&pageSize=100") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            signOut()
            throw DocumentImportError.cannotOpenFolder
        }
        
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let items = obj["files"] as? [[String: Any]] {
            self.files = items.compactMap { dict in
                guard let id = dict["id"] as? String, let name = dict["name"] as? String, let mime = dict["mimeType"] as? String else { return nil }
                let size = dict["size"] as? String
                let mod = dict["modifiedTime"] as? String
                return GoogleDriveFile(id: id, name: name, mimeType: mime, size: size, modifiedTime: mod)
            }
            self.currentFolderID = folderId
        }
    }
    
    // MARK: - Navigate Folder
    func openFolder(id: String, name: String) async {
        folderBreadcrumbs.append((id: id, name: name))
        try? await fetchFiles(folderId: id)
    }
    
    func navigateBackToBreadcrumb(index: Int) async {
        guard index < folderBreadcrumbs.count else { return }
        folderBreadcrumbs = Array(folderBreadcrumbs.prefix(index + 1))
        if let last = folderBreadcrumbs.last {
            try? await fetchFiles(folderId: last.id)
        }
    }
    
    // MARK: - Download File & Import to Fluence
    func downloadAndImport(file: GoogleDriveFile, store: LearningStore, targetLanguageID: String = "de") async throws -> Int {
        guard let token = accessToken else { throw DocumentImportError.cannotOpenFolder }
        self.isLoading = true
        defer { self.isLoading = false }
        
        let downloadURLString: String
        if file.mimeType.contains("google-apps.document") {
            downloadURLString = "https://www.googleapis.com/drive/v3/files/\(file.id)/export?mimeType=text/plain"
        } else if file.mimeType.contains("google-apps.spreadsheet") {
            downloadURLString = "https://www.googleapis.com/drive/v3/files/\(file.id)/export?mimeType=text/csv"
        } else {
            downloadURLString = "https://www.googleapis.com/drive/v3/files/\(file.id)?alt=media"
        }
        
        guard let url = URL(string: downloadURLString) else { throw DocumentImportError.cannotOpenFolder }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DocumentImportError.cannotOpenFolder
        }
        
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(file.name)
        try data.write(to: tempFile)
        
        return try await AnkiGoogleDriveManager.shared.importVocabulary(from: tempFile, store: store, languageID: targetLanguageID)
    }
    
    // MARK: - Import Direct Google Drive Link (Public or Shared)
    func importFromPublicLink(urlString: String, store: LearningStore, targetLanguageID: String = "de") async throws -> Int {
        var fileId = ""
        if let match = urlString.range(of: #"/d/([a-zA-Z0-9_-]+)"#, options: .regularExpression) {
            let substr = String(urlString[match])
            fileId = substr.replacingOccurrences(of: "/d/", with: "")
        } else if let match = urlString.range(of: #"id=([a-zA-Z0-9_-]+)"#, options: .regularExpression) {
            let substr = String(urlString[match])
            fileId = substr.replacingOccurrences(of: "id=", with: "")
        } else {
            fileId = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard !fileId.isEmpty else { throw DocumentImportError.cannotOpenFolder }
        
        let downloadURL = "https://drive.google.com/uc?export=download&id=\(fileId)"
        guard let url = URL(string: downloadURL) else { throw DocumentImportError.cannotOpenFolder }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard data.count > 10 else { throw DocumentImportError.emptyFile }
        
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("drive_import_\(fileId).txt")
        try data.write(to: tempFile)
        
        return try await AnkiGoogleDriveManager.shared.importVocabulary(from: tempFile, store: store, languageID: targetLanguageID)
    }
}
