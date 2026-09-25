import SwiftUI
import MuralCore

struct RootView: View {
    @State private var coordinator: ConversationCoordinator
    @State private var tab = 0
    @State private var onboarding = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
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
        .sheet(isPresented: $coordinator.showSettings) { SettingsView(coordinator: coordinator) }
        .sheet(isPresented: $coordinator.showAIConsent, onDismiss: { coordinator.resumeAfterAIConsent() }) {
            AIConsentView(agree: { coordinator.acceptAIConsent() }, decline: { coordinator.declineAIConsent() })
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
            
            // Subtle glowing perimeter aura
            FluenceAura(
                energy: max(coordinator.outputLevel, coordinator.inputLevel * 0.45),
                listening: coordinator.state == .active && !coordinator.isMuted,
                active: coordinator.state != .closing
            )
            
            VStack(spacing: 0) {
                // Top Header: CEFR Level Badge, Theme / Status, and Settings
                HStack {
                    Button {
                        coordinator.showSettings = true
                    } label: {
                        HStack(spacing: 5) {
                            Text(coordinator.language.flag)
                            Text(coordinator.store.learner.levelLabel)
                                .font(.system(.caption, design: .rounded, weight: .bold))
                        }
                        .foregroundStyle(FluenceColor.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(FluenceColor.accent.opacity(0.12), in: Capsule())
                    }
                    
                    Spacer()
                    
                    if let themeTitle = coordinator.selectedTheme?.title {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text(themeTitle)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(FluenceColor.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    } else {
                        Text(coordinator.status)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(FluenceColor.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        coordinator.showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(FluenceColor.secondary)
                            .padding(8)
                            .background(Color.white.opacity(0.06), in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                Spacer(minLength: 20)
                
                // Central High-Contrast Text Area
                VStack(spacing: 20) {
                    Text(linkedCaption)
                        .font(.system(size: coordinator.assistantPassage == nil ? 38 : 26, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FluenceColor.ink)
                        .padding(.horizontal, 28)
                        .environment(\.openURL, OpenURLAction { url in
                            guard url.scheme == "fluence-word", let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let word = components.queryItems?.first?.value else { return .discarded }
                            lookup = WordLookup(word: word, sentence: coordinator.caption)
                            return .handled
                        })
                    
                    if coordinator.store.preferences.meaningVisible {
                        Text(coordinator.assistantPassage == nil ? MeaningLanguages.greeting(in: coordinator.store.preferences.meaningLanguage) : !coordinator.meaning.isEmpty ? coordinator.meaning : coordinator.translating ? "Traduction en cours…" : "")
                            .font(.system(.title3, design: .rounded))
                            .foregroundStyle(FluenceColor.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                
                Spacer(minLength: 20)
                
                // Bottom User Feedback & Primary Controls
                VStack(spacing: 20) {
                    if let user = coordinator.userPassage {
                        Text("« \(user.text) »")
                            .font(.system(.subheadline, design: .rounded))
                            .italic()
                            .foregroundStyle(FluenceColor.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .transition(.opacity)
                    }
                    
                    if let notice = coordinator.notice {
                        Text(notice)
                            .font(.caption)
                            .foregroundStyle(FluenceColor.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    controls
                        .padding(.bottom, 16)
                }
            }
        }
        .navigationTitle("Fluence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(LanguageRegistry.all) { lang in
                        Button {
                            coordinator.selectLanguage(lang.id)
                        } label: {
                            HStack {
                                Text(lang.settingsTitle)
                                if coordinator.language.id == lang.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(coordinator.language.name)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(FluenceColor.ink)
                        Image(systemName: "chevron.down")
                            .font(.caption2.bold())
                            .foregroundStyle(FluenceColor.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(FluenceColor.accent.opacity(0.1), in: Capsule())
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    coordinator.showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(FluenceColor.ink)
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

    private var controls: some View {
        HStack(spacing: 44) {
            // Typing mode button
            Button {
                typing = true
            } label: {
                ZStack {
                    Circle()
                        .fill(FluenceColor.ink.opacity(0.06))
                        .frame(width: 52, height: 52)
                    Image(systemName: "keyboard")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(FluenceColor.ink)
                }
            }
            .buttonStyle(.plain)
            
            // Big Central Mic Action Button
            Button {
                if coordinator.state == .active { coordinator.toggleMute() }
                else if !coordinator.isRunning { coordinator.start() }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: coordinator.state == .active && !coordinator.isMuted ?
                                    [FluenceColor.accent, Color(red: 0.5, green: 0.35, blue: 0.95)] :
                                    [FluenceColor.accent.opacity(0.85), FluenceColor.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 76, height: 76)
                        .shadow(color: FluenceColor.accent.opacity(0.3), radius: 8, y: 4)
                    
                    if coordinator.state == .connecting || coordinator.state == .closing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: coordinator.isMuted && coordinator.state == .active ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .buttonStyle(.plain)
            
            // End conversation / Transcript button
            Button {
                if coordinator.isRunning { coordinator.end() }
                else { transcript = coordinator.session }
            } label: {
                ZStack {
                    Circle()
                        .fill(FluenceColor.ink.opacity(0.06))
                        .frame(width: 52, height: 52)
                    Image(systemName: coordinator.isRunning ? "xmark" : "text.bubble")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(coordinator.isRunning ? .red : FluenceColor.ink)
                }
            }
            .buttonStyle(.plain)
            .disabled(coordinator.session == nil && !coordinator.isRunning)
        }
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
