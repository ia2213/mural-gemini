# HANDOFF & MÉMOIRE PROJET : MURAL (Mural-Gemini)

> **Document de reprise automatique / Handoff**  
> Ce document récapitule l'état complet du projet, l'architecture, les secrets/configs, et les procédures pour reprendre le travail sans repartir de zéro.

---

## 1. Vue d'ensemble & Dépôt
- **Nom du projet** : Mural (Mural-Gemini)
- **Dépôt Git** : `https://github.com/ia2213/mural-gemini.git`
- **Branche principale** : `main`
- **Dossier local** : `C:/Users/Marc Hopf/mural_project/repo`
- **Livraison finale IPA** : Bureau client `C:/Users/Marc Hopf/Desktop/Mural-Gemini.ipa` + Bot Telegram `@CerveauPriveeBot` (chat_id: `856614939`)

---

## 2. Architecture & Fonctionnalités Clés

### A. Moteur IA Multi-Fournisseurs (Auto-Failover)
- **3 Fournisseurs configurés** dans `APIClient.swift` & `Models.swift` :
  1. **Groq API** (Par défaut : `qwen/qwen3.8-27b` ou `llama-3.1-8b-instant`)
  2. **Google Gemini API** (`gemini-1.5-flash` / `openai/chat/completions` endpoint)
  3. **Agent Personal Hermes VPS** (`http://<IP-VPS>:20128/v1/chat/completions`)
- **Auto-Failover** : Basculement automatique transparent sur erreurs HTTP 400, 403, 404, 429 (rate limit) et 500+.

### B. Audio & Vocal
- **STT (Reconnaissance)** : Groq Whisper Turbo (`whisper-large-v3-turbo`)
- **TTS (Synthèse)** : Native iOS `AVSpeechSynthesizer` (voix haute qualité `.premium` / `.enhanced`, préécoute, vitesse 0.8x-1.2x).
- **VAD & micro** : Pause automatique du micro pendant le TTS pour éviter les boucles d'auto-réponse.

### C. Interface & Compatibilité
- **iPad Support** : `NavigationSplitView`, layout responsive sidebar/detail, `TARGETED_DEVICE_FAMILY = "1,2"`, orientations complètes.
- **WidgetKit Widgets** : Extension `MuralWidgetExtension` (tailles Small, Medium, Large) connectée via `UserDefaults` partagés (`group.no.william.mural`).
- **Telegram Mini App & Bot** :
  - Mini App : `https://ia2213.github.io/mural-gemini/` (`index.html`)
  - Bot Telegram : `@MuralTeacherBot` avec commandes `/correction`, `/provider`, `/key`.

### D. Niveaux de correction
- Réglable dans l'UI (Réglages / Preferences) : **Fort**, **Moyen**, **Faible** (`correctionLevel` dans `TeachingPolicy.swift`).

### E. Mode Étude Assimil OCR & Documents Google Drive
- **OCR Assimil (Livre de méthode)** :
  - Capture caméra / Galerie photo via `CameraPickerView` et `PhotosPicker`.
  - Double moteur OCR : Apple Vision (`VNRecognizeTextRequest`) hors-ligne + analyse multimodale Gemini 2.0 Flash.
  - Structuration de leçon : dialogue bilingue numéroté, remarques de grammaire, exercices d'entraînement.
  - Session Professeur interactive : lecture audio des répliques, répétition et analyse de la prononciation, explications grammaticales, correction en temps réel des exercices.
- **Dossiers de cours par niveaux & Tous formats (Google Drive / iCloud / Local)** :
  - **Sélecteur de dossier complet :** Scannage récursif de sous-dossiers et détection automatique des niveaux (A1, A2, B1, B2, C1).
  - **Support universel de fichiers :** PDF, Word (.docx), PowerPoint (.pptx), Excel/CSV, images (avec OCR auto), ePub, HTML, RTF, Markdown, texte brut.
  - **Visualisation et lecture en ligne :** Possibilité de lire le document directement dans l'app pendant que l'IA y accède en continu.
  - **Mode « Cours en Questions » :** Pédagogie interactive où le professeur IA pose des questions progressives (vocabulaire, grammaire B2, cas, syntaxe), analyse les réponses orales/écrites, explique les erreurs en français et donne les formulations modèles en allemand.

### F. Algorithme FSRS Auto-Adaptatif & Révision 100% Vocale
- **Moteur FSRS (Free Spaced Repetition Scheduler)** :
  - Calcul continu de la stabilité ($S$), difficulté ($D$) et rétention ($R$) selon la courbe d'oubli mathématique.
  - Auto-ajustement dynamique des poids FSRS au fur et à mesure des révisions de l'utilisateur pour calibrer l'intervalle à sa mémoire personnelle.
- **Expérience 100% Vocale (Sans Écrit)** :
  - L'IA injecte naturellement les notions et expressions dues au fil de la discussion orale libre ou lors de la session dédiée FSRS.
  - L'évaluation des réponses vocales met à jour instantanément la base FSRS (Again, Hard, Good, Easy) et déclenche des corrections/explications modèles orales en français et allemand.
- **Notifications Journalières Intelligentes & Humaines** :
  - Programmation locale via `UNUserNotificationCenter` (1 ou 2 notifications par jour, heures configurables).
  - Messages dynamiques, motivants et presque humains qui interpellent l'utilisateur en citant un terme FSRS à réviser (*« Hé oh ! C'est l'heure de réviser 😉 Tu te rappelles comment on dit ... en allemand ? Viens me dire ça en vocal ! »*).
  - Le tap sur la notification ouvre directement l'application en mode vocal actif.

---

## 3. Configuration du Build & CI/CD (GitHub Actions)

- **Workflow CI** : `.github/workflows/build-ios.yml`
- **Mécanisme de packaging IPA** :
  - `xcodebuild` génère le binaire Release non signé pour iPhoneOS.
  - Structure de l'IPA :
    ```
    Payload/
    └── Mural.app/
        └── PlugIns/
            └── MuralWidgetExtension.appex
    ```
  - Widget Kit : Inclus dans `PlugIns/` pour apparaître dans le sélecteur de widgets iOS.

---

## 4. Fichiers Clés du Codebase

| Fichier / Repertoire | Rôle |
|---|---|
| `apps/ios/Mural.xcodeproj/project.pbxproj` | Configuration Xcode (Targets `Mural`, `MuralWidgetExtension`, `MuralUITests`). |
| `apps/ios/App/APIClient.swift` | Moteur tri-fournisseurs (Groq, Gemini, Hermes VPS) + Auto-Failover. |
| `apps/ios/App/Models.swift` | Modèles de données (`providerID`, `correctionLevel`, etc.). |
| `apps/ios/Core/TeachingPolicy.swift` | Prompts pédagogiques ajustables selon `correctionLevel`. |
| `apps/ios/App/RootView.swift` | Layout principal iPad (`NavigationSplitView`) et iPhone. |
| `apps/ios/App/Storage.swift` | Stockage et synchro `UserDefaults` partagés pour Widgets. |
| `apps/ios/Widget/MuralWidget.swift` | Code Swift du WidgetKit (Small/Medium/Large). |
| `index.html` | Code source Telegram Mini App (GitHub Pages). |
| `mural_telegram_runner.py` | Bot Python Telegram `@MuralTeacherBot`. |
| `.github/workflows/build-ios.yml` | Pipeline de build automatique et génération d'IPA. |

---

## 5. Guide de Reprise Rapide (Pour l'Agent ou le Développeur)

Si une nouvelle session démarre ou si tu veux relancer/modifier le projet :

1. **Lire ce fichier** : `HANDOFF.md` à la racine du dépôt.
2. **Se placer dans le répertoire** :
   ```bash
   cd "C:/Users/Marc Hopf/mural_project/repo"
   ```
3. **Pousser des modifications & déclencher le build IPA** :
   ```bash
   git add .
   git commit -m "Description de la modif"
   git push origin main
   ```
4. **Récupérer l'IPA compilé** :
   - Automatiquement téléchargé par les scripts Python sur `C:/Users/Marc Hopf/Desktop/Mural-Gemini.ipa` et envoyé sur Telegram au bot.

---
*Dernière mise à jour : 20 Septembre 2026*
