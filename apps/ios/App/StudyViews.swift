import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import MuralCore

// MARK: - Camera Picker Representable
struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Main Study Hub View
struct StudyHubView: View {
    @Bindable var coordinator: ConversationCoordinator
    @State private var lessons: [AssimilLesson] = []
    @State private var documents: [StudyDocument] = []
    
    @State private var showScanner = false
    @State private var showDocImporter = false
    @State private var activeAssimilLesson: AssimilLesson?
    @State private var activeDocument: StudyDocument?
    
    private let storeManager = StudyStoreManager.shared

    init(coordinator: ConversationCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Card
                headerSection
                
                // Quick Action Cards
                quickActionsSection
                
                // Assimil Lessons Section
                assimilSection
                
                // Documents Section
                documentsSection
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(MuralColor.cream)
        .navigationTitle("Professeur & Assimil")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reloadContent()
        }
        .sheet(isPresented: $showScanner, onDismiss: { reloadContent() }) {
            AssimilScannerView(coordinator: coordinator) { newLesson in
                storeManager.saveLesson(newLesson)
                reloadContent()
                activeAssimilLesson = newLesson
            }
        }
        .sheet(isPresented: $showDocImporter, onDismiss: { reloadContent() }) {
            DocumentImportView(coordinator: coordinator) { newDoc in
                storeManager.saveDocument(newDoc)
                reloadContent()
                activeDocument = newDoc
            }
        }
        .fullScreenCover(item: $activeAssimilLesson, onDismiss: { reloadContent() }) { lesson in
            AssimilTeacherSessionView(lesson: lesson, coordinator: coordinator)
        }
        .fullScreenCover(item: $activeDocument, onDismiss: { reloadContent() }) { doc in
            DocumentTeacherSessionView(document: doc, coordinator: coordinator)
        }
    }
    
    private func reloadContent() {
        lessons = storeManager.loadLessons()
        documents = storeManager.loadDocuments()
    }

    // MARK: - Sections
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "graduationcap.fill")
                    .font(.title)
                    .foregroundStyle(MuralColor.orange)
                Text("Professeur Particulier")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(MuralColor.ink)
            }
            Text("Étudiez vos cours Google Drive ou vos leçons du livre Assimil scannées. Mural vous guide pas à pas avec explications, répétition vocale et corrections interactives.")
                .font(.subheadline)
                .foregroundStyle(MuralColor.secondary)
                .lineSpacing(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }

    private var quickActionsSection: some View {
        HStack(spacing: 14) {
            // Scanner Assimil
            Button {
                showScanner = true
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.92, blue: 0.82))
                            .frame(width: 44, height: 44)
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(MuralColor.orange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scanner Assimil")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(MuralColor.ink)
                        Text("Photo de livre & OCR")
                            .font(.caption2)
                            .foregroundStyle(MuralColor.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
            }
            .buttonStyle(.plain)

            // Google Drive / Fichiers
            Button {
                showDocImporter = true
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.88, green: 0.94, blue: 1.0))
                            .frame(width: 44, height: 44)
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.blue)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Google Drive")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(MuralColor.ink)
                        Text("PDF & Fichiers de cours")
                            .font(.caption2)
                            .foregroundStyle(MuralColor.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    private var assimilSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Leçons Assimil Scannées", systemImage: "book.pages")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(MuralColor.ink)
                Spacer()
                Text("\(lessons.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(MuralColor.butter.opacity(0.8), in: Capsule())
            }

            if lessons.isEmpty {
                emptyPlaceholder(
                    icon: "camera.badge.ellipsis",
                    title: "Aucune leçon scannée",
                    subtitle: "Prenez en photo une page de votre méthode Assimil pour démarrer."
                )
            } else {
                ForEach(lessons) { lesson in
                    Button {
                        activeAssimilLesson = lesson
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(MuralColor.orange.opacity(0.15))
                                    .frame(width: 46, height: 46)
                                Text(lesson.lessonNumber.map { "\($0)" } ?? "📖")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(MuralColor.orange)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(lesson.title)
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .foregroundStyle(MuralColor.ink)
                                    .lineLimit(1)
                                HStack(spacing: 8) {
                                    Text("\(lesson.dialogue.count) répliques")
                                    Text("•")
                                    Text("\(lesson.exercises.count) exercices")
                                }
                                .font(.caption2)
                                .foregroundStyle(MuralColor.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(MuralColor.secondary)
                        }
                        .padding(14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.black.opacity(0.02), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            storeManager.deleteLesson(id: lesson.id)
                            reloadContent()
                        } label: {
                            Label("Supprimer cette leçon", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Documents Google Drive & Cours", systemImage: "doc.text")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(MuralColor.ink)
                Spacer()
                Text("\(documents.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15), in: Capsule())
            }

            if documents.isEmpty {
                emptyPlaceholder(
                    icon: "doc.badge.plus",
                    title: "Aucun document importé",
                    subtitle: "Importez un fichier PDF ou texte depuis Google Drive ou vos fichiers locaux."
                )
            } else {
                ForEach(documents) { doc in
                    Button {
                        activeDocument = doc
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 46, height: 46)
                                Image(systemName: "doc.richtext")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.blue)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(doc.title)
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .foregroundStyle(MuralColor.ink)
                                    .lineLimit(1)
                                HStack(spacing: 8) {
                                    Text(doc.source)
                                    Text("•")
                                    Text("\(doc.pageCount) page(s)")
                                }
                                .font(.caption2)
                                .foregroundStyle(MuralColor.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(MuralColor.secondary)
                        }
                        .padding(14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.black.opacity(0.02), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            storeManager.deleteDocument(id: doc.id)
                            reloadContent()
                        } label: {
                            Label("Supprimer ce document", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func emptyPlaceholder(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(MuralColor.secondary.opacity(0.7))
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(MuralColor.ink)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(MuralColor.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Assimil Scanner View
struct AssimilScannerView: View {
    let coordinator: ConversationCoordinator
    let onSave: (AssimilLesson) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isProcessing = false
    @State private var processingStatus = ""
    @State private var errorMessage: String?
    
    @State private var parsedLesson: AssimilLesson?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let parsedLesson = parsedLesson {
                        lessonPreviewSection(parsedLesson)
                    } else if let image = selectedImage {
                        imagePreviewSection(image)
                    } else {
                        captureOptionsSection
                    }
                }
                .padding(20)
            }
            .background(MuralColor.cream)
            .navigationTitle("Scanner Assimil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                if let lesson = parsedLesson {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Enregistrer") {
                            onSave(lesson)
                            dismiss()
                        }
                        .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView(selectedImage: $selectedImage)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run {
                            self.selectedImage = img
                        }
                    }
                }
            }
        }
    }

    private var captureOptionsSection: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(MuralColor.orange)
                .padding(.top, 20)
            
            Text("Photographiez votre page Assimil")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(MuralColor.ink)
            
            Text("L'OCR extrait automatiquement le dialogue bilingue, les remarques de grammaire et les exercices pour votre cours.")
                .font(.subheadline)
                .foregroundStyle(MuralColor.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Prendre une photo", systemImage: "camera.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(MuralColor.orange, in: RoundedRectangle(cornerRadius: 14))
                }
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choisir depuis la galerie", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .foregroundStyle(MuralColor.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func imagePreviewSection(_ image: UIImage) -> some View {
        VStack(spacing: 18) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(radius: 4)

            if isProcessing {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(MuralColor.orange)
                    Text(processingStatus)
                        .font(.caption)
                        .foregroundStyle(MuralColor.secondary)
                }
                .padding(.vertical, 10)
            } else {
                HStack(spacing: 14) {
                    Button("Reprendre") {
                        selectedImage = nil
                    }
                    .font(.subheadline)
                    .foregroundStyle(MuralColor.secondary)
                    
                    Button {
                        processImage(image)
                    } label: {
                        Text("Analyser la leçon (OCR)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(MuralColor.orange, in: Capsule())
                    }
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func lessonPreviewSection(_ lesson: AssimilLesson) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("Leçon \(lesson.lessonNumber.map(String.init) ?? "1") • \(lesson.dialogue.count) phrases")
                        .font(.caption)
                        .foregroundStyle(MuralColor.secondary)
                }
                Spacer()
                Button("Re-scanner") {
                    parsedLesson = nil
                    selectedImage = nil
                }
                .font(.caption)
            }

            Divider()

            Text("Dialogue Extrait")
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(lesson.dialogue) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Text("\(line.lineIndex).")
                                .font(.caption.bold())
                                .foregroundStyle(MuralColor.orange)
                            Text(line.targetText)
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .foregroundStyle(MuralColor.ink)
                            Spacer()
                        }
                        Text(line.nativeTranslation)
                            .font(.caption)
                            .foregroundStyle(MuralColor.secondary)
                            .padding(.leading, 18)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MuralColor.cream.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            if !lesson.grammarNotes.isEmpty {
                Divider()
                Text("Remarques & Grammaire")
                    .font(.headline)
                ForEach(lesson.grammarNotes, id: \.self) { note in
                    Text("• " + note)
                        .font(.caption)
                        .foregroundStyle(MuralColor.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func processImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        processingStatus = "Extraction du texte par OCR..."

        Task {
            do {
                let targetLang = coordinator.language.name
                let lesson: AssimilLesson
                
                // Try Gemini Vision if API key exists, otherwise local Apple Vision + LLM
                let googleKey = coordinator.store.preferences.googleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                if !googleKey.isEmpty {
                    await MainActor.run { processingStatus = "Analyse multimodale Gemini 2.0 Flash..." }
                    lesson = try await VisionOCRManager.shared.extractAndParseWithGemini(
                        image: image,
                        apiClient: coordinator.apiClient,
                        preferences: coordinator.store.preferences,
                        targetLanguage: targetLang
                    )
                } else {
                    await MainActor.run { processingStatus = "OCR Apple Vision en cours..." }
                    let rawText = try await VisionOCRManager.shared.extractTextWithVision(from: image, targetLanguageCode: coordinator.store.preferences.learningLanguageID)
                    await MainActor.run { processingStatus = "Structuration de la leçon..." }
                    lesson = try await VisionOCRManager.shared.structureRawTextIntoLesson(
                        rawText: rawText,
                        apiClient: coordinator.apiClient,
                        preferences: coordinator.store.preferences,
                        targetLanguage: targetLang
                    )
                }
                
                await MainActor.run {
                    self.parsedLesson = lesson
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }
}

// MARK: - Document Import View (Google Drive & Local Files)
struct DocumentImportView: View {
    let coordinator: ConversationCoordinator
    let onSave: (StudyDocument) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showFilePicker = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    @State private var pastedTitle = ""
    @State private var pastedContent = ""
    @State private var selectedDoc: StudyDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let doc = selectedDoc {
                        docPreviewSection(doc)
                    } else {
                        importOptionsSection
                    }
                }
                .padding(20)
            }
            .background(MuralColor.cream)
            .navigationTitle("Importer un Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                if let doc = selectedDoc {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Enregistrer") {
                            onSave(doc)
                            dismiss()
                        }
                        .fontWeight(.bold)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .plainText, .text, .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }

    private var importOptionsSection: some View {
        VStack(spacing: 20) {
            // Google Drive / Files button
            VStack(spacing: 14) {
                Image(systemName: "folder.badge.gearshape.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Color.blue)
                
                Text("Google Drive & Fichiers iOS")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(MuralColor.ink)
                
                Text("Sélectionnez vos fichiers de cours (PDF, Notes, Fichiers texte) depuis votre compte Google Drive ou vos dossiers locaux.")
                    .font(.subheadline)
                    .foregroundStyle(MuralColor.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                Button {
                    showFilePicker = true
                } label: {
                    Label("Choisir un fichier (Google Drive / PDF)", systemImage: "arrow.down.doc.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(22)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18))

            // Paste text option
            VStack(alignment: .leading, spacing: 12) {
                Text("Ou coller un texte de cours :")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(MuralColor.ink)
                
                TextField("Titre du cours / leçon", text: $pastedTitle)
                    .padding(12)
                    .background(MuralColor.cream, in: RoundedRectangle(cornerRadius: 10))
                
                TextField("Collez le texte du cours ici...", text: $pastedContent, axis: .vertical)
                    .lineLimit(4...8)
                    .padding(12)
                    .background(MuralColor.cream, in: RoundedRectangle(cornerRadius: 10))
                
                Button {
                    createFromPastedText()
                } label: {
                    Text("Valider ce texte")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(MuralColor.ink, in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(pastedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18))

            if isProcessing {
                ProgressView("Analyse pédagogique du document par l'IA...")
                    .font(.caption)
                    .tint(Color.blue)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func docPreviewSection(_ doc: StudyDocument) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text("Source: \(doc.source) • \(doc.pageCount) page(s)")
                    .font(.caption)
                    .foregroundStyle(MuralColor.secondary)
            }

            Divider()

            Text("Résumé du Professeur")
                .font(.headline)
            Text(doc.summary)
                .font(.subheadline)
                .foregroundStyle(MuralColor.secondary)
                .lineSpacing(3)

            if !doc.keyConcepts.isEmpty {
                Divider()
                Text("Concepts Clés Extraits")
                    .font(.headline)
                ForEach(doc.keyConcepts) { concept in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(concept.term)
                            .font(.subheadline.bold())
                            .foregroundStyle(MuralColor.ink)
                        Text(concept.definition)
                            .font(.caption)
                            .foregroundStyle(MuralColor.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MuralColor.cream.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isProcessing = true
            errorMessage = nil
            Task {
                do {
                    var doc = try await DocumentImportManager.shared.importFile(
                        from: url,
                        targetLanguageID: coordinator.store.preferences.learningLanguageID
                    )
                    try await DocumentImportManager.shared.analyzeDocument(
                        document: &doc,
                        apiClient: coordinator.apiClient,
                        preferences: coordinator.store.preferences
                    )
                    await MainActor.run {
                        self.selectedDoc = doc
                        self.isProcessing = false
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isProcessing = false
                    }
                }
            }
        case .failure(let error):
            self.errorMessage = error.localizedDescription
        }
    }

    private func createFromPastedText() {
        let title = pastedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Notes de cours" : pastedTitle
        var doc = StudyDocument(
            title: title,
            source: "Texte / Note",
            rawContent: pastedContent,
            targetLanguageID: coordinator.store.preferences.learningLanguageID
        )
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                try await DocumentImportManager.shared.analyzeDocument(
                    document: &doc,
                    apiClient: coordinator.apiClient,
                    preferences: coordinator.store.preferences
                )
                await MainActor.run {
                    self.selectedDoc = doc
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                }
            }
        }
    }
}

// MARK: - Assimil Teacher Session View (Interactive Tutor)
struct AssimilTeacherSessionView: View {
    let lesson: AssimilLesson
    let coordinator: ConversationCoordinator
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: String = "dialogue" // dialogue, grammar, exercises, conversation
    @State private var selectedLineIndex: Int = 0
    
    @State private var teacherMessage: String = ""
    @State private var userReply: String = ""
    @State private var isListening = false
    @State private var isThinking = false
    @State private var conversationHistory: [[String: String]] = []
    
    private let synthesizer = NativeSynthesizer()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step Bar
                stepPickerBar
                
                // Orb & Current Focus Area
                ScrollView {
                    VStack(spacing: 16) {
                        // Orb
                        MuralOrb(energy: isThinking ? 0.8 : (isListening ? 0.6 : 0.2), listening: isListening, active: true)
                            .frame(width: 140, height: 140)
                            .padding(.top, 10)
                        
                        // Teacher Speech Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("PROFESSEUR MURAL")
                                    .font(.caption.bold())
                                    .foregroundStyle(MuralColor.orange)
                                Spacer()
                                Button {
                                    speakTeacherMessage()
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundStyle(MuralColor.orange)
                                }
                            }
                            
                            Text(teacherMessage.isEmpty ? "Bonjour ! Je suis votre professeur pour cette leçon Assimil. Choisissez une étape pour commencer." : teacherMessage)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(MuralColor.ink)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)

                        // Step Specific Content
                        if currentStep == "dialogue" {
                            dialogueStepView
                        } else if currentStep == "grammar" {
                            grammarStepView
                        } else if currentStep == "exercises" {
                            exercisesStepView
                        }
                    }
                    .padding(20)
                }

                // Bottom Controls / Input
                bottomControlBar
            }
            .background(MuralColor.cream)
            .navigationTitle(lesson.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Quitter") {
                        synthesizer.stop()
                        dismiss()
                    }
                }
            }
            .onAppear {
                startStep("dialogue")
            }
        }
    }

    private var stepPickerBar: some View {
        HStack(spacing: 8) {
            stepButton(id: "dialogue", title: "1. Dialogue", icon: "bubble.left.and.bubble.right")
            stepButton(id: "grammar", title: "2. Grammaire", icon: "character.book.closed")
            stepButton(id: "exercises", title: "3. Exercices", icon: "pencil.and.list.clipboard")
            stepButton(id: "conversation", title: "4. Pratique", icon: "waveform")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
    }

    private func stepButton(id: String, title: String, icon: String) -> some View {
        Button {
            currentStep = id
            startStep(id)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(currentStep == id ? MuralColor.orange : MuralColor.cream, in: Capsule())
            .foregroundStyle(currentStep == id ? .white : MuralColor.ink)
        }
        .buttonStyle(.plain)
    }

    private var dialogueStepView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lignes du Dialogue")
                .font(.headline)
            
            ForEach(Array(lesson.dialogue.enumerated()), id: \.element.id) { (idx, line) in
                Button {
                    selectedLineIndex = idx
                    teachDialogueLine(line)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(line.lineIndex). \(line.targetText)")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(selectedLineIndex == idx ? MuralColor.orange : MuralColor.ink)
                            Text(line.nativeTranslation)
                                .font(.caption2)
                                .foregroundStyle(MuralColor.secondary)
                        }
                        Spacer()
                        Image(systemName: "speaker.wave.1")
                            .foregroundStyle(MuralColor.orange)
                    }
                    .padding(10)
                    .background(selectedLineIndex == idx ? Color(red: 1.0, green: 0.95, blue: 0.9) : Color.white, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var grammarStepView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes de Grammaire & Vocabulaire")
                .font(.headline)
            
            ForEach(lesson.grammarNotes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(MuralColor.orange)
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(MuralColor.ink)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var exercisesStepView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exercices de la Leçon")
                .font(.headline)
            
            ForEach(lesson.exercises) { ex in
                VStack(alignment: .leading, spacing: 8) {
                    Text(ex.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(MuralColor.ink)
                    ForEach(ex.items) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Q\(item.itemIndex): \(item.prompt)")
                                .font(.caption.bold())
                            Text("Solution : \(item.expectedAnswer)")
                                .font(.caption2)
                                .foregroundStyle(MuralColor.secondary)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MuralColor.cream.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var bottomControlBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                TextField("Répondre au professeur...", text: $userReply)
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
                
                Button {
                    sendUserReply()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(MuralColor.orange)
                }
                .disabled(userReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
            }
        }
        .padding(12)
        .background(MuralColor.cream)
    }

    private func startStep(_ step: String) {
        isThinking = true
        let prompt = AssimilTeacherPolicy.systemPrompt(
            lesson: lesson,
            step: step,
            correctionLevel: coordinator.store.preferences.correctionLevel
        )
        
        let introText = "Commence l'étape '\(step)' avec l'élève. Salue-le et lance la première consigne interactive."
        conversationHistory = [
            ["role": "user", "content": introText]
        ]
        
        Task {
            do {
                let result = try await coordinator.apiClient.respondHistory(
                    instructions: prompt,
                    history: conversationHistory,
                    preferences: coordinator.store.preferences
                )
                await MainActor.run {
                    self.teacherMessage = result.text
                    self.conversationHistory.append(["role": "assistant", "content": result.text])
                    self.isThinking = false
                    speakTeacherMessage()
                }
            } catch {
                await MainActor.run {
                    self.teacherMessage = "Prêt pour l'étape \(step) ! Posez-moi vos questions ou écoutez le dialogue."
                    self.isThinking = false
                }
            }
        }
    }

    private func teachDialogueLine(_ line: AssimilLine) {
        synthesizer.speak(text: line.targetText, languageCode: "de-DE", rate: coordinator.store.preferences.speechRate)
        teacherMessage = "Phrase \(line.lineIndex) : « \(line.targetText) »\n(Traduction : \(line.nativeTranslation))\n\nRépétez la phrase à l'oral ou écrivez-la ci-dessous pour vérifier votre prononciation et orthographe."
    }

    private func sendUserReply() {
        guard !userReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = userReply
        userReply = ""
        isThinking = true
        
        conversationHistory.append(["role": "user", "content": text])
        let prompt = AssimilTeacherPolicy.systemPrompt(
            lesson: lesson,
            step: currentStep,
            correctionLevel: coordinator.store.preferences.correctionLevel
        )
        
        Task {
            do {
                let result = try await coordinator.apiClient.respondHistory(
                    instructions: prompt,
                    history: conversationHistory,
                    preferences: coordinator.store.preferences
                )
                await MainActor.run {
                    self.teacherMessage = result.text
                    self.conversationHistory.append(["role": "assistant", "content": result.text])
                    self.isThinking = false
                    speakTeacherMessage()
                }
            } catch {
                await MainActor.run {
                    self.teacherMessage = "Bien reçu ! Continuons."
                    self.isThinking = false
                }
            }
        }
    }

    private func speakTeacherMessage() {
        guard !teacherMessage.isEmpty else { return }
        synthesizer.speak(
            text: teacherMessage,
            languageCode: "de-DE",
            rate: coordinator.store.preferences.speechRate,
            voiceIdentifier: coordinator.store.preferences.selectedVoiceIdentifier
        )
    }
}

// MARK: - Document Teacher Session View
struct DocumentTeacherSessionView: View {
    let document: StudyDocument
    let coordinator: ConversationCoordinator
    
    @Environment(\.dismiss) private var dismiss
    @State private var teacherMessage: String = ""
    @State private var userReply: String = ""
    @State private var isThinking = false
    @State private var conversationHistory: [[String: String]] = []
    
    private let synthesizer = NativeSynthesizer()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        MuralOrb(energy: isThinking ? 0.8 : 0.3, listening: false, active: true)
                            .frame(width: 140, height: 140)
                            .padding(.top, 10)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("TUTEUR GOOGLE DRIVE")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.blue)
                                Spacer()
                                Button {
                                    speakTeacherMessage()
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundStyle(Color.blue)
                                }
                            }
                            
                            Text(teacherMessage.isEmpty ? "Bonjour ! J'ai analysé votre document « \(document.title) ». Que souhaitez-vous approfondir ?" : teacherMessage)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(MuralColor.ink)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)

                        // Quick Quiz Cards
                        if !document.quizQuestions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Questions d'entraînement")
                                    .font(.headline)
                                ForEach(document.quizQuestions) { q in
                                    Button {
                                        userReply = "Réponds à la question : \(q.question)"
                                        sendUserReply()
                                    } label: {
                                        Text("❓ " + q.question)
                                            .font(.caption.bold())
                                            .foregroundStyle(MuralColor.ink)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(20)
                }

                // Input bar
                HStack(spacing: 12) {
                    TextField("Poser une question sur le document...", text: $userReply)
                        .padding(12)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
                    
                    Button {
                        sendUserReply()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Color.blue)
                    }
                    .disabled(userReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
                }
                .padding(12)
                .background(MuralColor.cream)
            }
            .background(MuralColor.cream)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Quitter") {
                        synthesizer.stop()
                        dismiss()
                    }
                }
            }
            .onAppear {
                startDocumentTutoring()
            }
        }
    }

    private func startDocumentTutoring() {
        isThinking = true
        let prompt = DocumentTeacherPolicy.systemPrompt(
            doc: document,
            correctionLevel: coordinator.store.preferences.correctionLevel
        )
        
        let intro = "Présente brièvement le sujet du document et pose une première question de réflexion à l'élève."
        conversationHistory = [
            ["role": "user", "content": intro]
        ]
        
        Task {
            do {
                let result = try await coordinator.apiClient.respondHistory(
                    instructions: prompt,
                    history: conversationHistory,
                    preferences: coordinator.store.preferences
                )
                await MainActor.run {
                    self.teacherMessage = result.text
                    self.conversationHistory.append(["role": "assistant", "content": result.text])
                    self.isThinking = false
                    speakTeacherMessage()
                }
            } catch {
                await MainActor.run {
                    self.teacherMessage = "Document prêt ! Quelle notion souhaitez-vous travailler ?"
                    self.isThinking = false
                }
            }
        }
    }

    private func sendUserReply() {
        guard !userReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = userReply
        userReply = ""
        isThinking = true
        
        conversationHistory.append(["role": "user", "content": text])
        let prompt = DocumentTeacherPolicy.systemPrompt(
            doc: document,
            correctionLevel: coordinator.store.preferences.correctionLevel
        )
        
        Task {
            do {
                let result = try await coordinator.apiClient.respondHistory(
                    instructions: prompt,
                    history: conversationHistory,
                    preferences: coordinator.store.preferences
                )
                await MainActor.run {
                    self.teacherMessage = result.text
                    self.conversationHistory.append(["role": "assistant", "content": result.text])
                    self.isThinking = false
                    speakTeacherMessage()
                }
            } catch {
                await MainActor.run {
                    self.teacherMessage = "Merci pour votre réponse. Poursuivons l'analyse du texte !"
                    self.isThinking = false
                }
            }
        }
    }

    private func speakTeacherMessage() {
        guard !teacherMessage.isEmpty else { return }
        synthesizer.speak(
            text: teacherMessage,
            languageCode: "de-DE",
            rate: coordinator.store.preferences.speechRate
        )
    }
}
