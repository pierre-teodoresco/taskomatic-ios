# Taskomatic

**Des tâches sans échéance, des rappels jusqu’à ce qu’elles soient terminées.**

Taskomatic est une app iPhone native pour gérer ses tâches personnelles sans dates limites ni retards accumulés. Une tâche reste à faire tant qu’elle n’est pas cochée. Une tâche récurrente revient automatiquement après la dernière validation, à la fréquence choisie.

L’interface privilégie l’ajout rapide, une liste lisible et peu de décisions à prendre. Elle propose une palette indigo, un thème clair et sombre, et des retours haptiques discrets.

**État du projet :** version de développement 1.1.0, utilisable sur iPhone. Le stockage local et les sauvegardes manuelles sont implémentés. L’intégration CloudKit est présente, mais sa synchronisation réelle reste à valider avec une équipe Apple disposant des capacités nécessaires. Le dépôt est actuellement géré localement, sans remote ni CI distante.

[Démarrage](#démarrage-sur-simulateur) · [Installation iPhone](#installer-sur-un-iphone) · [Architecture](#architecture-et-organisation) · [Sauvegardes et iCloud](#données-sauvegardes-et-icloud) · [Tests](#tests-et-vérification) · [Publication](#préparer-une-publication) · [Licence](#licence)

## Fonctionnalités

- Ajout rapide, notes facultatives, édition et suppression avec confirmation.
- Conservation du brouillon à la fermeture du clavier et protection des modifications non enregistrées dans l’éditeur.
- Tâches simples archivées après validation, avec restauration et annulation de la dernière validation.
- Tâches récurrentes en jours, semaines ou mois, avec préréglages et fréquence personnalisée de 1 à 99 unités.
- Rappel commun à une heure locale et aux jours de la semaine choisis. La notification affiche les titres pour une ou deux tâches, puis un résumé pour les listes plus longues.
- Action « Terminer » dans les notifications qui concernent une seule tâche.
- Export et restauration de sauvegardes dans Fichiers, avec choix possible d’iCloud Drive.
- Français et anglais, préférence système, thèmes clair/sombre/système, Dynamic Type et libellés VoiceOver.

## Prérequis et stack

| Élément | Choix du projet |
| --- | --- |
| Appareil cible | iPhone, iOS 17 minimum, orientation portrait |
| Environnement | macOS avec Xcode 26 ou plus récent et un runtime de simulateur iOS installé |
| Langage | Swift 6, vérification stricte de la concurrence |
| Interface et état | SwiftUI, Observation ; UIKit pour les intégrations système |
| Persistance | SwiftData ; configuration CloudKit privée sur appareil compatible et signé |
| Rappels | UserNotifications et renouvellement opportuniste via BackgroundTasks |
| Domaine | Package Swift local `TaskomaticCore`, indépendant de SwiftUI et SwiftData |
| Tests | Swift Testing pour le domaine ; XCTest pour le stockage, la file de notifications et l’interface |
| Génération du projet | [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.44 minimum |

Il n’y a **aucune dépendance tierce à l’exécution**, aucun serveur à lancer, aucune clé d’API et aucun fichier `.env` à préparer. Le package de domaine déclare également macOS 14 minimum pour ses tests sur Mac ; cela ne constitue pas une app macOS.

La version 1.1 a été vérifiée avec Xcode 26.6, Swift 6.3.3 et XcodeGen 2.46.0, sur les simulateurs iPhone 17 / iOS 26.5 et iPhone SE / iOS 18.2.

## Démarrage sur simulateur

Depuis la racine du dépôt :

```sh
open Taskomatic.xcodeproj
```

Dans Xcode, sélectionner le schéma **Taskomatic**, choisir un simulateur iPhone, puis lancer avec **⌘R**. Aucun compte iCloud n’est nécessaire : l’app utilise un stockage local sur simulateur.

Le projet Xcode généré est versionné et peut être ouvert directement. Installer XcodeGen pour régénérer le projet ou utiliser le script de vérification :

```sh
brew install xcodegen
xcodegen generate
```

`project.yml` est la source de référence pour les cibles, schémas et réglages de compilation. Après l’ajout ou la suppression de fichiers Swift, ou une modification du projet, régénérer et versionner aussi le `.xcodeproj`. Une modification uniquement faite dans les réglages Xcode peut être perdue à la prochaine génération.

Pour compiler en ligne de commande sans signature :

```sh
xcodebuild -project Taskomatic.xcodeproj -scheme Taskomatic \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

## Installer sur un iPhone

### Configurations disponibles

| Schéma / configuration | Usage | Stockage |
| --- | --- | --- |
| `Taskomatic` / `Debug` sur simulateur | Développement et tests | Local, sans CloudKit |
| `TaskomaticLocal` / `Local` sur iPhone | Installation avec une équipe personnelle Xcode | Local ; sauvegarde manuelle via Fichiers disponible |
| `Taskomatic` / `Debug` ou `Release` sur iPhone | Développement iCloud et préparation de la distribution | SwiftData avec conteneur CloudKit privé ; provisionnement requis |

Les configurations Local et CloudKit ont le même identifiant d’app et le même emplacement de stockage sur iPhone : elles se remplacent lors de l’installation, elles ne coexistent pas comme deux apps distinctes.

### Signature personnelle

1. Ajouter son compte Apple dans Xcode et connecter l’iPhone avec le mode Développeur activé.
2. Remplacer `DEVELOPMENT_TEAM` dans `project.yml` par l’identifiant de sa propre équipe, puis exécuter `xcodegen generate`.
3. Si l’identifiant d’app n’est pas disponible pour cette équipe, choisir son propre identifiant selon les indications ci-dessous.
4. Dans Xcode, sélectionner **TaskomaticLocal**, choisir l’iPhone et lancer avec **⌘R**. Le schéma utilise la configuration **Local**.

La configuration Local définit `LOCAL_ONLY` et utilise `Config/Local.entitlements`, sans capacités CloudKit. Une signature personnelle gratuite expire périodiquement et nécessite une nouvelle compilation/installation. Si iOS demande d’approuver le profil développeur, le faire dans ses réglages système.

Pour une installation en ligne de commande, relever l’identifiant de l’appareil avec `xcrun devicectl list devices`, puis adapter cette variable :

```sh
IOS_DEVICE_ID='REMPLACER_PAR_IDENTIFIANT_APPAREIL'

xcodebuild -project Taskomatic.xcodeproj -scheme TaskomaticLocal \
  -configuration Local -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedData-local -allowProvisioningUpdates build

xcrun devicectl device install app --device "$IOS_DEVICE_ID" \
  DerivedData-local/Build/Products/Local-iphoneos/Taskomatic.app

xcrun devicectl device process launch --device "$IOS_DEVICE_ID" \
  com.pierreteodoresco.taskomatic
```

Adapter aussi l’identifiant passé à `process launch` si l’app a été renommée. Ne pas versionner certificats, profils de provisionnement, identifiants de connexion ou exports de tâches personnelles. `Config/Local.xcconfig` est ignoré par Git, mais n’est pas chargé automatiquement par le projet actuel.

### Adapter les identifiants pour un fork

Rechercher `com.pierreteodoresco.taskomatic` dans le dépôt. Les valeurs à adapter se trouvent notamment dans :

- `project.yml` : identifiants de l’app et des cibles de tests, équipe de signature.
- `Config/Taskomatic.entitlements` et `App/Core/AppRuntime.swift` : conteneur CloudKit.
- `Config/Info.plist` et `App/Core/AppDelegate.swift` : identifiant de la tâche d’arrière-plan ; les deux doivent correspondre.
- `App/Core/AppRuntime.swift` : domaine de préférences des tests isolés, si souhaité.

Régénérer ensuite le projet. Le marqueur `com.pierreteodoresco.taskomatic.backup` dans `TaskBackup.swift` identifie le **format de fichier** : le conserver pour lire les sauvegardes Taskomatic, ou prévoir une migration explicite si le format change. Ce n’est pas un identifiant de signature à remplacer mécaniquement.

## Architecture et organisation

```text
App/
  TaskomaticApp.swift        Point d’entrée et réactions au cycle de vie
  Core/                     SwiftData, préférences, notifications, fichiers et iCloud
  Design/                   Couleurs sémantiques et contrôles partagés
  Features/                 Liste, édition, récurrence, réglages et sauvegardes
  Resources/                Traductions, assets et manifeste de confidentialité
Sources/TaskomaticCore/      Modèles de domaine, récurrence, rappels et format de sauvegarde
Tests/TaskomaticCoreTests/   Tests du package de domaine
TaskomaticTests/            Tests du stockage et de la file de notifications
TaskomaticUITests/          Parcours de l’app dans le simulateur
Config/                    Info.plist et entitlements par configuration
scripts/                   Vérification et génération de l’icône
project.yml                Spécification XcodeGen
Taskomatic.xcodeproj/       Projet généré et versionné
AGENTS.md                  Conventions de travail et de vérification
LICENSE                    Licence MIT-0
docs/                      Architecture, développement et compte rendu des revues
```

Le flux principal est **vue → TaskStore → SwiftData → nouvel état → recalcul des rappels**. `AppRuntime` assemble les services et l’état observable. Le domaine manipule des valeurs `TaskItem` ; le stockage les adapte en `TaskRecord` SwiftData. `AppSettings` conserve les préférences dans UserDefaults.

Les règles métier restent dans `TaskomaticCore`, avec dates et calendriers injectables pour les tests. Les mutations utilisent un contexte SwiftData frais et ne changent que les champs concernés, afin de préserver une modification arrivée depuis l’ouverture d’un éditeur. Les erreurs d’écriture sont distinguées des erreurs de relecture après une écriture réussie.

### Règles de récurrence

Une tâche récurrente est active dès sa création. Après validation, elle attend le début du jour local situé N jours, semaines ou mois calendaires plus tard. Par exemple, une tâche hebdomadaire cochée un mardi à 16 h revient le mardi suivant à 00 h ; une récurrence mensuelle du 31 janvier revient le dernier jour de février.

L’état actif est calculé à partir de la dernière validation, sans exiger qu’iOS réveille l’app à minuit. Les cycles manqués ne s’accumulent pas. Seule la dernière validation est conservée : il n’existe pas de journal historique des réalisations. Un identifiant de cycle renouvelé à chaque validation/restauration protège contre les actions d’anciennes notifications.

Les choix de concurrence, de récurrence et de planification sont détaillés dans [l’architecture](docs/architecture.md).

## Données, sauvegardes et iCloud

### Stockage et confidentialité

Les tâches sont stockées dans le conteneur de l’app. Le projet ne contient ni analytique, ni publicité, ni SDK de suivi, ni backend propre. Le manifeste de confidentialité se trouve dans `App/Resources/PrivacyInfo.xcprivacy`.

Les préférences de langue, d’apparence et de rappel restent sur l’appareil. Les exports contiennent les titres et notes en clair dans un fichier JSON, sans chiffrement ajouté par l’app ; ils doivent être partagés comme les données personnelles qu’ils contiennent.

### Sauvegarde manuelle

Dans **Réglages → Sauvegarde**, choisir **Exporter une sauvegarde**, puis un emplacement dans Fichiers. **iCloud Drive** permet d’y conserver une copie lorsque ce fournisseur est disponible sur l’appareil. Cette fonction est également disponible dans la configuration Local, sans entitlement CloudKit propre à l’app.

Le fichier contient toutes les tâches, y compris celles archivées ou en attente, leurs notes, leurs récurrences et leur état. Le format est versionné, utilise des dates en millisecondes depuis l’époque Unix et accepte au maximum **10 Mio et 10 000 tâches**.

La restauration valide le document entier et présente un aperçu avant d’enregistrer. Elle ajoute uniquement les identifiants absents, préserve les tâches déjà présentes et ne modifie pas les réglages de rappel. Une réimportation locale du même fichier ne crée pas de doublons. Une erreur d’écriture annule les ajouts ; les tâches restaurées reçoivent de nouveaux identifiants de cycle.

L’app confirme l’export du fichier. Son envoi distant relève du fournisseur Fichiers. L’export/restauration local a été vérifié ; le transfert réel par iCloud Drive reste à valider sur des appareils connectés à iCloud.

### Synchronisation automatique CloudKit

Le code utilise une base privée dans `iCloud.com.pierreteodoresco.taskomatic`. La synchronisation est distincte d’une sauvegarde versionnée : une modification ou une suppression peut se propager aux autres appareils.

Le provisionnement CloudKit et Push a été refusé pour l’équipe personnelle disponible lors du développement. Pour activer cette intégration, il faut une équipe Apple Developer Program disposant des capacités requises, un conteneur configuré et des profils correspondants. Le statut « compte iCloud disponible » ne prouve pas que les données ont été synchronisées.

La validation doit couvrir deux appareils, les modifications hors ligne, les conflits et les changements de compte. Des imports indépendants du même fichier sur deux appareils hors ligne constituent notamment un risque de doublons encore non validé. Le détail de l’activation et du déploiement du schéma CloudKit figure dans [le guide de développement](docs/development.md#enable-and-validate-icloud).

## Notifications : comportement et limites

L’autorisation est demandée à l’activation des rappels. Aucun rappel de tâche n’est prévu lorsqu’il n’y a rien à faire. L’heure suit le calendrier et le fuseau local de l’appareil.

- Si l’ensemble des tâches actives reste stable, des notifications calendaires se répètent sans limite de durée jusqu’à modification de la liste ou des réglages.
- Si le retour futur d’une tâche récurrente change le contenu, le planificateur prépare jusqu’à **60 prochains rappels datés**. La date de couverture apparaît dans les réglages.
- La réserve est renouvelée à l’ouverture, après les mutations, les changements d’heure significatifs et les changements distants, ainsi qu’en arrière-plan quand iOS le permet.
- Le renouvellement en arrière-plan n’est pas garanti. Après épuisement de la réserve sans rouvrir l’app, les rappels datés cessent ; une continuité indépendante de l’ouverture demanderait une solution serveur.
- Le rappel de test utilise une requête distincte. Une planification réussie n’assure pas l’affichage d’une bannière : les autorisations, les options de présentation et les modes de concentration iOS interviennent aussi.

La réconciliation préserve les rappels en attente pendant un renouvellement interrompu et ne supprime pas l’historique des notifications déjà reçues. Voir `ReminderPlan.swift`, `NotificationQueue.swift` et `NotificationService.swift` pour ces mécanismes.

## Tests et vérification

### Domaine seul

```sh
swift test
```

Ces tests tournent sur Mac sans simulateur et couvrent notamment les cycles de tâches, fins de mois, années bissextiles, changements d’heure, contenus de notification et sauvegardes invalides.

### Ensemble des tests

Lister les simulateurs et choisir un identifiant disponible :

```sh
xcrun simctl list devices available
IOS_SIMULATOR_ID='REMPLACER_PAR_UUID_SIMULATEUR'
xcrun simctl boot "$IOS_SIMULATOR_ID"
open -a Simulator
./scripts/verify.sh "$IOS_SIMULATOR_ID"
```

Omettre `simctl boot` si le simulateur est déjà démarré. Le script exécute les tests du package, régénère le projet, puis lance les tests XCTest de stockage, de notifications et d’interface. Les résultats Xcode sont conservés sous `DerivedData/Logs/Test/`.

Pour cibler un test :

```sh
xcodebuild -project Taskomatic.xcodeproj -scheme Taskomatic \
  -configuration Debug -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
  -derivedDataPath DerivedData -parallel-testing-enabled NO \
  -only-testing:TaskomaticTests/TaskStoreTests \
  CODE_SIGNING_ALLOWED=NO test
```

Remplacer le filtre par `TaskomaticUITests/TaskomaticUITests/nomDuTest` pour un parcours d’interface. Les tests de stockage vérifient aussi les écritures concurrentes, l’import répété, les anciens jetons de notification et un échec d’enregistrement sur une base réellement ouverte en lecture seule.

Les arguments `--ui-testing` et `--reset-test-store` activent et réinitialisent un stockage et des préférences dédiés **uniquement dans une compilation de développement sur simulateur** (`DEBUG`). La réinitialisation nettoie également les notifications de cette app dans le simulateur. Ces arguments n’activent aucun effacement sur un iPhone physique ni dans un build Release.

Pour la version 1.1, **17 tests de domaine, 9 tests de stockage/file de notifications et 12 parcours UI ont été validés**. Les contrôles manuels comprennent l’export/restauration via Fichiers, les apparences et le texte d’accessibilité sur petit écran. Le [compte rendu des revues](docs/review.md) distingue les vérifications effectuées et les intégrations restant à tester.

## Modifier le projet

Lire [AGENTS.md](AGENTS.md) et les documents du domaine concerné avant une modification. Garder les règles métier dans le package, les adaptations système dans `App/Core` et les composants visuels réutilisables dans `App/Design`.

- Utiliser les couleurs sémantiques de `Theme` et les contrôles communs pour conserver une apparence cohérente.
- Vérifier clair/sombre, clavier, texte agrandi et VoiceOver lors des changements d’interface.
- Pour un correctif métier, reproduire d’abord le comportement fautif avec un test, puis corriger et relancer les vérifications concernées.
- Faire relire les changements de manière indépendante, traiter les remarques et obtenir une seconde passe avant de committer.
- Garder les builds, captures de simulateur, résultats `.xcresult` et données de test locales hors du dépôt.

Le formateur est celui de la toolchain Swift, sans dépendance à SwiftFormat :

```sh
swift format format --in-place --recursive App Sources Tests TaskomaticTests TaskomaticUITests
swift format lint --recursive App Sources Tests TaskomaticTests TaskomaticUITests
git diff --check
```

### Ajouter une langue

1. Créer `App/Resources/<code>.lproj/Localizable.strings` avec toutes les clés et les mêmes paramètres de format que la version anglaise.
2. Ajouter la langue à `AppLanguage` dans `AppSettings.swift` et à `AppStrings.code` dans `AppStrings.swift`.
3. Ajouter son choix au sélecteur de `SettingsView` et son code à `knownRegions` dans `project.yml`.
4. Régénérer le projet et vérifier les textes, pluriels, dates, récurrences et notifications dans cette langue.

La langue de développement est l’anglais. Le contenu saisi par l’utilisateur n’est jamais traduit. Les ressources sont des fichiers `.strings` ; il n’y a pas de catalogue `.xcstrings` à générer.

### Icône et assets

L’icône est une création vectorielle du projet, rendue en PNG par ce script macOS :

```sh
swift scripts/generate-icon.swift
```

Le script réécrit l’icône et son `Contents.json` dans le catalogue d’assets ; versionner le résultat si le dessin change. Les références visuelles et décisions de présentation sont décrites dans [l’architecture](docs/architecture.md#visual-direction).

## Dépannage

| Symptôme | Vérification |
| --- | --- |
| `xcodebuild` pointe vers les Command Line Tools | Vérifier `xcode-select -p`, puis choisir l’installation Xcode dans ses réglages Locations / Command Line Tools |
| Un nouveau fichier n’apparaît pas dans Xcode | Relancer `xcodegen generate` depuis la racine |
| Signature refusée pour iCloud ou Push | Pour une équipe personnelle, choisir **TaskomaticLocal / Local** et sa propre équipe |
| App installée mais ouverture refusée sur iPhone | Vérifier le mode Développeur et la confiance du profil dans les réglages iOS |
| Profil personnel expiré | Reconstruire et réinstaller avec Xcode |
| Rappel de test invisible | Vérifier autorisation, bannières, Centre de notifications et Concentration ; consulter aussi le Centre de notifications après le test |
| Un fichier de sauvegarde ne se restaure pas | Vérifier qu’il est disponible dans Fichiers, au format Taskomatic et dans les limites indiquées ; aucune restauration partielle n’est appliquée |
| L’app affiche une erreur de stockage | Réessayer et inspecter la console Xcode ; préserver la base existante avant toute investigation destructive |

## Préparer une publication

Le dépôt ne contient pas de pipeline de publication automatique. Avant TestFlight ou l’App Store :

1. Configurer ses identifiants, sa signature de distribution et, pour le schéma Taskomatic actuel, les capacités CloudKit/Push.
2. Valider la synchronisation sur appareils puis déployer le schéma CloudKit de développement en production.
3. Tester les évolutions de schéma SwiftData sur des bases existantes et conserver la compatibilité des sauvegardes versionnées.
4. Mettre à jour `MARKETING_VERSION` et `CURRENT_PROJECT_VERSION` dans `project.yml`, puis régénérer le projet.
5. Vérifier le manifeste de confidentialité, les déclarations App Store, les captures, les traductions et le comportement de la version distribuée via TestFlight.

Archiver avec le schéma **Taskomatic**, configuration **Release**. La configuration **Local** sert au développement personnel. Le [guide de développement](docs/development.md) décrit les opérations CloudKit et les limites de validation actuelles.

## Documentation complémentaire

- [Architecture](docs/architecture.md) : invariants, concurrence, stockage, sauvegardes et stratégie de rappels.
- [Développement](docs/development.md) : simulateur, signature, appareil physique et intégration iCloud.
- [Revues et validation](docs/review.md) : corrections, tests effectués et limites connues.
- [Conventions du dépôt](AGENTS.md) : responsabilités des composants et processus de vérification.

## Licence

Le code et la documentation du projet sont distribués sous [MIT No Attribution — MIT-0](LICENSE), copyright © 2026 Pierre Teodoresco.

Cette licence permet l’utilisation, la modification, la redistribution, la sous-licence et la vente, y compris dans un produit propriétaire, sans obligation de publier ses modifications ni de conserver une attribution. Le logiciel est fourni sans garantie. [Référence SPDX](https://spdx.org/licenses/MIT-0.html).
