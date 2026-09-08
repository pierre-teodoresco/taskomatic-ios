# Taskomatic

Une app iPhone de tâches personnelles, en SwiftUI. Écris une tâche, puis garde-la dans ta liste et tes rappels jusqu’à ce qu’elle soit terminée. Les tâches récurrentes reviennent après leur dernière validation, sans échéance ni accumulation de retards.

- Ajout rapide, notes facultatives, édition, suppression et annulation de validation.
- Récurrence en jours, semaines et mois calendaires ; réactivation au début du jour.
- Rappel commun à une heure et aux jours choisis, avec les titres pour une ou deux tâches.
- Action « Terminer » dans les notifications à une seule tâche.
- Archive des tâches simples et liste des récurrentes en attente.
- Français, anglais, thème clair/sombre/système, Dynamic Type et VoiceOver.
- SwiftData local et configuration CloudKit privée.

## Ouvrir et tester

Ouvrir `Taskomatic.xcodeproj` dans Xcode. Le projet généré est versionné ; `project.yml` permet de le régénérer avec XcodeGen.

```sh
swift test
./scripts/verify.sh <identifiant-du-simulateur>
```

Le schéma **Taskomatic** comprend les tests du stockage et de l’interface. Les tests simulateur utilisent un stockage local isolé ; ils ne touchent pas iCloud.

## iPhone et iCloud

**TaskomaticLocal**, configuration **Local**, permet l’installation avec une équipe personnelle Xcode. Cette configuration conserve les tâches sur l’iPhone. La signature gratuite doit être renouvelée périodiquement.

**Taskomatic**, configurations **Debug/Release**, contient l’intégration iCloud. Elle exige une équipe Apple Developer payante et le conteneur CloudKit configuré. Le compte actuellement disponible a été refusé par Apple pour les capacités iCloud et Push Notifications ; la synchronisation réelle reste donc à valider après activation du compte. Les deux configurations utilisent le même identifiant d’app et le même emplacement de stockage sur l’iPhone.

## Portée des rappels locaux

Lorsque toutes les tâches à rappeler sont déjà actives, les notifications se répètent sans limite de durée jusqu’à modification de la liste.

Si une tâche récurrente doit revenir plus tard, l’app prépare jusqu’à **60 prochains rappels**, en calculant le bon contenu pour chaque date. La réserve est renouvelée à l’ouverture, après une modification, à réception d’une synchronisation et, lorsque iOS le permet, en arrière-plan. L’échéance de cette réserve apparaît dans les réglages. Le renouvellement après plusieurs mois sans rouvrir l’app ne peut pas être garanti par iOS ; assurer cette continuité demande un service serveur. Cette limite de la version locale reste un point produit à confirmer.

Voir [le guide de développement](docs/development.md), [l’architecture](docs/architecture.md) et [la revue indépendante](docs/review.md).
