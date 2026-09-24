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
        ZStack {
            FluenceColor.background.ignoresSafeArea()
            
            Group {
                switch tab {
                case 0: immersiveTalkShell { TalkView(coordinator: coordinator) }
                case 1: immersiveShell { ThemesView(coordinator: coordinator) { theme in coordinator.chooseTheme(theme); tab = 0 } }
                case 2: immersiveShell { StudyHubView(coordinator: coordinator) }
                case 3: immersiveShell { WordsView(coordinator: coordinator) }
                default: TalkView(coordinator: coordinator)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: tab)
            
            // Subtlest navigation switcher (bottom floating pill)
            if !coordinator.isRunning || tab != 0 {
                VStack {
                    Spacer()
                    HStack(spacing: 24) {
                        tabButton(icon: "waveform", index: 0)
                        tabButton(icon: "square.grid.2x2", index: 1)
                        tabButton(icon: "graduationcap", index: 2)
                        tabButton(icon: "book", index: 3)
                        
                        Button { coordinator.showSettings = true } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(FluenceColor.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .tint(FluenceColor.ink)
        .sheet(isPresented: $coordinator.showSettings) { SettingsView(coordinator: coordinator) }
        .sheet(isPresented: $coordinator.showAIConsent, onDismiss: { coordinator.resumeAfterAIConsent() }) {
            AIConsentView(agree: { coordinator.acceptAIConsent() }, decline: { coordinator.declineAIConsent() })
        }
        .fullScreenCover(isPresented: $onboarding) { OnboardingView(coordinator: coordinator) { coordinator.store.updatePreferences { $0.hasOnboarded = true }; onboarding = false } }
        .alert("A little interruption", isPresented: Binding(get: { coordinator.error != nil || coordinator.store.error != nil }, set: { if !$0 { coordinator.error = nil; coordinator.store.error = nil } })) {
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
    
    private func tabButton(icon: String, index: Int) -> some View {
        Button { tab = index } label: {
            Image(systemName: tab == index ? "\(icon).fill" : icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tab == index ? FluenceColor.accent : FluenceColor.secondary)
        }
    }

    private func immersiveTalkShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func immersiveShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .background(FluenceColor.background)
                .toolbarBackground(FluenceColor.background, for: .navigationBar)
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
            FluenceAura(energy: max(coordinator.outputLevel, coordinator.inputLevel * 0.45), listening: coordinator.state == .active && !coordinator.isMuted, active: coordinator.state != .closing)
            
            VStack(spacing: 0) {
                // Immersive top area for theme display
                if let themeTitle = coordinator.selectedTheme?.title {
                    Text(themeTitle)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(FluenceColor.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 16)
                }
                
                Spacer()
                
                // Central Whisper Area
                VStack(spacing: 24) {
                    WhisperText(text: linkedCaption, isLarge: true)
                        .padding(.horizontal, 30)
                        .shadow(color: FluenceColor.background.opacity(0.8), radius: 10)
                    
                    if coordinator.store.preferences.meaningVisible {
                        WhisperText(text: AttributedString(coordinator.assistantPassage == nil ? MeaningLanguages.greeting(in: coordinator.store.preferences.meaningLanguage) : !coordinator.meaning.isEmpty ? coordinator.meaning : coordinator.translating ? "..." : ""))
                            .foregroundStyle(FluenceColor.secondary)
                            .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
                
                // Bottom Area (Controls & User Speech)
                VStack(spacing: 20) {
                    if let user = coordinator.userPassage {
                        Text(user.text)
                            .font(.system(.subheadline, design: .rounded))
                            .italic()
                            .foregroundStyle(FluenceColor.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .transition(.opacity)
                    }
                    
                    controls
                        .padding(.bottom, 30)
                }
            }
            .animation(.easeInOut(duration: 0.8), value: coordinator.caption)
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
                var components = URLComponents(); components.scheme = "fluence-word"; components.host = "lookup"
                components.queryItems = [URLQueryItem(name: "word", value: word)]
                part.link = components.url
            }
            part.foregroundColor = FluenceColor.ink; result.append(part)
        }
        return result
    }

    private var controls: some View {
        HStack(spacing: 40) {
            // Typing mode toggle
            Button { typing = true } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 22))
                    .foregroundStyle(FluenceColor.secondary)
            }
            
            // Primary Action (Mic / Start)
            Button {
                if coordinator.state == .active { coordinator.toggleMute() }
                else if !coordinator.isRunning { coordinator.start() }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 84, height: 84)
                    
                    if coordinator.state == .connecting || coordinator.state == .closing {
                        ProgressView().tint(FluenceColor.accent)
                    } else {
                        Image(systemName: coordinator.isMuted && coordinator.state == .active ? "mic.slash" : "mic")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(coordinator.state == .active && !coordinator.isMuted ? FluenceColor.accent : FluenceColor.ink)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .buttonStyle(.plain)
            
            // End / Transcript
            Button {
                if coordinator.isRunning { coordinator.end() }
                else { transcript = coordinator.session }
            } label: {
                Image(systemName: coordinator.isRunning ? "xmark.circle" : "text.bubble")
                    .font(.system(size: 22))
                    .foregroundStyle(FluenceColor.secondary)
            }
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
                else { ProgressView("Finding the meaning…") }
                Spacer()
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading).background(FluenceColor.cream)
                .navigationTitle("A little meaning").navigationBarTitleDisplayMode(.inline)
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
                Text("Say it your way.").font(.system(.title, design: .rounded, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                TextField("Reply in \(coordinator.language.name) or another language", text: $text, axis: .vertical).lineLimit(3...6).focused($focused).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22)).accessibilityIdentifier("typed-reply-input")
                    .onChange(of: text) { _, _ in coordinator.noteTypingActivity() }
                if let error = coordinator.typedReplyError {
                    Text(error).font(.footnote).foregroundStyle(FluenceColor.secondary).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("typed-reply-error")
                }
                Button { sending = true; Task { let ok = await coordinator.sendTyped(text); sending = false; if ok { dismiss() } } } label: {
                    HStack { Text(sending ? "Sending…" : "Send reply").fixedSize(horizontal: false, vertical: true); Spacer(); Image(systemName: "arrow.up") }.padding(18).background(FluenceColor.orange, in: Capsule())
                }.disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("typed-reply-send").id("typed-reply-send")
                Spacer()
            }.padding(26).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(FluenceColor.ink)
            }.accessibilityIdentifier("typed-reply-scroll").background(FluenceColor.cream)
                .onChange(of: coordinator.typedReplyError) { _, error in
                    if error != nil { withAnimation { proxy.scrollTo("typed-reply-send", anchor: .bottom) } }
                }
            }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }.presentationDetents([.medium, .large]).onAppear { coordinator.typedReplyError = nil; coordinator.noteTypingActivity(); focused = true }
    }
}
