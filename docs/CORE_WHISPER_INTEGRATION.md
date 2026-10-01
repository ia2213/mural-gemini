# Core Whisper.cpp On-Device Integration Plan

> Ticket #7 — Instructeur d'accent avec Whisper.cpp embarqué  
> État : Planifié · Code complet à implémenter dans ticket dédié

---

## Contexte

Intégrer Whisper.cpp (implémentation C++ de Whisper d'OpenAI) de manière **on-device** dans Fluence iOS pour fournir un instructeur d'accent :

- Transcription de la voix de l'apprenant via le modèle Whisper embarqué
- Calcul du **WER** (Word Error Rate) entre la transcription et le texte cible attendu
- Scoring d'accent (0-100) avec niveaux (Débutant → Expert)
- Affichage du score dans l'UI après chaque réponse vocale

**Contraintes** : iOS 15+, ARM64, Swift 5.9+.

---

## (a) Téléchargement et ajout du modèle Whisper au bundle Xcode

### Modèles disponibles

| Modèle | Taille (int8) | Latence estimée (iPhone 15) | Précision |
|--------|---------------|-----------------------------|-----------|
| `ggml-base.en.bin` | ~72 Mo | ~1-2 s | Bonne |
| `ggml-small.en.bin` | ~130 Mo | ~3-5 s | Meilleure |
| `ggml-medium.en.bin` | ~490 Mo | ~10-15 s | Excellente (peut-être trop lourd) |

**Recommandation** : `ggml-small.en.bin` comme compromis taille/précision pour l'instructeur d'accent.

### Téléchargement

```bash
# Depuis le repo whisper.cpp
cd whisper.cpp
bash ./models/download-ggml-model.sh small.en
# ou manuellement :
# https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin
```

### Ajout au bundle Xcode

1. Copier `ggml-small.en.bin` dans `apps/ios/App/Assets.xcassets/WhisperModel/` (créer le dossier)
2. Dans `Fluence.xcodeproj` → cible **Fluence** → **Build Phases** → **Copy Bundle Resources**, ajouter le fichier .bin
3. Alternative : fournir le modèle via un dossier nommé `Models` dans le projet avec "Target Membership" coché

**Note** : Le modèle sera accessible via `Bundle.main.url(forResource: "ggml-small.en", withExtension: "bin")`.

---

## (b) Compilation de whisper.cpp pour iOS (ARM64)

### Option 1 : Sous-module Git + compilation native (recommandé)

```bash
# Dans le répertoire du projet iOS
cd ../..  # au niveau de Fluence.xcodeproj
git submodule add https://github.com/ggerganov/whisper.cpp.git whisper.cpp
```

**Configuration CMake pour iOS** :

```bash
# Dans whisper.cpp/
mkdir build-ios && cd build-ios
cmake -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
      -DCMAKE_BUILD_TYPE=Release \
      -DWHISPER_NO_GUI=ON \
      -DWHISPER_NO_WEBRTC=ON \
      ..

make -j4
```

Cela produit `libwhisper.a` (archive statique) compilée pour ARM64 iOS.

### Option 2 : Swift Package Manager (alternative)

whisper.cpp peut être intégré via SPM en utilisant un `Package.swift` personnalisé qui pointe vers le repo et compile les Sources C++. Cependant, cette approche est moins éprouvée — la méthode sous-module + librairie statique est plus fiable.

### Intégration de la librairie

Après compilation, copier `libwhisper.a` dans un dossier `Vendor/` du projet et l'ajouter au **Link Binary With Libraries** dans Xcode. Configurer les **Header Search Paths** pour pointer vers les headers de whisper.cpp.

---

## (c) Bridging Header Swift → C++

Swift ne peut pas appeler directement du C++ — il faut un *bridging header* C qui expose une API C-compatible, puis le bridging header Swift qui inclut ce fichier C.

### Architecture de l'interface

```
whisper.cpp/include/whisper.h     ← API C++ originale
Core/WhisperBridge.h               ← API C (extern "C") — bridge
Core/WhisperBridge.mm              ← Implémentation Objective-C++ (appelle whisper.cpp)
Core/WhisperEngine.swift           ← Swift — consomme WhisperBridge
```

### whisper_bridge.h (fichier C)

```c
// Core/WhisperBridge.h
#ifndef WHISPER_BRIDGE_H
#define WHISPER_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void* WhisperContextHandle;

WhisperContextHandle whisper_load_model(const char* model_path);
void whisper_free(WhisperContextHandle ctx);
int whisper_transcribe(WhisperContextHandle ctx, const char* audio_path,
                        char* output_buffer, int output_buffer_size);

#ifdef __cplusplus
}
#endif

#endif
```

### whisper_bridge.mm (Objective-C++)

```objc
// Core/WhisperBridge.mm
#import "WhisperBridge.h"
#include "whisper.h"
#include <string>

WhisperContextHandle whisper_load_model(const char* path) {
    return (WhisperContextHandle)whisper_init_from_file(path);
}

void whisper_free(WhisperContextHandle ctx) {
    if (ctx) whisper_free((struct whisper_context*)ctx);
}

int whisper_transcribe(WhisperContextHandle ctx, const char* audio_path,
                       char* out_buf, int buf_size) {
    auto* wctx = (struct whisper_context*)ctx;
    // whisper_process_file ou whisper_full avec callback
    // ... retourne la transcription dans out_buf
    return 0; // 0 = success
}
```

### Configuration du bridging header

Dans `Fluence.xcodeproj`, créer ou modifier le **Objective-C Bridging Header** (dans Build Settings → Objective-C Bridging Header) :

```
# Path: apps/ios/Fluence.xcodeproj/project.pbxproj
# Ou via Xcode : File > New > Bridging Header
```

Contenu du bridging header (`Fluence-Bridging-Header.h`) :

```objc
#ifndef FLUENCE_BRIDGING_HEADER_H
#define FLUENCE_BRIDGING_HEADER_H

#include "Core/WhisperBridge.h"

#endif
```

---

## (d) Core/WhisperEngine.swift — Encapsulation Swift

Le sketch ci-dessous présente l'API publique. Le code complet sera implémenté dans le ticket dédié.

```swift
// Core/WhisperEngine.swift (SKETCH)
import Foundation
import AVFoundation

/// Moteur Whisper.cpp on-device pour la transcription vocale et le scoring d'accent.
///
/// - Requires: modèle whisper (ggml-small.en.bin) dans le bundle
/// - Thread safety: une instance par tâche de transcription (non partageable)
/// - Mémoire : ~50-150 Mo selon le modèle chargé
final class WhisperEngine {

    // MARK: - Configuration

    enum ModelSize {
        case base    // ~72 Mo, latence ~1-2 s
        case small   // ~130 Mo, latence ~3-5 s
        case medium  // ~490 Mo, latence ~10-15 s
    }

    /// Chemin du modèle dans le bundle ou sur disque.
    let modelPath: URL

    private let context: OpaquePointer?  // whisper_context*
    private let whisperParams: whisper full_params  // ou équivalent

    // MARK: - Initialisation

    /// Charge le modèle Whisper depuis le chemin donné.
    /// - Parameter modelPath: URL du fichier .bin (ex: dans le bundle)
    /// - Throws: WhisperError.modelNotFound, .loadFailed, .architectureMismatch
    init(modelPath: URL) throws {
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw WhisperError.modelNotFound(modelPath)
        }
        // whisper_init_from_file(modelPath.path) via bridging
        // Stocker le contexte pour les appels ultérieurs
    }

    deinit {
        // whisper_free(context)
    }

    // MARK: - Transcription

    /// Transcrit un fichier audio (WAV, MP3, M4A) et retourne le texte.
    /// - Parameter audioFile: URL du fichier audio à transcrire
    /// - Returns: texte transcrit
    /// - Throws: WhisperError.audioInvalid, .transcriptionFailed, .timeout
    ///
    /// - Note: Le fichier audio doit être au format 16kHz mono WAV pour optimal.
    ///         whisper.cpp peut convertir depuis d'autres formats mais avec une latence supplémentaire.
    func transcribe(audioFile: URL) async throws -> String {
        // 1. Valider le fichier audio existe
        // 2. Appeler whisper_transcribe via le bridging C
        // 3. Parser le résultat texte
        // 4. Retourner la chaîne
        fatalError("Implémentation dans le ticket dédié")
    }

    /// Version synchrone pour les cas où async n'est pas disponible.
    func transcribeSync(audioFile: URL) throws -> String {
        fatalError("Implémentation dans le ticket dédié")
    }

    // MARK: - WER (Word Error Rate)

    /// Calcule le Word Error Rate (WER) entre une transcription et un texte de référence.
    /// - Parameters:
    ///   - transcription: texte transcrit par Whisper (ou tout texte)
    ///   - reference: texte cible attendu (ground truth)
    /// - Returns: WER en tant que double (0.0 = parfait, 1.0 = tout erroné, >1.0 possible)
    ///
    /// - Algorithme : WER = (S + D + I) / N
    ///   où S = substitutions, D = deletions, I = insertions, N = nombre de mots dans la référence.
    ///   Implémentation via l'algorithme de Levenshtein sur les tokens.
    func computeWER(transcription: String, reference: String) -> Double {
        let refWords = tokenize(reference)
        let hypWords = tokenize(transcription)
        guard !refWords.isEmpty else { return 0.0 }

        let (substitutions, deletions, insertions) = levenshteinDistance(
            refWords.count,
            {$0}, // référence[i]
            {$0}, // hypothèse[i]
        )
        // Voir implémentation complète du ticket dédié
        return Double(substitutions + deletions + insertions) / Double(refWords.count)
    }

    // MARK: - Tokenisation (simple)

    private func tokenize(_ text: String) -> [String] {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
    }

    // MARK: - Scoring d'accent

    /// Calcule un score d'accent à partir du WER.
    /// - Parameter wer: Word Error Rate (0.0 = parfait)
    /// - Returns: AccentScore avec wordErrorRate, score 0-100, et niveau
    func accentScore(from wer: Double) -> AccentScore {
        let score = max(0, min(100, Int(round((1.0 - wer) * 100))))
        let level: AccentScore.Level = score >= 90 ? .expert :
                                       score >= 70 ? .advanced :
                                       score >= 50 ? .intermediate :
                                       .beginner
        return AccentScore(wordErrorRate: wer, score: score, level: level)
    }
}

// MARK: - Erreurs

enum WhisperError: LocalizedError {
    case modelNotFound(URL)
    case loadFailed(String)
    case audioInvalid(URL)
    case transcriptionFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let url): return "Modèle Whisper non trouvé: \(url.path)"
        case .loadFailed(let reason): return "Échec du chargement du modèle: \(reason)"
        case .audioInvalid(let url): return "Fichier audio invalide: \(url.path)"
        case .transcriptionFailed(let reason): return "Transcription échouée: \(reason)"
        case .timeout: return "La transcription a dépassé le délai imparti"
        }
    }
}
```

---

## (e) Calcul du WER — Algorithme Levenshtein

Le WER est le métrique standard pour évaluer la qualité de la reconnaissance vocale. L'implémentation repose sur l'édition de chaînes (ou de séquences de tokens) via la distance de Levenshtein :

```
WER = (S + D + I) / N

où :
  S = nombre de substitutions (mot référence remplacé par un autre mot)
  D = nombre de déletions (mot référence absent dans l'hypothèse)
  I = nombre d'insertions (mot présent dans l'hypothèse mais pas dans la référence)
  N = nombre total de mots dans la référence

Exemple :
  Référence : "je voudrais un café"
  Transcription : "je voudrais du café"
  → 1 substitution ("un" → "du")
  WER = 1/4 = 0.25 = 25%
```

L'algorithme de Levenshtein sur les tokens :

```swift
// Implémentation sketch (détail dans le ticket dédié)
func levenshtein(_ s: [String], _ t: [String]) -> (sub: Int, del: Int, ins: Int) {
    // Matrice DP classique : dp[i][j] = coût minimal pour aligner s[0..i) avec t[0..j)
    // Backtrack pour compter S, D, I individuellement
    fatalError("Implémentation dans le ticket dédié")
}
```

**Complexité** : O(|s| × |t|) en temps et espace. Pour des phrases courtes (< 50 mots), c'est négligeable.

---

## (f) Stockage et affichage du score WER dans l'UI

### Stockage des résultats

Le score d'accent doit être associé à chaque fragment vocal. Modifications à `Core/Models.swift` :

```swift
// Dans Fragment (Core/Models.swift)
public struct Fragment: Codable, Identifiable, Equip, Sendable {
    // ... champs existants ...

    /// Score d'accent calculé par Whisper.cpp après transcription
    public var accentScore: AccentScore?

    /// Transcription Whisper du fragment vocal (si disponible)
    public var whisperTranscription: String?
}
```

### Affichage dans l'UI

Le score peut être affiché dans :
- **ConversationView** : sous le texte du fragment, un petit badge "Accent: 85/100 — Avancé"
- **Statistiques / Dashboard** : histogramme des scores au fil des sessions
- **Feedback post-évaluation** : message personnalisé basé sur le niveau

### Intégration dans ConversationCoordinator

Après chaque réponse vocale de l'apprenant, appeler WhisperEngine pour :
1. Transcrire l'audio enregistré
2. Calculer le WER vs. le texte attendu (si disponible)
3. Stocker le score dans le fragment

```swift
// Dans ConversationCoordinator (App/ConversationCoordinator.swift)
// Ajout dans handle(_:):
case "session.input_transcript.delta":
    // ... traitement existant ...
    if speaker == .user, let audioURL = event["audio_url"] as? String {
        // Après que l'audio a été enregistré localement :
        let engine = try WhisperEngine(modelPath: Bundle.main.url(forResource: "ggml-small.en", withExtension: "bin")!)
        let transcription = try await engine.transcribe(audioFile: localAudioURL)
        let wer = engine.computeWER(transcription: transcription, reference: expectedText ?? "")
        session?.fragments.last?.accentScore = engine.accentScore(from: wer)
        session?.fragments.last?.whisperTranscription = transcription
    }
```

---

## Fichiers à modifier

| Fichier | Action | Notes |
|---------|--------|-------|
| `Package.swift` | Optionnel — si utilisation de SPM pour whisper.cpp | Le sous-module Git est préférable |
| `Fluence.xcodeproj/project.pbxproj` | Ajouter `libwhisper.a`, configurer Header Search Paths, ajouter le bridging header | Build Settings → Other Linker Flags: `-l"whisper"` |
| `Core/Models.swift` | Ajouter `accentScore: AccentScore?` et `whisperTranscription: String?` à `Fragment` | Backwards compatible (champs optionnels) |
| `App/ConversationCoordinator.swift` | Appeler WhisperEngine après chaque réponse vocale | Dans `handle(_:)`, cas `session.input_transcript.delta` |
| `App/Assets.xcassets/` | Ajouter le dossier pour le modèle Whisper (`WhisperModel/ggml-small.en.bin`) | Copier le fichier .bin |
| `Core/WhisperEngine.swift` | **NOUVEAU** — fichier d'encapsulation Swift | Sketch fourni ci-dessus |
| `Core/AccentScore.swift` | **NOUVEAU** — struct de score d'accent | Sketch fourni ci-dessous |
| `Core/WhisperBridge.h` | **NOUVEAU** — API C pour le bridging | Sketch fourni ci-dessus |
| `Core/WhisperBridge.mm` | **NOUVEAU** — implémentation Objective-C++ | Sketch fourni ci-dessus |
| `Fluence-Bridging-Header.h` | **NOUVEAU** — bridging header Swift → C | Inclure WhisperBridge.h |

---

## Risques identifiés

### 1. Taille du modèle Whisper small (~130 Mo en int8)

- Le modèle `ggml-small.en.bin` pèse environ 130 Mo (int8). À ajouter au bundle Xcode, cela augmente la taille de l'APP de ~130 Mo.
- **Impact** : la taille de l'application téléchargeable depuis l'App Store augmente. Pour les marchés à bande passante limitée, cela peut être problématique.
- **Atténuation** : télécharger le modèle à la première utilisation (pas dans le bundle initial) ou utiliser le modèle `base` (~72 Mo) comme fallback.

### 2. Performance — latence d'inférence

- Sur un iPhone 15 (A16), la transcription d'une phrase de 5-10 secondes avec `ggml-small` prend environ 3-5 secondes.
- **Impact** : l'expérience utilisateur peut sembler lente si le score est affiché immédiatement après chaque phrase.
- **Atténuation** :
  - Lancer la transcription de manière asynchrone et afficher le score avec un délai (ne pas bloquer l'UI)
  - Utiliser `ggml-base` (~1-2 s de latence) pour un feedback plus rapide, au prix d'une précision moindre
  - Lancer la transcription en arrière-plan pendant que l'apprenant parle déjà à la réponse suivante

### 3. RAM — consommation mémoire

- Whisper small charge le modèle en RAM (~130 Mo) plus des tampons d'inférence (~50-100 Mo supplémentaires).
- Total estimé : ~200-250 Mo de RAM pour l'instance WhisperEngine.
- **Impact** : sur les iPhone avec 4 Go de RAM (iPhone SE, iPhone 12/13 base), cela peut provoquer du swapping ou des OOM (out of memory) si d'autres processus sont actifs.
- **Atténuation** :
  - Charger le modèle à la demande et le désallouer après la transcription (`whisper_free`)
  - Un seul moteur partagé par session (pas une instance par fragment)
  - Surveillance de l'utilisation mémoire via `ProcessInfo.processInfo.physicalMemory` ou `task_info`

### 4. Format audio requis

- Whisper.cpp fonctionne mieux avec des fichiers WAV 16kHz mono. Les enregistrements iOS (AVAudioRecorder) peuvent être en format différent (par exemple 44.1kHz, stéréo).
- **Impact** : conversion audio nécessaire avant transcription, ajout de latence.
- **Atténuation** : configurer AVAudioRecorder pour enregistrer en 16kHz mono, ou utiliser la conversion intégrée de whisper.cpp (`whisper_full` avec préprocessing).

### 5. Multilingue

- Les modèles Whisper commerciaux (small.en, base.en) sont anglophones uniquement.
- **Impact** : l'instructeur d'accent ne fonctionnera que pour l'anglais. Pour les autres langues (français, espagnol, allemand...), il faut utiliser les modèles multilingues (`ggml-small.bin`) qui sont plus lourds (~460 Mo) et plus lents.
- **Atténuation** : commencer avec l'anglais uniquement, étendre aux autres langues dans un ticket futur avec des modèles spécifiques.

### 6. App Store review

- L'inclusion d'un code C++ compilé (library static) doit être déclarée dans les métadonnées App Store (Third-Party Notices).
- **Impact** : ajout de boilerplate pour la conformité.
- **Atténuation** : inclure les crédits de whisper.cpp dans `ThirdPartyNotices.txt`.

---

## Références

- [whisper.cpp GitHub](https://github.com/ggerganov/whisper.cpp) — implémentation C++ de Whisper
- [Modèles GGML ( HuggingFace )](https://huggingface.co/ggerganov/whisper.cpp) — téléchargement des modèles
- [Documentation iOS de whisper.cpp](https://github.com/ggerganov/whisper.cpp/blob/master/docs/03_ios.md) — guide de compilation iOS
- [WER (Word Error Rate) — Wikipedia](https://en.wikipedia.org/wiki/Word_error_rate)
- [Algorithme de Levenshtein](https://en.wikipedia.org/wiki/Levenshtein_distance)

---

## Prochaines étapes

1. **Ticket dédié** : Créer un ticket séparé pour implémenter le code complet
2. **Implémentation** :
   - Cloner whisper.cpp comme sous-module
   - Compiler `libwhisper.a` pour iOS ARM64
   - Créer les fichiers de bridging (WhisperBridge.h, .mm, Bridging-Header.h)
   - Implémenter WhisperEngine.swift complet
   - Implémenter AccentScore.swift
   - Modifier Models.swift pour ajouter les champs WER
   - Intégrer dans ConversationCoordinator
3. **Tests** :
   - Test unitaire du calcul WER avec des paires transcrit/référence connues
   - Test d'intégration sur iPhone réel (pas simulateur — le simulateur x86_64 ne supporte pas ARM64)
   - Mesure de la latence et de la consommation RAM
4. **UI** : Ajouter l'affichage du score dans ConversationView et Dashboard
