# 📖 INFORMATIONS & MÉMOIRE CENTRALE — PROJET MUSLY
> **Document de référence exhaustif** regroupant l'intégralité de la mémoire du projet, la vision, nos choix architecturaux, nos refus fermes, l'historique technique, les secrets d'infrastructure et les directives produit.
> **Date de consolidation** : 02 Novembre 2026  
> **Dépôt local** : `C:\Users\coren\Documents\music\musly_repo`  
> **Version active** : `v2.10.14+29` (Production)

---

## 1. 🎯 La Vision Fondatrice & Le Concept

**Musly** est né d'un besoin précis de l'utilisateur : concevoir une application de streaming musical haute fidélité connectée à son serveur privé, mais offrant le confort, la fluidité visuelle et l'expérience utilisateur des leaders du marché (**Apple Music** et **Spotify**).

### Le Principe de l'Illusion du « Catalogue Infini »
L'application est connectée au serveur personnel de l'utilisateur (`https://music.corentinjanin.fr`).
- **Aucune distinction visible** : Pour l'utilisateur, il ne doit y avoir aucune différence perceptible entre les morceaux stockés localement sur le serveur et le reste de la musique mondiale.
- **Accès instantané 90M+** : Lorsqu'un utilisateur recherche ou lance un titre qui n'est pas encore téléchargé sur son serveur, le serveur (via son résolveur FastAPI / CJ Resolver) se connecte au catalogue Deezer (90 millions de titres) et commence à streamer le morceau en direct en **Opus Studio Master 48 kHz** via des requêtes partielles HTTP 206 (Range requests).
- **Mise en cache transparente** : Pendant que les premières secondes sont jouées instantanément sur l'application, le serveur télécharge et met en cache la suite du morceau pour une écoute sans coupure ni latence, même en cas de saut direct dans la piste (ex: à 1 min 20).

---

## 2. 🚫 Nos Refus Fermes & Les Idées Rejetées (Ce qui est strictement INTERDIT)

Au fil des itérations, des règles strictes ont été établies sur ce que l'application **ne doit JAMAIS faire** :

1. ❌ **AUCUN ÉMOJI DANS L'INTERFACE UTILISATEUR** :  
   - *Règle absolue* : L'utilisateur a formellement banni les émojis dans les boutons, menus, titres, onglets ou badges.
   - *Alternative obligatoire* : Uniquement des icônes vectorielles nettes et professionnelles (SVG propres, Material Icons ou Cupertino Icons sobres).
2. ❌ **PAS DE MAQUETTES ABSTRAITES HORS CODE** :  
   - L'utilisateur a explicitement demandé d'oublier les maquettes statiques/abstraites ("oublie complètement la maquette"). Tout développement doit être testé et validé directement dans le code réel, sur l'émulateur ou sur smartphone physique.
3. ❌ **PAS DE CARTES D'ALBUMS AU LIEU DES TITRES DANS LA BIBLIOTHÈQUE** :  
   - *Refus catégorique* : Ne jamais afficher une grille de gros carrés d'albums obligeant l'utilisateur à cliquer sur un album pour ensuite voir les chansons.
   - *Règle obligatoire* : Affichage direct sous forme de pistes (**TrackListTile** avec petite pochette carrée + Titre + Artiste + Durée).
4. ❌ **PAS DE BADGES TECHNIQUES OU STICKERS PARASITES SUR LE PLAYER** :  
   - Pas de fioritures criardes, de vignettes techniques superflues ou de labels encombrants sur l'écran Now Playing. L'espace doit respirer, façon Apple Music.
5. ❌ **PAS DE CHARGE LOURDE CÔTÉ SERVEUR (Traitement DJ / IA Audio)** :  
   - Le serveur n'a pas la puissance processeur pour calculer des fondus ou de l'analyse audio temps réel pour chaque client. Tous les calculs de crossfade et d'effets doivent être exécutés côté client dans l'application Flutter.
6. ❌ **PAS DE COUPURE NETTE AUDIO ENTRE LES MORCEAUX** :  
   - Interdiction d'avoir une coupure abrupte à la fin d'un morceau. La transition doit être progressive et intelligente (crossfade dynamique avec pré-chargement du morceau suivant).
7. ❌ **AUCUNE TRONCATURE DANS L'IMPORT DE PLAYLISTS (Règle Lossless)** :  
   - Interdiction de brider l'import de playlists externes (comme l'ancien bug qui limitait à 35 titres). Une playlist de 13h49 et de 300 titres doit importer l'intégralité des 300 titres avec leur durée exacte.
8. ❌ **PAS DE « PLUS TARD » QUI BLOQUE LES MISES À JOUR FUTURES** :  
   - Quand l'utilisateur clique sur "Plus tard" lors d'une alerte de mise à jour, cela ne doit reporter QUE la version actuelle. Dès qu'une nouvelle version sort, la pop-up doit réapparaître au démarrage.
9. ❌ **NE PAS FORCER LE VPN LOCALDEVVPN EN CONTINU** :  
   - L'utilisateur utilise **ProtonVPN** au quotidien. `LocalDevVPN` (pour SideStore) ne doit être allumé que ponctuellement pendant les rafraîchissements ou installations (30 secondes).
10. ❌ **PAS DE BAVARDAGE INUTILE DANS LES RÉPONSES** :  
    - L'utilisateur exige des explications directes, synthétiques, numérotées, orientées action ("point par point, ne blablate pas pendant trois ans").

---

## 3. 🎨 Nos Choix de Design & Standards UI/UX (Apple Human Interface Guidelines)

L'interface de Musly a été entièrement harmonisée selon les principes du skill `apple-design-skill` :

* **Thème Pure OLED Noir Absolu (`#000000`)** :
  - Fond d'écran : `Color(0xFF000000)`.
  - Pas de gris délavé (les anciens `#1C1C1E` ou `#282828` ont été éradiqués).
  - Surfaces secondaires et cartes : `#09090B` et `#0C0C0E`.
  - Bordures capillaires fines et discrètes : `Color(0x14FFFFFF)` (8%) ou `0x1AFFFFFF` (10%).
  - Neutralisation du système Monet / Dynamic Color d'Android pour empêcher que le système n'injecte des teintes marron/grises sur le noir pur OLED.
* **Barre de Navigation & Mini Player Translucides** :
  - Utilisation d'un `BackdropFilter` avec flou gaussien et fond en verre fumé (`Color(0xB3000000)`).
* **Now Playing Screen (Écran de Lecture Plein Écran)** :
  - Pochette de l'album centrée avec ombrage doux.
  - Arrière-plan diffus dynamique reprenant les teintes de la pochette avec fondu progressif dans le noir OLED absolu (`BlurredGradientBackground`).
  - Paroles synchronisées en direct (Synced Lyrics) affichées en mode karaoké fluide avec surlignage de la ligne en cours de lecture.
* **Typographie & Lisibilité** :
  - Textes principaux en blanc pur (`#FFFFFF`), textes secondaires en gris doux Apple (`#8E8E93`), métadonnées tertiaires (`#636366`).

---

## 4. ⚙️ Architecture Technique & Écosystème

### Backend & Infrastructure
* **Serveur Principal** : `https://music.corentinjanin.fr`
* **Protocole serveur** : OpenSubsonic standard + extensions API personnalisées.
* **Streaming audio** : Format Opus Studio Master 48 kHz (Range 206, chunk streaming).
* **API de Déploiement Automatique** :
  - Endpoint : `https://music.corentinjanin.fr/api/musly/deploy`
  - Méthode : `POST`
  - Header secret : `X-Musly-Auth: VOTRE_SECRET_DEPLOY`
  - Fichiers mis à jour côté serveur : `version.json`, `index.html` (page de téléchargement), fichiers `.apk` et `.ipa`.
* **Portail public des mises à jour** : `https://music.corentinjanin.fr/updates/`
* **Manifeste des versions** : `https://music.corentinjanin.fr/updates/version.json`

### Application Client Flutter (`lib/`)
* **`lib/main.dart`** : Point d'entrée de l'application, configuration audio et injection des services.
* **`lib/theme/app_theme.dart`** : Définition des constantes OLED et palette de couleurs.
* **`lib/services/theme_service.dart`** : Gestion du mode OLED (`app_pure_oled`) sauvegardé dans `SharedPreferences`.
* **`lib/services/deezer_service.dart`** : Connexion au catalogue public Deezer, recherche globale de playlists et pagination automatique par paquets de 100 morceaux.
* **`lib/services/link_resolver_service.dart`** : Décodeur universel de liens Spotify, Apple Music et Deezer avec extraction directe du titre, de l'artiste (`subtitle`), de la jaquette et de la durée exacte sans troncature.
* **`lib/services/update_service.dart`** : Système de détection de mise à jour avec vérification sémantique de version et snooze sélectif par numéro de version (`snoozed_update_version`).
* **`lib/providers/library_provider.dart`** : Gestion de la bibliothèque, recherche multi-sources en parallèle (local + serveur + Deezer), création et fusion de playlists (`savePlaylistToLibrary`, `addSongsToPlaylist`).
* **`lib/screens/playlist/playlist_screen.dart`** : Affichage d'une liste de lecture avec décompte exact des titres et calcul dynamique de la durée d'écoute globale (`formattedDuration`, ex: `13 h 49 min`).

---

## 5. 📱 Stratégie iOS, SideStore & Réseau

Pour permettre à l'utilisateur d'avoir Musly sur son iPhone sans payer d'abonnement Apple Développeur (99$/an) et **sans dépendre d'un PC au quotidien** :

* **Choix de SideStore** :
  - Contrairement à AltStore classique qui exige que le PC reste allumé sur le même réseau Wi-Fi, SideStore s'auto-renouvelle directement depuis l'iPhone en utilisant un VPN local de bouclage (**`LocalDevVPN`** ou WireGuard).
* **Gestion du double VPN (ProtonVPN & LocalDevVPN)** :
  - iOS n'autorise qu'un seul profil VPN connecté à la fois.
  - **Au quotidien (99% du temps)** : L'utilisateur utilise **ProtonVPN**. Musly fonctionne parfaitement avec ProtonVPN.
  - **Lors des mises à jour ou du rafraîchissement hebdomadaire (1% du temps)** : L'utilisateur coupe ProtonVPN, active `LocalDevVPN`, ouvre SideStore pour rafraîchir ou mettre à jour, puis réactive ProtonVPN.
* **Résolution de l'Erreur Code -80045 (*Operation could not be completed at this time*)** :
  - Cause : Bug de communication avec les serveurs d'authentification Anisette d'Apple.
  - Solution validée : Dans SideStore > *Settings* > *User customization* > *Anisette Servers* > sélectionner **`SideStore (New)`** (serveur 5) et désactiver l'option **`Enable Auto Rotation`**.

---

## 6. 📜 Historique & Résumé des Versions Clés

| Version | Build | Évolutions Majeures |
| :--- | :---: | :--- |
| **v2.10.14** | `29` | **Suppression de la limite de 35 titres** lors de l'import Spotify/Deezer. Conservation 100% sans perte des morceaux et durées. Pagination multi-pages Deezer (+1000 titres). Durée totale dynamique affichée. Déploiement de `Musly.ipa` (14,3 Mo). |
| **v2.10.13** | `28` | Ajout de la fonctionnalité **« Ajouter à mes listes de lecture »** (modal permettant de sauvegarder une playlist importée comme nouvelle playlist ou de fusionner dans une existante). |
| **v2.10.12** | `27` | Recherche universelle de playlists dans le catalogue public Deezer 90M avec chargement instantané des jaquettes et durée cumulée. |
| **v2.10.10** | `25` | Correction de la mise en veille des mises à jour (le bouton "Plus tard" ne bloque plus les versions ultérieures). |
| **v2.10.3** | `18` | Intégration du résolveur de liens universels et streaming OpenSubsonic. |
| **v2.9.x** | `15` | Refonte graphique complète vers le thème Pure OLED Noir `#000000` et design Apple HIG. |

---

## 7. 💡 Guide Opérationnel pour la Prochaine IA

1. **Priorité absolue à l'expérience utilisateur** : Pas de régression sur le noir OLED (`#000000`), pas d'émojis, pas de cartes géantes inutiles dans la bibliothèque, garder l'affichage par titres directs.
2. **Cycle de livraison d'une nouvelle version** :
   ```bash
   # 1. Incrémenter la version dans pubspec.yaml (ex: 2.10.15+30)
   # 2. Compiler l'APK Android release
   flutter build apk --release
   # 3. Déployer sur le serveur de production
   curl -X POST "https://music.corentinjanin.fr/api/musly/deploy" \
     -H "X-Musly-Auth: VOTRE_SECRET_DEPLOY" \
     -F "file=@build/app/outputs/flutter-apk/app-release.apk" \
     -F "version=2.10.15" \
     -F "build_number=30" \
     -F "release_notes=[\"Description des changements\"]"
   ```
3. **Style de communication** : Répondre en français, aller droit au but, donner des instructions claires, numérotées et immédiatement applicables.
