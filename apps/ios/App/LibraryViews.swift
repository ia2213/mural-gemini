import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import MuralCore

struct ThemesView: View {
    let coordinator: ConversationCoordinator
    let choose: (ConversationTheme?) -> Void
    @State private var search = ""
    @State private var category = "All"
    @State private var current = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var themes: [ConversationTheme] {
        coordinator.language.themes.filter { (category == "All" || $0.category == category) && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.category.localizedCaseInsensitiveContains(search)) }
    }
    private var categories: [String] { coordinator.language.themes.map(\.category).reduce(into: ["All"]) { if !$0.contains($1) { $0.append($1) } } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "Un point de départ", title: "Qu’avez-vous\nen tête ?", subtitle: "Le même compagnon. Un nouveau lieu.")
                Button { choose(nil) } label: {
                    HStack { Image(systemName: "waveform"); Text("Discuter librement"); Spacer(); Image(systemName: "arrow.up.right") }
                        .font(.headline).padding(22).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 26))
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { c in
                            Button(c == "All" ? "Tout" : c) { category = c }.font(.caption).padding(.horizontal, 15).padding(.vertical, 11)
                                .background(category == c ? FluenceColor.peach : .white.opacity(0.65), in: Capsule())
                                .accessibilityAddTraits(category == c ? .isSelected : [])
                        }
                    }
                }.scrollIndicators(.hidden)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 260 : (horizontalSizeClass == .regular ? 220 : 150)), spacing: 16)], spacing: 16) {
                    ForEach(themes) { theme in
                        Button { if theme.id == "today" { current = true } else { choose(theme) } } label: {
                            VStack(alignment: .leading, spacing: 28) {
                                Image(systemName: theme.symbol).font(.system(size: 28, weight: .light)).foregroundStyle(FluenceColor.secondary)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(theme.title).font(.system(.headline, design: .rounded))
                                    Text(theme.subtitle).font(.caption).foregroundStyle(FluenceColor.secondary)
                                }
                            }.frame(maxWidth: .infinity, minHeight: 142, alignment: .leading).padding(19)
                                .background(FluenceColor.panels[theme.colorIndex], in: RoundedRectangle(cornerRadius: 27))
                        }.buttonStyle(.plain)
                    }
                }
                if themes.isEmpty { ContentUnavailableView.search(text: search) }
            }.padding(24).frame(maxWidth: 1000).frame(maxWidth: .infinity, alignment: .topLeading)
        }.foregroundStyle(FluenceColor.ink)
            .searchable(text: $search, prompt: "Find a conversation")
            .sheet(isPresented: $current) { CurrentTopicView(coordinator: coordinator) { choose(coordinator.selectedTheme) } }
    }
}

struct CurrentTopicView: View {
    let coordinator: ConversationCoordinator
    let selected: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var brief: TopicBrief?
    @State private var loading = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeading(eyebrow: "Le monde actuel", title: "Un nouveau sujet.", subtitle: "De quoi aimeriez-vous parler ?")
                    TextField(coordinator.language.topicPlaceholder, text: $query, axis: .vertical).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 20))
                    Button { find() } label: {
                        HStack { Text(loading ? "Recherche en cours…" : "Trouver un sujet"); Spacer(); if loading { ProgressView() } else { Image(systemName: "sparkle.magnifyingglass") } }.padding(18).background(FluenceColor.peach, in: Capsule())
                    }.disabled(loading || query.trimmingCharacters(in: .whitespaces).isEmpty)
                    if let error { Text(error).font(.footnote).foregroundStyle(FluenceColor.secondary) }
                    if let brief {
                        Text(.init(brief.text)).font(.body).textSelection(.enabled)
                        SourcesView(sources: brief.sources, date: brief.retrievedAt)
                        Button("Parler de ça", systemImage: "waveform") { coordinator.discuss(brief); selected(); dismiss() }
                            .font(.headline).padding(18).frame(maxWidth: .infinity).background(FluenceColor.orange, in: Capsule())
                    }
                    Text("La recherche utilise votre compte Gemini API. Les sources restent liées à la discussion.").font(.footnote).foregroundStyle(FluenceColor.secondary)
                }.padding(26)
            }.background(FluenceColor.cream).foregroundStyle(FluenceColor.ink)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
        }
    }
    private func find() {
        loading = true; error = nil
        Task { do { brief = try await coordinator.currentTopic(query) } catch { self.error = error.localizedDescription }; loading = false }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Google Drive Direct Browser Sheet
struct GoogleDriveBrowserSheet: View {
    let coordinator: ConversationCoordinator
    @ObservedObject private var service = GoogleDriveDirectService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var driveLink = ""
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var importingFileId: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                FluenceColor.background.ignoresSafeArea()
                
                if service.isAuthenticated {
                    VStack(spacing: 0) {
                        // User info banner & search
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(FluenceColor.accent)
                                Text(service.userEmail ?? "Google Drive Connecté")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(FluenceColor.ink)
                                Spacer()
                                Button("Déconnexion") {
                                    service.signOut()
                                }
                                .font(.caption)
                                .foregroundStyle(FluenceColor.coral)
                            }
                            
                            // Search bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(FluenceColor.secondary)
                                TextField("Rechercher dans Google Drive…", text: $search)
                                    .font(.subheadline)
                                    .onSubmit {
                                        Task { try? await service.fetchFiles(folderId: service.currentFolderID, search: search) }
                                    }
                                if !search.isEmpty {
                                    Button {
                                        search = ""
                                        Task { try? await service.fetchFiles(folderId: service.currentFolderID) }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(FluenceColor.secondary)
                                    }
                                }
                            }
                            .padding(10)
                            .background(FluenceColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            
                            // Folder breadcrumbs
                            if service.folderBreadcrumbs.count > 1 {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(0..<service.folderBreadcrumbs.count, id: \.self) { idx in
                                            let crumb = service.folderBreadcrumbs[idx]
                                            Button {
                                                Task { await service.navigateBackToBreadcrumb(index: idx) }
                                            } label: {
                                                Text(crumb.name)
                                                    .font(.caption)
                                                    .foregroundStyle(idx == service.folderBreadcrumbs.count - 1 ? FluenceColor.ink : FluenceColor.accent)
                                            }
                                            if idx < service.folderBreadcrumbs.count - 1 {
                                                Image(systemName: "chevron.right")
                                                    .font(.caption2)
                                                    .foregroundStyle(FluenceColor.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(FluenceColor.surface)
                        
                        Divider()
                        
                        // Files List
                        if service.isLoading && service.files.isEmpty {
                            Spacer()
                            ProgressView("Chargement de votre Drive…")
                            Spacer()
                        } else if service.files.isEmpty {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "folder.badge.questionmark")
                                    .font(.system(size: 40))
                                    .foregroundStyle(FluenceColor.secondary)
                                Text("Aucun fichier trouvé dans ce dossier.")
                                    .font(.subheadline)
                                    .foregroundStyle(FluenceColor.secondary)
                            }
                            Spacer()
                        } else {
                            List {
                                ForEach(service.files) { file in
                                    Button {
                                        if file.isFolder {
                                            Task { await service.openFolder(id: file.id, name: file.name) }
                                        } else {
                                            importFile(file)
                                        }
                                    } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: file.iconName)
                                                .font(.title3)
                                                .foregroundStyle(file.isFolder ? FluenceColor.accent : FluenceColor.ink)
                                                .frame(width: 28)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(file.name)
                                                    .font(.system(.body, design: .rounded, weight: .medium))
                                                    .foregroundStyle(FluenceColor.ink)
                                                    .lineLimit(1)
                                                
                                                HStack(spacing: 8) {
                                                    if file.isFolder {
                                                        Text("Dossier")
                                                    } else {
                                                        Text("Fichier à importer")
                                                    }
                                                }
                                                .font(.caption2)
                                                .foregroundStyle(FluenceColor.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            if importingFileId == file.id {
                                                ProgressView()
                                            } else if file.isFolder {
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundStyle(FluenceColor.secondary)
                                            } else {
                                                Image(systemName: "arrow.down.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(FluenceColor.accent)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .listStyle(.plain)
                        }
                    }
                } else {
                    // Not connected view + Link import option
                    ScrollView {
                        VStack(spacing: 24) {
                            VStack(spacing: 12) {
                                Image(systemName: "externaldrive.badge.icloud")
                                    .font(.system(size: 54))
                                    .foregroundStyle(FluenceColor.accent)
                                
                                Text("Google Drive Direct")
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(FluenceColor.ink)
                                
                                Text("Connectez directement votre compte Google Drive pour explorer vos dossiers et importer vos cours, paquets Anki et lexiques en un clic.")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(FluenceColor.secondary)
                                    .padding(.horizontal, 20)
                            }
                            .padding(.top, 24)
                            
                            // 1. Direct OAuth Connect Button
                            Button {
                                Task {
                                    do {
                                        try await service.signIn()
                                    } catch {
                                        alertMessage = "Connexion annulée ou impossible : \(error.localizedDescription)"
                                        showAlert = true
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.badge.key.fill")
                                    Text("Se connecter avec Google")
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                }
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(FluenceColor.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .padding(.horizontal, 24)
                            }
                            
                            HStack {
                                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                                Text("OU PAR LIEN PARTAGÉ").font(.caption2).foregroundStyle(FluenceColor.secondary)
                                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            
                            // 2. Direct Link Import Option
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Coller un lien Google Drive")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(FluenceColor.ink)
                                
                                TextField("https://drive.google.com/file/d/...", text: $driveLink)
                                    .font(.subheadline)
                                    .padding(14)
                                    .background(FluenceColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                
                                Button {
                                    importFromLink()
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.down.doc.fill")
                                        Text("Télécharger & Importer")
                                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    }
                                    .foregroundStyle(FluenceColor.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(FluenceColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .disabled(driveLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(18)
                            .background(FluenceColor.surface.opacity(0.60), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .padding(.horizontal, 24)
                        }
                    }
                }
            }
            .navigationTitle("Google Drive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                if service.isAuthenticated {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { try? await service.fetchFiles(folderId: service.currentFolderID) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .alert("Google Drive", isPresented: $showAlert) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }
    
    private func importFile(_ file: GoogleDriveFile) {
        importingFileId = file.id
        Task {
            do {
                let count = try await service.downloadAndImport(file: file, store: coordinator.store, targetLanguageID: coordinator.language.id)
                importingFileId = nil
                alertMessage = "\(count) mots importés avec succès depuis « \(file.name) » !"
                showAlert = true
            } catch {
                importingFileId = nil
                alertMessage = "Erreur lors de l'importation : \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func importFromLink() {
        let link = driveLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else { return }
        Task {
            do {
                let count = try await service.importFromPublicLink(urlString: link, store: coordinator.store, targetLanguageID: coordinator.language.id)
                driveLink = ""
                alertMessage = "\(count) mots importés avec succès depuis le lien Google Drive !"
                showAlert = true
            } catch {
                alertMessage = "Impossible de télécharger ce lien Google Drive : \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}

struct WordsView: View {
    let coordinator: ConversationCoordinator
    @State private var search = ""
    @State private var selected: WordState?
    @State private var sessions = false
    @State private var importingAnki = false
    @State private var showGoogleDrive = false
    @State private var exportURL: URL?
    @State private var alertMessage: String?
    @State private var showAlert = false
    
    private var learner: LearnerState { coordinator.store.learner }
    private var words: [WordState] { learner.words.filter { search.isEmpty || $0.lemma.localizedCaseInsensitiveContains(search) || $0.meaning.localizedCaseInsensitiveContains(search) } }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeading(eyebrow: "Mots et Vocabulaire", title: "Vos mots.", subtitle: "Mots et phrases pour vos futures discussions.")
                
                // Anki & Google Drive Sync / Import / Export Bar
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        // 1. Google Drive Direct Button
                        Button {
                            showGoogleDrive = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "externaldrive.badge.icloud")
                                    .font(.caption)
                                Text("Google Drive")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                            }
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(FluenceColor.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        // 2. Anki & Local File Import Button
                        Button {
                            importingAnki = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.caption)
                                Text("Anki / Fichier")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            }
                            .foregroundStyle(FluenceColor.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(FluenceColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        
                        // 3. Export Menu
                        Menu {
                            Button {
                                if let url = AnkiGoogleDriveManager.shared.exportToAnkiTSV(words: words, language: coordinator.language.name) {
                                    exportURL = url
                                }
                            } label: {
                                Label("Exporter Deck Anki (.txt / .tsv)", systemImage: "rectangle.stack.badge.plus")
                            }
                            
                            Button {
                                if let url = AnkiGoogleDriveManager.shared.exportToJSON(words: words, language: coordinator.language.name) {
                                    exportURL = url
                                }
                            } label: {
                                Label("Exporter Sauvegarde Drive (.json)", systemImage: "externaldrive.fill")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption)
                                Text("Exporter")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            }
                            .foregroundStyle(FluenceColor.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(FluenceColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(FluenceColor.emerald)
                        Text("Accès direct Google Drive & Anki")
                            .font(.caption2)
                            .foregroundStyle(FluenceColor.secondary)
                        Spacer()
                        Text("\(words.count) mots")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(FluenceColor.ink)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(14)
                .background(FluenceColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                if words.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        Image(systemName: "leaf").font(.system(size: 34, weight: .light))
                        Text(search.isEmpty ? "Ils pousseront d'ici." : "Aucun mot correspondant.").font(.system(.title2, design: .rounded, weight: .medium))
                        Text(search.isEmpty ? "Au fil de nos discussions, les mots et expressions utiles apparaîtront ici. Vous pouvez aussi importer un paquet Anki ou un fichier depuis Google Drive." : "Essayer un autre mot ou une signification.").font(.subheadline).foregroundStyle(FluenceColor.secondary)
                    }.padding(26).frame(maxWidth: .infinity, alignment: .leading).background(FluenceColor.sage, in: RoundedRectangle(cornerRadius: 28))
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(words) { word in
                            Button { selected = word } label: {
                                HStack(spacing: 18) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(word.lemma).font(.system(size: 30, weight: .bold, design: .rounded))
                                        Text(word.meaning).font(.title3).foregroundStyle(FluenceColor.secondary)
                                    }
                                    Spacer(minLength: 10)
                                    VStack(alignment: .trailing, spacing: 8) { RecallBars(count: word.bars); Text(word.label).font(.caption2).foregroundStyle(FluenceColor.secondary) }
                                }.padding(.vertical, 20)
                            }.buttonStyle(.plain)
                            Divider().overlay(FluenceColor.peach)
                        }
                    }
                }
                HStack { Text("1 · Fragile"); Spacer(); Text("2 · En croissance"); Spacer(); Text("3 · Solide") }.font(.caption).foregroundStyle(FluenceColor.secondary)
                Text("Les barres estiment votre capacité de mémorisation orale. Le moteur FSRS gère l'espacement et la révision.").font(.footnote).foregroundStyle(FluenceColor.secondary)
                if !learner.capabilities.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trouver votre voix").font(.system(.title3, design: .rounded, weight: .semibold))
                        ForEach(learner.capabilities, id: \.self) { Text($0).font(.subheadline) }
                        Text("Observé lors de nos conversations. Estimations non officielles.").font(.footnote).foregroundStyle(FluenceColor.secondary)
                    }.padding(22).background(FluenceColor.butter, in: RoundedRectangle(cornerRadius: 24))
                }
            }.padding(22).frame(maxWidth: 1000).frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(FluenceColor.ink)
        .searchable(text: $search, prompt: "Rechercher un mot")
        .sheet(item: $selected) { word in WordDetailView(word: word, store: coordinator.store) }
        .sheet(isPresented: $sessions) { SessionHistoryView(store: coordinator.store) }
        .sheet(isPresented: $showGoogleDrive) { GoogleDriveBrowserSheet(coordinator: coordinator) }
        .sheet(isPresented: Binding(get: { exportURL != nil }, set: { if !$0 { exportURL = nil } })) {
            if let url = exportURL {
                ActivityViewController(activityItems: [url])
            }
        }
        .fileImporter(isPresented: $importingAnki, allowedContentTypes: [.plainText, .json, .commaSeparatedText, .tabSeparatedText, .item]) { result in
            switch result {
            case .success(let url):
                Task {
                    do {
                        let count = try await AnkiGoogleDriveManager.shared.importVocabulary(from: url, store: coordinator.store, languageID: coordinator.language.id)
                        alertMessage = "\(count) mots importés avec succès dans votre vocabulaire Fluence !"
                        showAlert = true
                    } catch {
                        alertMessage = "Erreur lors de l'importation : \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            case .failure(let error):
                alertMessage = "Sélection annulée ou erreur : \(error.localizedDescription)"
                showAlert = true
            }
        }
        .alert("Importation de vocabulaire", isPresented: $showAlert) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }
}

struct WordDetailView: View {
    let word: WordState
    let store: LearningStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text(word.lemma).font(.system(.largeTitle, design: .rounded, weight: .medium))
                if store.language.id == "zh" { PinyinHelp(text: word.lemma) }
                Text(word.meaning).font(.title3).foregroundStyle(FluenceColor.secondary)
                HStack { RecallBars(count: word.bars); Text(word.label).font(.subheadline) }
                Text(word.explanation).font(.body)
                Text("“\(word.example)”").font(.system(.title3, design: .rounded)).padding(20).frame(maxWidth: .infinity, alignment: .leading).background(FluenceColor.peach, in: RoundedRectangle(cornerRadius: 22))
                Text("\(word.independentCount) utilisations indépendantes · Vu pour la dernière fois : \(word.lastSeen.formatted(date: .abbreviated, time: .omitted))").font(.footnote).foregroundStyle(FluenceColor.secondary)
                Button("Supprimer de mes mots", role: .destructive) { store.hideWord(word.id); dismiss() }.font(.footnote)
                Spacer()
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading).background(FluenceColor.cream).foregroundStyle(FluenceColor.ink)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}

struct SourcesView: View {
    var sources: [SourceLink]
    var date: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sources · \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(FluenceColor.secondary)
            ForEach(sources) { source in if let url = source.safeURL { Link(destination: url) { Label(source.title, systemImage: "arrow.up.right").font(.subheadline) } } }
        }
    }
}

struct TranscriptView: View {
    let session: SessionRecord?
    var meaningLanguage = "English"
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let session {
                        ForEach(session.passages) { passage in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(passage.speaker == .assistant ? "FLUENCE" : "YOU").font(.caption).tracking(1).foregroundStyle(FluenceColor.secondary)
                                Text(passage.text).font(.system(.title3, design: .rounded)).textSelection(.enabled)
                                    .accessibilityIdentifier(passage.speaker == .user ? "transcript-user-passage" : "transcript-assistant-passage")
                                if session.languageID == "zh" { PinyinHelp(text: passage.text) }
                                if let translation = session.translations[MeaningRequest.cacheKey(revisionKey: passage.revisionKey, language: meaningLanguage)] ?? session.translations[passage.revisionKey] {
                                    Text(translation).font(.subheadline).foregroundStyle(FluenceColor.secondary)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(session.topics) { topic in Text(.init(topic.text)); SourcesView(sources: topic.sources, date: topic.retrievedAt) }
                        if session.fragments.isEmpty && session.topics.isEmpty { Text("Your conversation will appear here.").foregroundStyle(FluenceColor.secondary) }
                    } else { Text("Start a conversation and your words will appear here.") }
                }.padding(26)
            }.background(FluenceColor.cream).foregroundStyle(FluenceColor.ink)
                .navigationTitle("Notre conversation").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { dismiss() } } }
        }
    }
}

struct SessionHistoryView: View {
    let store: LearningStore
    @State private var selected: SessionRecord?
    @State private var deleting: SessionRecord?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if store.learningSessions.isEmpty { Text("Vos conversations en \(store.language.name) apparaîtront ici.").foregroundStyle(FluenceColor.secondary) }
                ForEach(store.learningSessions) { session in
                    Button { selected = session } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.title).font(.headline)
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(FluenceColor.secondary)
                        }.padding(.vertical, 8)
                    }.swipeActions { Button("Supprimer", role: .destructive) { deleting = session }.disabled(session.endedAt == nil) }
                }
            }.scrollContentBackground(.hidden).background(FluenceColor.cream)
                .navigationTitle("Conversations").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { dismiss() } } }
        }.sheet(item: $selected) { session in EditableTranscriptView(sessionID: session.id, store: store) }
            .confirmationDialog("Supprimer cette conversation et ses données d'apprentissage ?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("Supprimer", role: .destructive) { if let deleting { store.deleteSession(deleting.id) }; deleting = nil }
            }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct EditableTranscriptView: View {
    let sessionID: UUID
    let store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingID: String?
    @State private var editedText = ""
    private var session: SessionRecord? { store.sessions.first { $0.id == sessionID } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(session?.passages ?? []) { passage in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(passage.speaker == .user ? "YOU" : "FLUENCE").font(.caption).tracking(1)
                                Spacer()
                                if passage.speaker == .user && session?.endedAt != nil {
                                    Button("Edit") { editedText = passage.text; editingID = passage.id }.font(.caption)
                                }
                            }.foregroundStyle(FluenceColor.secondary)
                            Text(passage.text).font(.system(.title3, design: .rounded)).textSelection(.enabled)
                                    .accessibilityIdentifier(passage.speaker == .user ? "transcript-user-passage" : "transcript-assistant-passage")
                            if session?.languageID == "zh" { PinyinHelp(text: passage.text) }
                        }
                    }
                    ForEach(session?.topics ?? []) { topic in Text(.init(topic.text)); SourcesView(sources: topic.sources, date: topic.retrievedAt) }
                }.padding(26)
            }.background(FluenceColor.cream).foregroundStyle(FluenceColor.ink)
                .navigationTitle("Notre conversation").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { dismiss() } } }
        }.sheet(isPresented: Binding(get: { editingID != nil }, set: { if !$0 { editingID = nil } })) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Ce que vous avez dit", text: $editedText, axis: .vertical).lineLimit(4...10).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 20))
                    Text("Corrigez une phrase mal comprise. L'ancienne phrase sera remplacée dans l'historique et votre apprentissage s'adaptera.").font(.footnote).foregroundStyle(FluenceColor.secondary)
                    Spacer()
                }.padding(24).background(FluenceColor.cream).navigationTitle("Ce que vous avez dit").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Annuler") { editingID = nil } }
                        ToolbarItem(placement: .confirmationAction) { Button("Sauvegarder") { if let id = editingID { store.correctPassage(sessionID: sessionID, passageID: id, text: editedText) }; editingID = nil } }
                    }
            }.presentationDetents([.medium, .large])
        }
    }
}

struct SettingsView: View {
    let coordinator: ConversationCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?
    @State private var exporting = false
    @State private var importing = false
    @State private var backup: BackupDocument?
    @State private var deleting = false
    @State private var notices = false
    
    private var store: LearningStore { coordinator.store }
    private var totalVoiceSeconds: Double { store.sessions.reduce(0) { $0 + $1.voiceSeconds } }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: 0. APPARENCE & THÈME
                Section {
                    Picker(selection: Binding(get: { store.preferences.appearance }, set: { val in store.updatePreferences { $0.appearance = val } })) {
                        Text("Automatique (Système)").tag("system")
                        Text("Sombre").tag("dark")
                        Text("Clair").tag("light")
                    } label: {
                        Label("Thème d'affichage", systemImage: "circle.lefthalf.filled")
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Apparence")
                }
                
                // MARK: 1. APPRENTISSAGE & PÉDAGOGIE
                Section {
                    Picker(selection: Binding(get: { store.preferences.pedagogicalMode }, set: { val in store.updatePreferences { $0.pedagogicalMode = val } })) {
                        Text("👨🏫 Professeur Particulier (Guidé)").tag("teacher")
                        Text("💬 Discussion Libre (Immersion)").tag("conversation")
                    } label: {
                        Label("Mode d'apprentissage", systemImage: "graduationcap.fill")
                    }
                    .pickerStyle(.menu)
                    
                    Picker(selection: Binding(get: { coordinator.language.id }, set: { coordinator.selectLanguage($0) })) {
                        ForEach(LanguageRegistry.all) { language in
                            Text(language.settingsTitle).tag(language.id)
                        }
                    } label: {
                        Label("Langue apprise", systemImage: "globe")
                    }
                    .pickerStyle(.menu)
                    
                    Picker(selection: Binding(get: { store.preferences.cefrLevel }, set: { val in store.updatePreferences { $0.cefrLevel = val } })) {
                        Text("A1 · Débutant").tag("A1")
                        Text("A2 · Élémentaire").tag("A2")
                        Text("B1 · Intermédiaire").tag("B1")
                        Text("B2 · Avancé (Recommandé)").tag("B2")
                        Text("C1 · Autonome / Médical").tag("C1")
                        Text("C2 · Bilingue / Expert").tag("C2")
                    } label: {
                        Label("Niveau de départ (CECRL)", systemImage: "chart.bar.fill")
                    }
                    .pickerStyle(.menu)
                    
                    Toggle(isOn: Binding(get: { store.preferences.meaningVisible }, set: { value in
                        if value != store.preferences.meaningVisible { coordinator.toggleMeaning() }
                    })) {
                        Label("Sous-titres & Traduction", systemImage: "captions.bubble.fill")
                    }
                    
                    if store.preferences.meaningVisible {
                        Picker(selection: Binding(get: { store.preferences.meaningLanguage }, set: { coordinator.selectMeaningLanguage($0) })) {
                            ForEach(MeaningLanguages.all, id: \.self) { Text($0).tag($0) }
                        } label: {
                            Label("Langue de traduction", systemImage: "character.book.closed")
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Picker(selection: Binding(get: { store.preferences.correctionLevel }, set: { val in store.updatePreferences { $0.correctionLevel = val } })) {
                        Text("Strict (corrige chaque phrase)").tag("high")
                        Text("Équilibré (naturel)").tag("medium")
                        Text("Fluide (erreurs clés)").tag("low")
                    } label: {
                        Label("Niveau de correction", systemImage: "checkmark.seal")
                    }
                    .pickerStyle(.menu)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Centres d'intérêt", systemImage: "sparkles")
                            .font(.subheadline)
                            .foregroundStyle(FluenceColor.ink)
                        TextField("Ex: médecine, voyages, philosophie...", text: Binding(get: { store.preferences.interests }, set: { value in store.updatePreferences { $0.interests = String(value.prefix(500)) } }))
                            .font(.subheadline)
                            .foregroundStyle(FluenceColor.secondary)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Apprentissage")
                }
                
                // MARK: 2. VOIX & AUDIO
                Section {
                    Picker(selection: Binding(get: { store.preferences.speechRate }, set: { val in store.updatePreferences { $0.speechRate = val } })) {
                        Text("Lente (0.8x)").tag(Float(0.40))
                        Text("Normale (1.0x)").tag(Float(0.50))
                        Text("Rapide (1.2x)").tag(Float(0.60))
                    } label: {
                        Label("Vitesse vocale", systemImage: "gauge.with.dots.needle.50percent")
                    }
                    .pickerStyle(.menu)
                    
                    let availableVoices = AVSpeechSynthesisVoice.speechVoices().filter {
                        $0.language.lowercased().hasPrefix(String(store.language.locale.prefix(2)).lowercased())
                    }
                    Picker(selection: Binding(get: { store.preferences.selectedVoiceIdentifier }, set: { val in store.updatePreferences { $0.selectedVoiceIdentifier = val } })) {
                        Text("Automatique").tag("")
                        ForEach(availableVoices, id: \.identifier) { v in
                            let qualityStr = v.quality == .premium ? " (HD)" : ""
                            Text("\(v.name)\(qualityStr)").tag(v.identifier)
                        }
                    } label: {
                        Label("Accent & Timbre", systemImage: "person.wave.2")
                    }
                    .pickerStyle(.menu)
                    
                    Button {
                        let text = store.language.greeting
                        let synth = AVSpeechSynthesizer()
                        let utterance = AVSpeechUtterance(string: text)
                        if !store.preferences.selectedVoiceIdentifier.isEmpty, let v = AVSpeechSynthesisVoice(identifier: store.preferences.selectedVoiceIdentifier) {
                            utterance.voice = v
                        } else {
                            utterance.voice = AVSpeechSynthesisVoice(language: store.language.locale)
                        }
                        utterance.rate = store.preferences.speechRate
                        synth.speak(utterance)
                    } label: {
                        Label("Écouter un extrait audio", systemImage: "speaker.wave.2.fill")
                            .foregroundStyle(FluenceColor.accent)
                    }
                } header: {
                    Text("Voix & Audio")
                }
                
                // MARK: 3. CONFIGURATION DES MOTEURS IA (Subpage)
                Section {
                    Picker(selection: Binding(get: { store.preferences.providerID }, set: { val in store.updatePreferences { $0.providerID = val } })) {
                        Text("Auto (Groq → Gemini → VPS)").tag("auto")
                        Text("Groq Cloud (Llama 3.3)").tag("groq")
                        Text("Google Gemini (2.0 Flash)").tag("google")
                        Text("Hermes VPS Personnel").tag("hermes_vps")
                    } label: {
                        Label("Moteur actif", systemImage: "cpu")
                    }
                    .pickerStyle(.menu)
                    
                    NavigationLink {
                        AISettingsSubView(coordinator: coordinator)
                    } label: {
                        Label("Clés API & Modèles avancés", systemImage: "slider.horizontal.2.square")
                    }
                } header: {
                    Text("Intelligence Artificielle")
                } footer: {
                    Text("En mode Auto, Fluence bascule automatiquement sur le meilleur modèle disponible sans interruption.")
                }
                
                // MARK: 4. SAUVEGARDES & DONNÉES
                Section {
                    Button {
                        do { backup = BackupDocument(data: try store.exportData()); exporting = true }
                        catch { message = error.localizedDescription }
                    } label: {
                        Label("Exporter mes données", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        importing = true
                    } label: {
                        Label("Importer une sauvegarde", systemImage: "square.and.arrow.down")
                    }
                    .disabled(coordinator.isRunning)
                    
                    Button(role: .destructive) {
                        deleting = true
                    } label: {
                        Label("Réinitialiser l'apprentissage", systemImage: "trash")
                    }
                    .disabled(coordinator.isRunning)
                } header: {
                    Text("Données & Sauvegarde")
                }
                
                // MARK: 5. À PROPOS
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("2.0 (Fluence)")
                            .foregroundStyle(FluenceColor.secondary)
                    }
                    
                    Link(destination: URL(string: "https://fluence.chat/privacy/")!) {
                        Label("Politique de confidentialité", systemImage: "lock.shield")
                    }
                    
                    Button {
                        notices = true
                    } label: {
                        Label("Mentions légales open-source", systemImage: "doc.plaintext")
                    }
                } header: {
                    Text("À propos")
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(FluenceColor.accent)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "Fluence-learning-backup") { result in
            if case .failure(let error) = result { message = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                try store.importData(Archive.readImportData(from: url))
                message = "Sauvegarde importée avec succès."
            } catch { message = error.localizedDescription }
        }
        .confirmationDialog("Supprimer toutes les données ?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Tout supprimer", role: .destructive) { coordinator.deleteLearningData() }
        } message: {
            Text("Ceci réinitialisera votre historique et vos mots mémorisés. Vos clés API resteront enregistrées.")
        }
        .sheet(isPresented: $notices) {
            NavigationStack {
                ScrollView {
                    Text(Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "Notices unavailable.")
                        .font(.footnote)
                        .padding(24)
                }
                .navigationTitle("Mentions Légales")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer") { notices = false }
                    }
                }
            }
        }
    }
}

// MARK: - Dedicated Clean AI Subpage
struct AISettingsSubView: View {
    let coordinator: ConversationCoordinator
    @State private var groqKey = ""
    @State private var hasGroqKey = CredentialStore.hasKey
    @State private var message: String?
    
    private var store: LearningStore { coordinator.store }
    
    var body: some View {
        Form {
            // Groq Cloud
            Section {
                Picker("Modèle Groq", selection: Binding(get: { store.preferences.groqModel }, set: { val in store.updatePreferences { $0.groqModel = val } })) {
                    Text("Llama 3.3 70B (Optimal)").tag("llama-3.3-70b-versatile")
                    Text("GPT-OSS 120B").tag("openai/gpt-oss-120b")
                    Text("Qwen 3.8 27B").tag("qwen/qwen3.8-27b")
                    Text("Llama 3.1 8B (Ultra-Rapide)").tag("llama-3.1-8b-instant")
                }
                .pickerStyle(.menu)
                
                SecureField(hasGroqKey ? "Clé enregistrée (remplacer)" : "Clé API Groq (gsk_...)", text: $groqKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                if !groqKey.isEmpty {
                    Button("Sauvegarder la clé Groq") {
                        do {
                            try CredentialStore.save(groqKey)
                            groqKey = ""
                            hasGroqKey = true
                            message = "Clé Groq enregistrée."
                        } catch { message = error.localizedDescription }
                    }
                }
                
                Link("Obtenir une clé Groq gratuite", destination: URL(string: "https://console.groq.com/keys")!)
            } header: {
                Label("Groq Cloud API", systemImage: "bolt.fill")
            }
            
            // Google Gemini
            Section {
                Picker("Modèle Gemini", selection: Binding(get: { store.preferences.geminiModel }, set: { val in store.updatePreferences { $0.geminiModel = val } })) {
                    Text("Gemini 2.0 Flash (Recommandé)").tag("gemini-2.0-flash")
                    Text("Gemini 2.0 Lite").tag("gemini-2.0-flash-lite")
                    Text("Gemini 1.5 Flash").tag("gemini-1.5-flash")
                    Text("Gemini 1.5 Pro").tag("gemini-1.5-pro")
                }
                .pickerStyle(.menu)
                
                SecureField("Clé API Gemini (AIzaSy...)", text: Binding(get: { store.preferences.googleAPIKey }, set: { val in store.updatePreferences { $0.googleAPIKey = val } }))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                Link("Obtenir une clé Gemini gratuite", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
            } header: {
                Label("Google Gemini API", systemImage: "sparkle")
            }
            
            // Hermes VPS
            Section {
                TextField("URL Endpoint VPS", text: Binding(get: { store.preferences.vpsEndpoint }, set: { val in store.updatePreferences { $0.vpsEndpoint = val } }))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                SecureField("Token VPS (Facultatif)", text: Binding(get: { store.preferences.vpsAPIKey }, set: { val in store.updatePreferences { $0.vpsAPIKey = val } }))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                Picker("Modèle VPS", selection: Binding(get: { store.preferences.vpsModel }, set: { val in store.updatePreferences { $0.vpsModel = val } })) {
                    Text("Hermes Auto (OmniRoute)").tag("auto/best-coding")
                    Text("Hermes 3 (8B Local)").tag("NousResearch/Hermes-3-Llama-3.1-8B")
                    Text("Hermes Vocal VPS").tag("hermes-agent-vps")
                }
                .pickerStyle(.menu)
            } header: {
                Label("Agent VPS Personnel Hermes", systemImage: "server.rack")
            } footer: {
                Text("Connexion directe à votre instance Oracle Cloud VPS.")
            }
        }
        .navigationTitle("Configuration IA")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LearningLanguagePicker: View {
    let coordinator: ConversationCoordinator
    var body: some View {
        Picker("Learning language", selection: Binding(get: { coordinator.language.id }, set: { coordinator.selectLanguage($0) })) {
            ForEach(LanguageRegistry.all) { language in Text(language.settingsTitle).tag(language.id) }
        }
        .pickerStyle(.menu)
        .disabled(coordinator.isRunning)
        .accessibilityIdentifier("learning-language-picker")
    }
}
