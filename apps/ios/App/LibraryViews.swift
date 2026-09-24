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

struct WordsView: View {
    let coordinator: ConversationCoordinator
    @State private var search = ""
    @State private var selected: WordState?
    @State private var sessions = false
    private var learner: LearnerState { coordinator.store.learner }
    private var words: [WordState] { learner.words.filter { search.isEmpty || $0.lemma.localizedCaseInsensitiveContains(search) || $0.meaning.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "Mots et Vocabulaire", title: "Vos mots.", subtitle: "Mots et phrases pour vos futures discussions.")
                if words.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        Image(systemName: "leaf").font(.system(size: 34, weight: .light))
                        Text(search.isEmpty ? "Ils pousseront d'ici." : "Aucun mot correspondant.").font(.system(.title2, design: .rounded, weight: .medium))
                        Text(search.isEmpty ? "Au fil de nos discussions, les mots et expressions utiles apparaîtront ici." : "Essayer un autre mot ou une signification.").font(.subheadline).foregroundStyle(FluenceColor.secondary)
                    }.padding(26).frame(maxWidth: .infinity, alignment: .leading).background(FluenceColor.sage, in: RoundedRectangle(cornerRadius: 28))
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(words) { word in
                            Button { selected = word } label: {
                                HStack(spacing: 18) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(word.lemma).font(.system(size: 32, weight: .bold, design: .rounded))
                                        Text(word.meaning).font(.title3).foregroundStyle(FluenceColor.secondary)
                                    }
                                    Spacer(minLength: 10)
                                    VStack(alignment: .trailing, spacing: 8) { RecallBars(count: word.bars); Text(word.label).font(.caption2).foregroundStyle(FluenceColor.secondary) }
                                }.padding(.vertical, 24)
                            }.buttonStyle(.plain)
                            Divider().overlay(FluenceColor.peach)
                        }
                    }
                }
                HStack { Text("1 · Fragile"); Spacer(); Text("2 · En croissance"); Spacer(); Text("3 · Solide") }.font(.caption).foregroundStyle(FluenceColor.secondary)
                Text("Les barres estiment votre capacité de mémorisation orale. Le niveau FSRS gère l'espacement.").font(.footnote).foregroundStyle(FluenceColor.secondary)
                if !learner.capabilities.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trouver votre voix").font(.system(.title3, design: .rounded, weight: .semibold))
                        ForEach(learner.capabilities, id: \.self) { Text($0).font(.subheadline) }
                        Text("Observé lors de nos conversations. Estimations non officielles.").font(.footnote).foregroundStyle(FluenceColor.secondary)
                    }.padding(22).background(FluenceColor.butter, in: RoundedRectangle(cornerRadius: 24))
                }
            }.padding(26).frame(maxWidth: 1000).frame(maxWidth: .infinity, alignment: .topLeading)
        }.foregroundStyle(FluenceColor.ink).searchable(text: $search, prompt: "Find a word")
            .sheet(item: $selected) { word in WordDetailView(word: word, store: coordinator.store) }
            .sheet(isPresented: $sessions) { SessionHistoryView(store: coordinator.store) }
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
    @State private var key = ""
    @State private var hasKey = CredentialStore.hasKey
    @State private var message: String?
    @State private var exporting = false
    @State private var importing = false
    @State private var backup: BackupDocument?
    @State private var deleting = false
    @State private var notices = false
    @State private var showingAPIKey = false
    private var store: LearningStore { coordinator.store }
    private var totalVoiceSeconds: Double { store.sessions.reduce(0) { $0 + $1.voiceSeconds } }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Learning language", selection: Binding(get: { coordinator.language.id }, set: { coordinator.selectLanguage($0) })) {
                        ForEach(LanguageRegistry.all) { language in Text(language.settingsTitle).tag(language.id) }
                    }
                    .pickerStyle(.menu)
                    
                    Toggle("Meaning subtitles", isOn: Binding(get: { store.preferences.meaningVisible }, set: { value in
                        if value != store.preferences.meaningVisible { coordinator.toggleMeaning() }
                    }))
                    
                    Picker("Meaning language", selection: Binding(get: { store.preferences.meaningLanguage }, set: { coordinator.selectMeaningLanguage($0) })) {
                        ForEach(MeaningLanguages.all, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Correction Level / Niveau", selection: Binding(get: { store.preferences.correctionLevel }, set: { val in store.updatePreferences { $0.correctionLevel = val } })) {
                        Text("Fort / Strict").tag("high")
                        Text("Moyen / Équilibré").tag("medium")
                        Text("Faible / Fluide").tag("low")
                    }
                    .pickerStyle(.menu)
                    TextField("A few things you enjoy", text: Binding(get: { store.preferences.interests }, set: { value in store.updatePreferences { $0.interests = String(value.prefix(500)) } }), axis: .vertical)
                } header: { Text("Just your pace") } footer: { Text(coordinator.isRunning ? "End this conversation to switch languages. Each language keeps its own words and progress." : "Each language keeps its own words and progress. Fluence finds your pace through conversation.") }
                if ManagedAccountConfiguration.load() != nil {
                    Section {
                        NavigationLink { ManagedAccountView() } label: {
                            Label("Account", systemImage: "person.crop.circle")
                        }.disabled(coordinator.isRunning).accessibilityIdentifier("managed-account-settings")
                    }
                }
                Section {
                    Picker("Moteur IA Principal", selection: Binding(get: { store.preferences.providerID }, set: { val in store.updatePreferences { $0.providerID = val } })) {
                        Text("Auto (Groq → Gemini → VPS)").tag("auto")
                        Text("Hermes VPS Agent").tag("hermes_vps")
                        Text("Google Gemini API").tag("google")
                        Text("Groq API Cloud").tag("groq")
                    }
                    .pickerStyle(.menu)
                } header: { Text("MOTEUR IA PRINCIPAL") } footer: {
                    Text("En mode Auto, l'application bascule automatiquement entre Groq, Google Gemini et votre VPS personnel si un service est indisponible.")
                }

                Section {
                    TextField("VPS Endpoint URL", text: Binding(get: { store.preferences.vpsEndpoint }, set: { val in store.updatePreferences { $0.vpsEndpoint = val } }))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("VPS Auth Token (Facultatif)", text: Binding(get: { store.preferences.vpsAPIKey }, set: { val in store.updatePreferences { $0.vpsAPIKey = val } }))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Picker("VPS Model", selection: Binding(get: { store.preferences.vpsModel }, set: { val in store.updatePreferences { $0.vpsModel = val } })) {
                        Text("Hermes Auto").tag("auto/best-coding")
                        Text("Hermes 3 (8B)").tag("NousResearch/Hermes-3-Llama-3.1-8B")
                        Text("Hermes Vocal").tag("hermes-agent-vps")
                    }
                    .pickerStyle(.menu)
                } header: { Text("🏛️ AGENT HERMES VPS PERSONNEL") } footer: {
                    Text("Connecté à votre serveur Oracle VPS personnel.")
                }

                Section {
                    SecureField("Google API Key (AIzaSy...)", text: Binding(get: { store.preferences.googleAPIKey }, set: { val in store.updatePreferences { $0.googleAPIKey = val } }))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Picker("Gemini Model", selection: Binding(get: { store.preferences.geminiModel }, set: { val in store.updatePreferences { $0.geminiModel = val } })) {
                        Text("Gemini 2.0 Flash").tag("gemini-2.0-flash")
                        Text("Gemini 2.0 Lite").tag("gemini-2.0-flash-lite")
                        Text("Gemini 1.5 Flash").tag("gemini-1.5-flash")
                        Text("Gemini 1.5 Pro").tag("gemini-1.5-pro")
                    }
                    .pickerStyle(.menu)
                    Link("Obtenir une clé Gemini gratuite", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                } header: { Text("🌐 MOTEUR GOOGLE GEMINI") }

                Section {
                    Picker("Groq Model", selection: Binding(get: { store.preferences.groqModel }, set: { val in store.updatePreferences { $0.groqModel = val } })) {
                        Text("GPT-OSS 120B").tag("openai/gpt-oss-120b")
                        Text("GPT-OSS 20B").tag("openai/gpt-oss-20b")
                        Text("Qwen 3.8 27B").tag("qwen/qwen3.8-27b")
                        Text("Llama 3.3 70B").tag("llama-3.3-70b-versatile")
                        Text("Llama 3.1 8B").tag("llama-3.1-8b-instant")
                    }
                    .pickerStyle(.menu)
                    DisclosureGroup(isExpanded: $showingAPIKey) {
                        if hasKey { Label("Clé Groq sauvegardée sur cet iPhone", systemImage: "checkmark.shield") }
                        SecureField(hasKey ? "Remplacer la clé Groq (gsk_...)" : "Clé Groq API (gsk_...)", text: $key)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive().accessibilityIdentifier("api-key")
                        Button(hasKey ? "Enregistrer la nouvelle clé" : "Enregistrer la clé") {
                            do { try CredentialStore.save(key); key = ""; hasKey = true; message = "Enregistré avec succès." }
                            catch { message = error.localizedDescription }
                        }.disabled(key.isEmpty || coordinator.isRunning)
                        Link("Obtenir une clé Groq gratuite", destination: URL(string: "https://console.groq.com/keys")!)
                        if hasKey {
                            Button("Supprimer la clé", role: .destructive) {
                                do { try CredentialStore.delete(); hasKey = false; message = "Clé supprimée." }
                                catch { message = error.localizedDescription }
                            }.disabled(coordinator.isRunning)
                        }
                    } label: { Label("Clé API Groq", systemImage: "key").accessibilityIdentifier("advanced-api-key") }
                } header: { Text("⚡ MOTEUR CLOUD GROQ") } footer: {
                    Text("Sélectionnez votre modèle Groq. La reconnaissance vocale utilise Groq Whisper Turbo, et la synthèse vocale utilise les voix de votre iPhone.")
                }
                Section {
                    Picker("Moteur Vocal / Voice Engine", selection: Binding(get: { store.preferences.ttsEngine }, set: { val in store.updatePreferences { $0.ttsEngine = val } })) {
                        Text("Voix iOS Native (AVSpeechSynthesizer)").tag("ios")
                        Text("Voix Google Gemini (IA Audio API)").tag("gemini")
                    }
                    .pickerStyle(.menu)
                    let availableVoices = AVSpeechSynthesisVoice.speechVoices().filter {
                        $0.language.lowercased().hasPrefix(String(store.language.locale.prefix(2)).lowercased())
                    }
                    Picker("Accent Vocal / Voice", selection: Binding(get: { store.preferences.selectedVoiceIdentifier }, set: { val in store.updatePreferences { $0.selectedVoiceIdentifier = val } })) {
                        Text("Automatique (Par défaut)").tag("")
                        ForEach(availableVoices, id: \.identifier) { v in
                            let qualityStr = v.quality == .premium ? " (Premium)" : (v.quality == .enhanced ? " (Enhanced)" : "")
                            Text("\(v.name) · \(v.language)\(qualityStr)").tag(v.identifier)
                        }
                    }
                    .pickerStyle(.menu)
                    Button("Écouter un extrait de voix") {
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
                    }
                } header: { Text("SYNTHÈSE VOCALE") } footer: {
                    Text("Choisissez la voix de Fluence. Appuyez sur Écouter pour tester le rendu.")
                }
                Section {
                    Picker("Conversation limit", selection: Binding(get: { store.preferences.sessionMinutes }, set: { value in store.updatePreferences { $0.sessionMinutes = value } })) {
                        Text("15 minutes").tag(15); Text("30 minutes").tag(30); Text("60 minutes").tag(60)
                    }
                    .pickerStyle(.menu)
                    Picker("Vitesse vocale / Speed", selection: Binding(get: { store.preferences.speechRate }, set: { val in store.updatePreferences { $0.speechRate = val } })) {
                        Text("Lente (0.8x)").tag(Float(0.40))
                        Text("Normale (1.0x)").tag(Float(0.50))
                        Text("Rapide (1.2x)").tag(Float(0.60))
                    }
                    .pickerStyle(.menu)
                    LabeledContent("Temps vocal généré", value: "\(Int(totalVoiceSeconds / 60)) min \(Int(totalVoiceSeconds) % 60) sec")
                    LabeledContent("Estimation coût vocal API", value: String(format: "$%.2f USD", totalVoiceSeconds / 60 * 0.05))
                    LabeledContent("Recherches API effectuées", value: "\(store.sessions.reduce(0) { $0 + $1.searchCalls })")
                    Link("Consulter mon usage sur Groq", destination: URL(string: "https://console.groq.com/")!)
                } header: { Text("Limites & Usage") } footer: {
                    Text("La limite de conversation permet d'éviter de consommer l'API involontairement.")
                }
                Section {
                    Button("Export learning backup", systemImage: "square.and.arrow.up") {
                        do { backup = BackupDocument(data: try store.exportData()); exporting = true } catch { message = error.localizedDescription }
                    }
                    Button("Import learning backup", systemImage: "square.and.arrow.down") { importing = true }.disabled(coordinator.isRunning)
                    Button("Delete all conversations and learning", role: .destructive) { deleting = true }.disabled(coordinator.isRunning)
                } header: { Text("Vos données d'apprentissage") } footer: {
                    Text("L'exportation inclut vos mots et transcriptions de conversation. Vos réglages et votre clé API ne sont pas exportés.")
                }
                Section {
                    Link("Privacy policy", destination: URL(string: "https://fluence.chat/privacy/")!)
                        .accessibilityIdentifier("settings-privacy-policy")
                    Link("Terms of use", destination: URL(string: "https://fluence.chat/terms/")!)
                        .accessibilityIdentifier("settings-terms")
                    Link("Contact support", destination: URL(string: "https://fluence.chat/support/")!)
                        .accessibilityIdentifier("settings-support")
                } header: { Text("Aide & Vie privée") }
                Section {
                    Text("Fluence 0.2 · Personal build").font(.footnote)
                    Text("Teacher: Groq Llama 3.3 70B · STT: Groq Whisper").font(.footnote)
                    Link("Groq data controls", destination: URL(string: "https://groq.com/privacy/")!)
                    Text("L'audio et le texte sélectionné sont traités par Groq (ou votre VPS) pendant la discussion. L'audio brut n'est pas sauvegardé par Fluence.").font(.footnote)
                    Button("Open-source notices") { notices = true }
                }
            }.scrollContentBackground(.hidden).background(FluenceColor.cream).tint(FluenceColor.secondary)
                .navigationTitle("Réglages").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { key = ""; dismiss() } } }
        }
        .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "Fluence-learning-backup") { result in if case .failure(let error) = result { message = error.localizedDescription } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(); let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }
                try store.importData(Archive.readImportData(from: url)); message = "Sauvegarde importée avec succès."
            } catch { message = error.localizedDescription }
        }
        .confirmationDialog("Supprimer toutes les données d'apprentissage sur cet iPhone ?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Tout supprimer", role: .destructive) { coordinator.deleteLearningData() }
        } message: { Text("Ceci supprimera vos conversations, vocabulaires et progrès. Exportez une sauvegarde d'abord si vous souhaitez les conserver. Votre clé API et vos préférences resteront.") }
        .sheet(isPresented: $notices) {
            NavigationStack {
                ScrollView { Text(Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "Notices unavailable.").font(.footnote).padding(24).textSelection(.enabled) }
                    .navigationTitle("Open-source notices").navigationBarTitleDisplayMode(.inline)
            }
        }
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
