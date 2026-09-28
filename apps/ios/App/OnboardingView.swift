import SwiftUI
import MuralCore

struct OnboardingView: View {
    let coordinator: ConversationCoordinator
    let done: () -> Void
    @State private var step = 0
    @State private var targetID: String
    @State private var meaningLanguage: String
    @State private var hasChosenMeaning: Bool
    @State private var apiKeyInput: String = ""
    @State private var greetingIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase

    init(coordinator: ConversationCoordinator, done: @escaping () -> Void) {
        self.coordinator = coordinator
        self.done = done
        _targetID = State(initialValue: coordinator.language.id)
        _meaningLanguage = State(initialValue: coordinator.store.preferences.meaningLanguage.isEmpty ? "French" : coordinator.store.preferences.meaningLanguage)
        _hasChosenMeaning = State(initialValue: coordinator.store.preferences.meaningLanguage != Preferences().meaningLanguage)
        _apiKeyInput = State(initialValue: CredentialStore.read() ?? "")
    }

    private var target: LanguageModule { LanguageRegistry.module(for: targetID) ?? .german }
    private var greeting: String { reduceMotion ? target.greeting : LanguageRegistry.all[greetingIndex].greeting }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if step > 0 {
                    Button { move(to: step - 1) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 20, weight: .medium)).frame(width: 44, height: 44)
                            .modifier(SoftGlass())
                    }.accessibilityLabel("Retour").accessibilityIdentifier("onboarding-back")
                } else { Brand() }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Capsule().fill(index == step ? FluenceColor.accent : FluenceColor.secondary.opacity(0.3))
                            .frame(width: index == step ? 24 : 8, height: 6)
                    }
                }.accessibilityElement(children: .ignore).accessibilityLabel("Étape \(step + 1) sur 3")
            }.padding(.horizontal, 26).padding(.top, 8).frame(height: 54)

            ScrollView {
                VStack(spacing: step == 0 ? 22 : 18) {
                    VStack(spacing: 4) {
                        FluenceAura().frame(height: typeSize.isAccessibilitySize ? 80 : step == 0 ? 120 : 70)
                        Text(greeting)
                            .font(.system(size: typeSize.isAccessibilitySize ? 46 : step == 0 ? 56 : 46, weight: .semibold, design: .rounded))
                            .tracking(-1.5).id(greeting)
                            .transition(.opacity)
                            .frame(height: step == 0 ? 72 : 56)
                            .accessibilityIdentifier("onboarding-greeting")
                    }.padding(.top, step == 0 ? 6 : 0).accessibilityElement(children: .ignore).accessibilityLabel("Bienvenue sur Fluence")

                    Group {
                        if step == 0 { languageStep }
                        else if step == 1 { meaningStep }
                        else { aiEngineStep }
                    }.id(step).transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 14)))
                    
                    if step == 1 && typeSize.isAccessibilitySize { consentDetails }
                }.padding(.horizontal, 26).padding(.bottom, 22)
            }.scrollIndicators(.hidden).id(step)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                if step == 1 && !typeSize.isAccessibilitySize { consentDetails }
                Button(step < 2 ? "Continuer" : "🚀 Commencer l'apprentissage") { advance() }
                    .font(.system(.headline, design: .rounded)).bold().multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(FluenceColor.accent, in: Capsule())
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("onboarding-continue")
                if !typeSize.isAccessibilitySize {
                    Text(step == 0 ? "Nous adapterons le rythme de la conversation à votre niveau." : (step == 1 ? "Vous pouvez modifier ces deux langues à tout moment dans les Réglages." : "Vos données et clés restent chiffrées sur votre iPhone."))
                        .font(.caption).foregroundStyle(FluenceColor.secondary).multilineTextAlignment(.center)
                }
            }.padding(.horizontal, 26).padding(.top, 16).padding(.bottom, 16)
                .background(FluenceColor.surface)
        }
        .background(FluenceColor.background.ignoresSafeArea())
        .foregroundStyle(FluenceColor.ink).tint(FluenceColor.accent)
        .interactiveDismissDisabled()
        .sensoryFeedback(.selection, trigger: targetID)
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(3.8)) } catch { return }
                guard !Task.isCancelled else { return }
                if scenePhase == .active {
                    withAnimation(.easeInOut(duration: 0.6)) { greetingIndex = (greetingIndex + 1) % LanguageRegistry.all.count }
                }
            }
        }
    }

    private var consentDetails: some View {
        VStack(spacing: 8) {
            Text(AIProcessingConsent.summary)
                .font(.footnote).foregroundStyle(FluenceColor.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("onboarding-ai-consent")
            Link("Politique de confidentialité", destination: URL(string: "https://fluence.chat/privacy/")!)
                .font(.footnote).underline().foregroundStyle(FluenceColor.accent).accessibilityIdentifier("onboarding-privacy-policy")
        }
    }

    private var languageStep: some View {
        VStack(spacing: 18) {
            Text("Quelle langue\nsouhaitez-vous parler ?")
                .font(.system(.title2, design: .rounded, weight: .bold)).tracking(-0.5)
                .multilineTextAlignment(.center).accessibilityIdentifier("onboarding-language-title")
            VStack(spacing: 10) {
                ForEach(LanguageRegistry.all) { language in
                    Button { targetID = language.id } label: {
                        HStack(spacing: 14) {
                            Text(language.flag)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(language.nativeName).font(.system(.headline, design: .rounded)).bold()
                                Text(language.settingsTitle).font(.caption).foregroundStyle(FluenceColor.secondary)
                            }
                            Spacer()
                            Image(systemName: targetID == language.id ? "checkmark.circle.fill" : "circle")
                                .font(.title3).foregroundStyle(targetID == language.id ? FluenceColor.accent : FluenceColor.secondary.opacity(0.4))
                        }.padding(.horizontal, 18).padding(.vertical, 13).frame(maxWidth: .infinity)
                            .background(targetID == language.id ? FluenceColor.surfaceSecondary : FluenceColor.surface, in: RoundedRectangle(cornerRadius: 20))
                            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(targetID == language.id ? FluenceColor.accent.opacity(0.6) : .clear, lineWidth: 1.5) }
                    }.buttonStyle(.plain)
                        .accessibilityLabel(language.settingsTitle)
                        .accessibilityAddTraits(targetID == language.id ? .isSelected : [])
                        .accessibilityIdentifier("onboarding-language-\(language.id)")
                }
            }
        }
    }

    private var meaningStep: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text("Une aide dans\nvotre langue.")
                    .font(.system(.title2, design: .rounded, weight: .bold)).tracking(-0.5)
                Text("Fluence s'exprime en \(target.name). Choisissez votre langue de confort pour la traduction et les explications pédagogiques.")
                    .font(.subheadline).foregroundStyle(FluenceColor.secondary)
            }.multilineTextAlignment(.center).accessibilityIdentifier("onboarding-meaning-title")
            
            Picker("Langue de traduction", selection: Binding(get: { meaningLanguage }, set: { meaningLanguage = $0; hasChosenMeaning = true })) {
                ForEach(MeaningLanguages.all, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.menu).font(.system(.headline, design: .rounded))
                .padding(18).frame(maxWidth: .infinity)
                .background(FluenceColor.surface, in: RoundedRectangle(cornerRadius: 20))
                .accessibilityIdentifier("onboarding-meaning-picker")
            
            VStack(spacing: 8) {
                Text(target.greeting).font(.system(.title2, design: .rounded, weight: .semibold))
                if target.id == "zh", let reading = MandarinPinyin.reading(target.greeting) {
                    Text(reading).font(.callout).foregroundStyle(FluenceColor.secondary)
                }
                Text(MeaningLanguages.greeting(in: meaningLanguage)).font(.body).foregroundStyle(FluenceColor.secondary)
                    .accessibilityIdentifier("onboarding-meaning-example")
                Text("Activez les traductions et sous-titres dès que vous en avez besoin.").font(.caption).foregroundStyle(FluenceColor.secondary).padding(.top, 8)
            }.multilineTextAlignment(.center).padding(.vertical, 12)
        }
    }

    private var aiEngineStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: "sparkles").font(.system(size: 36, weight: .medium)).foregroundStyle(FluenceColor.accent)
                Text("Moteur d'Intelligence Artificielle")
                    .font(.system(.title2, design: .rounded, weight: .bold)).tracking(-0.5)
                Text("Fluence fonctionne immédiatement avec le Mode Auto intelligent. Vous pouvez également connecter vos propres clés API (OpenAI ChatGPT, Claude, Gemini, Groq, DeepSeek, Mistral, OpenRouter ou VPS).")
                    .font(.subheadline).foregroundStyle(FluenceColor.secondary).multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(FluenceColor.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mode Auto Activé")
                            .font(.headline)
                        Text("Groq · Gemini · ChatGPT · Claude · VPS")
                            .font(.caption)
                            .foregroundStyle(FluenceColor.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(FluenceColor.surface, in: RoundedRectangle(cornerRadius: 18))
                
                Text("Vous pourrez ajouter vos clés API personnelles à tout moment dans Réglages > Fournisseurs d'IA.")
                    .font(.caption)
                    .foregroundStyle(FluenceColor.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.top, 8)
        }
    }

    private func advance() {
        if step == 0 {
            if !hasChosenMeaning && meaningLanguage == target.name {
                let preferredNames = Locale.preferredLanguages.map { identifier in
                    let code = Locale(identifier: identifier).language.languageCode?.identifier ?? identifier
                    if code == "zh" { return "Chinese (Simplified)" }
                    return LanguageRegistry.module(for: code)?.name ?? Locale(identifier: "fr").localizedString(forLanguageCode: code)?.capitalized ?? ""
                }
                meaningLanguage = preferredNames.first { MeaningLanguages.all.contains($0) && $0 != target.name }
                    ?? MeaningLanguages.all.first { $0 != target.name } ?? "French"
            }
            move(to: 1)
        } else if step == 1 {
            move(to: 2)
        } else {
            let cleanKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanKey.isEmpty {
                try? CredentialStore.save(cleanKey, for: "groq")
                try? CredentialStore.save(cleanKey, for: "owner")
            }
            coordinator.selectLanguage(targetID)
            coordinator.selectMeaningLanguage(meaningLanguage)
            coordinator.store.updatePreferences { $0.meaningVisible = true; $0.aiConsentVersion = AIProcessingConsent.version }
            done()
        }
    }

    private func move(to value: Int) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) { step = value }
    }
}

enum AIProcessingConsent {
    static let version = 2
    static let summary = "Avec votre accord, Fluence transmet votre audio et vos phrases au moteur d'IA sélectionné (Groq, OpenAI, Gemini, Claude ou votre VPS) pour générer les conversations interactives. Vos données restent strictement privées."
    enum ConsentError: LocalizedError {
        case required
        var errorDescription: String? { "Avant d'utiliser les fonctionnalités vocales d'IA, ouvrez l'onglet Parler pour valider le consentement de traitement audio." }
    }
}

struct AIConsentView: View {
    let agree: () -> Void
    let decline: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "waveform.bubble").font(.system(size: 32, weight: .light)).foregroundStyle(FluenceColor.accent)
            Text("Avant de commencer").font(.system(.title, design: .rounded, weight: .bold))
                .accessibilityIdentifier("ai-consent-title")
            Text(AIProcessingConsent.summary).font(.body)
            Text("Votre progression et vos données d'apprentissage restent enregistrées sur cet iPhone. Fluence ne stocke aucun enregistrement audio brut. Vous pouvez explorer vos fiches et cours librement sans accepter.")
                .font(.subheadline).foregroundStyle(FluenceColor.secondary)
            Link("Politique de confidentialité", destination: URL(string: "https://fluence.chat/privacy/")!).font(.subheadline).underline().foregroundStyle(FluenceColor.accent)
            Button("Accepter et continuer", action: agree).font(.headline).frame(maxWidth: .infinity).padding(18)
                .background(FluenceColor.accent, in: Capsule()).foregroundStyle(.white).accessibilityIdentifier("ai-consent-agree")
            Button("Pas maintenant", action: decline).font(.subheadline).frame(maxWidth: .infinity)
                .foregroundStyle(FluenceColor.secondary)
                .accessibilityIdentifier("ai-consent-decline")
        }.padding(28).foregroundStyle(FluenceColor.ink).tint(FluenceColor.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(FluenceColor.background)
            .presentationDetents([.large]).interactiveDismissDisabled()
    }
}
