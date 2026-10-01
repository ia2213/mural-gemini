# Release — Fluence iOS (no.william.mural)

## Status

| Étape | Statut | Notes |
|-------|--------|-------|
| Bundle ID | `no.william.mural` | AltStore actuellement ; migration App Store à faire |
| Apple Developer Program | ❌ Non affilié | $99/an requis pour TestFlight + App Store |
| Screenshots | 📁 `release/screenshots/` | Structure prête, captures à générer |
| Privacy Manifest | ✅ `App/PrivacyInfo.xcprivacy` | Mis à jour pour audio on-device + personnalisation |
| Signing | Développeur personnel | Profil AltStore actuel ; Apple Developer nécessaire pour distribution officielle |
| IPA CI | ✅ `Mural-Gemini-IPA` | Build automatique via GitHub Actions |

## Prérequis Apple Developer Program

1. Créer un compte [Apple Developer](https://developer.apple.com/) ($99/an).
2. Dans [App Store Connect](https://appstoreconnect.apple.com/), créer l'application avec le bundle ID `no.william.mural`.
3. Générer un profil de distribution (App Store ou TestFlight) dans Xcode → Preferences → Accounts.
4. Ajouter les screenshots pour chaque langue : `release/screenshots/en-US/` (6 images, 1242×2688px) et `fr-FR/`.

## Screenshots requis (6 par langue)

| # | Écran | Taille |
|---|-------|--------|
| 1 | Accueil / Onboarding | 1242×2688 |
| 2 | Conversation libre | 1242×2688 |
| 3 | Professeur & Assimil | 1242×2688 |
| 4 | Mode Enfant (KidsVocalHub) | 1242×2688 |
| 5 | Réglages / Clés API | 1242×2688 |
| 6 | Vocabulaire / FSRS | 1242×2688 |

## Soumission App Store Review

- Catégorie : Éducation
- Age: 4+ (Mode Enfant présent → Guideline 1.3 stricte)
- Privacy: Policy URL requise (hébergement externe)
- Contacts: Email de support + contact développeur
- Notes de version :
  - v3.0 : Migration Keychain, Parental Gate, AIConsent, FSRS, import Anki paginé
  - v2.2.0 : Moteur conversationnel, import documents multi-formats

## TestFlight

Après affiliation Apple Developer :
```sh
# Dans Xcode : Product → Archive → Distribute App → TestFlight
#Ou via Transporter / altool CLI avec les certificats adéquats.
```

## Limitations actuelles (gratuit)

- Le développeur n'est pas affilié au programme Apple Developer.
- Le build actuel est signé pour AltStore (développeur personnel, renouvellement 7j).
- TestFlight et App Store ne sont pas disponibles tant que l'affiliation n'est pas effectuée.
- Le travail de préparation (Privacy Manifest, structure de screenshots, note de version) est effectué ; l'activation finale nécessite l'achat de l'adhésion.

## Fluence Dossier Complet

Voir `~/Fluence_Dossier_Complet.md` pour l'audit complet de la refonte v3.0.
