import SwiftUI
import MuralCore

struct RootView: View {
    @State private var coordinator: ConversationCoordinator
    @State private var tab = 0
    @State private var onboarding = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var colorScheme: ColorScheme? {
        switch coordinator.store.preferences.appearance {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
    
    init(store: LearningStore) {
        let coordinator = ConversationCoordinator(store: store)
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--preview"), ProcessInfo.processInfo.arguments.contains("--preview-existing-user") {
            store.updatePreferences { $0.hasOnboarded = true }
        }
        if let screen = ScreenshotPreview.screen { coordinator.prepareScreenshot(screen) }
        coordinator.prepareTypedReplyPreview()
        coordinator.prepareConversationPolicyPreview()
        _tab = State(initialValue: ScreenshotPreview.tab)
        #endif
        _coordinator = State(initialValue: coordinator)
    }
    
    var body: some View {
        @Bindable var coordinator = coordinator
        TabView(selection: $tab) {
            NavigationStack {
                TalkView(coordinator: coordinator)
            }
            .tabItem {
                Label("Discussion", systemImage: "waveform")
            }
            .tag(0)
            
            NavigationStack {
                StudyHubView(coordinator: coordinator)
            }
            .tabItem {
                Label("Professeur", systemImage: "graduationcap.fill")
            }
            .tag(1)
            
            NavigationStack {
                WordsView(coordinator: coordinator)
            }
            .tabItem {
                Label("Vocabulaire", systemImage: "book.fill")
            }
            .tag(2)
            
            NavigationStack {
                ThemesView(coordinator: coordinator) { theme in
                    coordinator.chooseTheme(theme)
                    tab = 0
                }
            }
            .tabItem {
                Label("Thèmes", systemImage: "sparkles")
            }
            .tag(3)
        }
        .tint(FluenceColor.accent)
        .preferredColorScheme(colorScheme)
        .sheet(isPresented: $coordinator.showSettings) {
            SettingsView(coordinator: coordinator)
                .preferredColorScheme(colorScheme)
                .tint(FluenceColor.accent)
        }
        .sheet(isPresented: $coordinator.showAIConsent, onDismiss: { coordinator.resumeAfterAIConsent() }) {
            AIConsentView(agree: { coordinator.acceptAIConsent() }, decline: { coordinator.declineAIConsent() })
                .preferredColorScheme(colorScheme)
                .tint(FluenceColor.accent)
        }
        .fullScreenCover(isPresented: $onboarding) { OnboardingView(coordinator: coordinator) { coordinator.store.updatePreferences { $0.hasOnboarded = true }; onboarding = false } }
        .alert("Information", isPresented: Binding(get: { coordinator.error != nil || coordinator.store.error != nil }, set: { if !$0 { coordinator.error = nil; coordinator.store.error = nil } })) {
            Button("OK", role: .cancel) { coordinator.error = nil; coordinator.store.error = nil }
        } message: { Text(coordinator.error ?? coordinator.store.error ?? "") }
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            #if DEBUG && targetEnvironment(simulator)
            if arguments.contains("--preview") && arguments.contains("--preview-onboarding") {
                onboarding = !coordinator.store.preferences.hasOnboarded
                return
            }
            #endif
            onboarding = !coordinator.store.preferences.hasOnboarded && !arguments.contains("--preview") && !AudioVerification.requested
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { coordinator.background() }
            else if phase == .active { coordinator.resume() }
        }
    }
}

struct TalkView: View {
    @Bindable var coordinator: ConversationCoordinator
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var typing = false
    @State private var transcript: SessionRecord?
    @State private var lookup: WordLookup?
    
    var body: some View {
        ZStack {
            FluenceColor.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Status & Scenario Bar
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(coordinator.state == .active ? FluenceColor.emerald : FluenceColor.secondary.opacity(0.40))
                            .frame(width: 8, height: 8)
                        Text(coordinator.state == .active ? (coordinator.store.preferences.pedagogicalMode == "teacher" ? "Professeur Actif" : "En écoute") : "Prêt")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(coordinator.state == .active ? FluenceColor.emerald : FluenceColor.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(FluenceColor.surface, in: Capsule())
                    
                    Spacer()
                    
                    if let theme = coordinator.selectedTheme {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text(theme.title)
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(FluenceColor.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(FluenceColor.surface, in: Capsule())
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                
                Spacer(minLength: 20)
                
                // Central Conversation Card (Calm, High-Contrast & Legible)
                VStack(spacing: 18) {
                    Text(linkedCaption)
                        .font(.system(size: coordinator.assistantPassage == nil ? 32 : 24, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FluenceColor.ink)
                        .padding(.horizontal, 24)
                        .environment(\.openURL, OpenURLAction { url in
                            guard url.scheme == "fluence-word", let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let word = components.queryItems?.first?.value else { return .discarded }
                            lookup = WordLookup(word: word, sentence: coordinator.caption)
                            return .handled
                        })
                    
                    if coordinator.store.preferences.meaningVisible {
                        HStack(spacing: 6) {
                            Image(systemName: "captions.bubble.fill")
                                .font(.caption2)
                                .foregroundStyle(FluenceColor.accent)
                            Text(coordinator.assistantPassage == nil ? MeaningLanguages.greeting(in: coordinator.store.preferences.meaningLanguage) : !coordinator.meaning.isEmpty ? coordinator.meaning : coordinator.translating ? "Compréhension en cours…" : "")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(FluenceColor.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(FluenceColor.surfaceSecondary, in: Capsule())
                        .padding(.horizontal, 20)
                    }
                    
                    if let user = coordinator.userPassage {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundStyle(FluenceColor.secondary)
                            Text("« \(user.text) »")
                                .font(.system(.subheadline, design: .rounded))
                                .italic()
                                .foregroundStyle(FluenceColor.secondary)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(FluenceColor.surface, in: Capsule())
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(FluenceColor.surface.opacity(0.85), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 18)
                
                // Subtle Calm Voice Waveform Presence
                SoberWaveformView(
                    energy: max(coordinator.outputLevel, coordinator.inputLevel),
                    isListening: coordinator.state == .active && !coordinator.isMuted,
                    isSpeaking: coordinator.outputLevel > 0.06,
                    onTap: {
                        if coordinator.state == .active { coordinator.toggleMute() }
                        else if !coordinator.isRunning { coordinator.start() }
                    }
                )
                .padding(.top, 16)
                
                Spacer(minLength: 20)
                
                // Bottom Clean Control Bar
                HStack(spacing: 32) {
                    // Keyboard input button
                    Button {
                        typing = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(FluenceColor.surface)
                                .frame(width: 52, height: 52)
                            Image(systemName: "keyboard")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(FluenceColor.ink)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Main Clean Voice Action Button
                    Button {
                        if coordinator.state == .active { coordinator.toggleMute() }
                        else if !coordinator.isRunning { coordinator.start() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: coordinator.state == .active && !coordinator.isMuted ? "pause.fill" : "mic.fill")
                                .font(.system(size: 19, weight: .bold))
                            Text(coordinator.state == .active ? (coordinator.isMuted ? "Reprendre" : "En écoute") : "Parler")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 16)
                        .background(
                            coordinator.state == .active && !coordinator.isMuted
                                ? FluenceColor.emerald
                                : FluenceColor.accent,
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Transcript / End button
                    Button {
                        if coordinator.isRunning { coordinator.end() }
                        else { transcript = coordinator.session }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(FluenceColor.surface)
                                .frame(width: 52, height: 52)
                            Image(systemName: coordinator.isRunning ? "stop.fill" : "text.bubble")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(coordinator.isRunning ? FluenceColor.coral : FluenceColor.ink)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(coordinator.session == nil && !coordinator.isRunning)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(FluenceColor.surface.opacity(0.70), in: Capsule())
                .padding(.bottom, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(LanguageRegistry.all) { lang in
                        Button {
                            coordinator.selectLanguage(lang.id)
                        } label: {
                            HStack {
                                Text("\(lang.flag) \(lang.settingsTitle)")
                                if coordinator.language.id == lang.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(coordinator.language.flag)
                        Text(coordinator.language.name)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Text("· \(coordinator.store.learner.levelLabel)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(FluenceColor.accent)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(FluenceColor.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(FluenceColor.surface, in: Capsule())
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("Fluence")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(FluenceColor.ink)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    coordinator.showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(FluenceColor.ink)
                        .padding(8)
                        .background(FluenceColor.surface, in: Circle())
                }
            }
        }
        .sheet(isPresented: $typing) { TypedReplyView(coordinator: coordinator) }
        .sheet(item: $transcript) { session in
            TranscriptView(session: session, meaningLanguage: coordinator.store.preferences.meaningLanguage)
        }
        .sheet(item: $lookup) { item in LookupView(item: item, coordinator: coordinator) }
    }
    
    private var linkedCaption: AttributedString {
        var result = AttributedString()
        for segment in CaptionWords.segments(coordinator.caption, languageID: coordinator.language.id) {
            var part = AttributedString(segment.text)
            if coordinator.assistantPassage != nil, let word = segment.lookup {
                var components = URLComponents()
                components.scheme = "fluence-word"
                components.host = "lookup"
                components.queryItems = [URLQueryItem(name: "word", value: word)]
                part.link = components.url
            }
            part.foregroundColor = FluenceColor.ink
            result.append(part)
        }
        return result
    }
}

struct WordLookup: Identifiable { var id = UUID(); var word: String; var sentence: String }
struct LookupView: View {
    let item: WordLookup
    let coordinator: ConversationCoordinator
    @State private var explanation: String?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(item.word).font(.system(.largeTitle, design: .rounded, weight: .medium))
                if coordinator.language.id == "zh" { PinyinHelp(text: item.word) }
                Text(item.sentence).font(.title3).foregroundStyle(FluenceColor.secondary)
                if let explanation { Text(explanation).font(.body).textSelection(.enabled) }
                else if let error { Text(error).foregroundStyle(FluenceColor.secondary) }
                else { ProgressView("Recherche de la définition…") }
                Spacer()
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading).background(FluenceColor.cream)
                .navigationTitle("Signification").navigationBarTitleDisplayMode(.inline)
        }.presentationDetents([.medium, .large])
            .task { do { explanation = try await coordinator.lookup(word: item.word, sentence: item.sentence) } catch { self.error = error.localizedDescription } }
    }
}

struct TypedReplyView: View {
    let coordinator: ConversationCoordinator
    @State private var text = ""
    @State private var sending = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Répondre par écrit").font(.system(.title, design: .rounded, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                TextField("Répondez en \(coordinator.language.name) ou en français", text: $text, axis: .vertical).lineLimit(3...6).focused($focused).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22)).accessibilityIdentifier("typed-reply-input")
                    .onChange(of: text) { _, _ in coordinator.noteTypingActivity() }
                if let error = coordinator.typedReplyError {
                    Text(error).font(.footnote).foregroundStyle(FluenceColor.secondary).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("typed-reply-error")
                }
                Button { sending = true; Task { let ok = await coordinator.sendTyped(text); sending = false; if ok { dismiss() } } } label: {
                    HStack { Text(sending ? "Envoi…" : "Envoyer la réponse").fixedSize(horizontal: false, vertical: true); Spacer(); Image(systemName: "arrow.up") }.padding(18).background(FluenceColor.orange, in: Capsule())
                }.disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("typed-reply-send").id("typed-reply-send")
                Spacer()
            }.padding(26).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(FluenceColor.ink)
            }.accessibilityIdentifier("typed-reply-scroll").background(FluenceColor.cream)
                .onChange(of: coordinator.typedReplyError) { _, error in
                    if error != nil { withAnimation { proxy.scrollTo("typed-reply-send", anchor: .bottom) } }
                }
            }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
        }.presentationDetents([.medium, .large]).onAppear { coordinator.typedReplyError = nil; coordinator.noteTypingActivity(); focused = true }
    }
}
