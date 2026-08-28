# Centre Oxygène — Application mobile Android

Application Flutter qui consomme l'API de production `https://atlasapi.swiviq.com/api/v1`
(même backend que le front web Angular). Palette et typographies alignées sur le
front (`primary` bleu #3B82F6, Inter/Poppins).

## Fonctionnalités

- **Connexion** (JWT 15 jours, session restaurée au démarrage), écran animé.
- **Mot de passe oublié** — même logique que le web : email + téléphone, un
  nouveau mot de passe est envoyé par WhatsApp **et** e-mail.
- **Permissions** — `GET /permissions/my` filtre menus et actions par rôle
  (directeur / manager / professeur / secrétaire).
- **Inscription élève** — formulaire alimenté par `GET /inscription/config`
  (niveaux, matières, tarifs, remises), estimation de prix en direct, création
  via `POST /inscription/register` (prix final calculé côté serveur).
- **Liste élèves** — recherche, filtres (niveau, statut, gratuit), pagination
  infinie, fiche détaillée (contacts, matières, paiements, absences).
- **Emploi du temps** — lecture seule, filtres par version d'emploi du temps,
  niveau, professeur, jour.
- **Absences élèves** — grille de pointage par niveau/jour avec bascule
  présent/absent animée, vue mensuelle, rapport d'assiduité par niveau
  (taux, comportements, contacts parents).
- **Séances professeurs** — saisie d'une séance (durée + description, part en
  validation), consultation de ses séances (la direction voit tout).
- **Bulletins du mois** — tunnel de saisie mobile : mes groupes → élèves →
  évaluation individuelle (impression générale, points forts/attention,
  note /20, commentaire) + « tout va bien » pour le reste.
- **Profil** — modification infos personnelles et mot de passe, mode sombre.
- **Notifications ciblées** — sans Firebase : l'appareil interroge l'API avec
  le JWT du prof connecté (le ciblage par prof est garanti par l'auth).
  Poll 60 s en avant-plan + tâche WorkManager ~15 min en arrière-plan ;
  notification locale quand une séance est enregistrée ou validée.

## Lancer

```bash
flutter pub get
flutter run            # appareil/émulateur Android
flutter build apk      # APK release (signé debug pour l'instant)
```

## Structure

```
lib/
  app/        thème (palette du front) + routes (go_router, gardées par l'auth)
  core/       client Dio + JWT, session, permissions, modèles, repositories,
              widgets partagés, service de notifications
  features/   un dossier par écran (login, home, students, inscription,
              schedule, absence, records, profile)
```

## Notes backend

- Le filtre « niveau » de la liste élèves envoie le **nom** du niveau (quirk
  de l'API, pas l'id).
- La date d'absence s'appelle `asbenceDate` (typo historique de la base,
  conservée).
- `POST /absence/setAbsence` est une bascule : le même appel crée ou supprime.
- Passage à des push FCM possible plus tard : ajouter l'enregistrement du
  token appareil côté backend au point où la validation d'une séance envoie
  déjà le WhatsApp (`teacher.controller` / `activePanding`).
