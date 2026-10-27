// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Musly';

  @override
  String get emulatorDetected => 'Émulateur détecté';

  @override
  String get emulatorNotAllowed =>
      'Cette application ne peut pas fonctionner sur un émulateur.\nVeuillez utiliser un appareil physique.';

  @override
  String get goodMorning => 'Bonjour';

  @override
  String get goodAfternoon => 'Bonjour';

  @override
  String get goodEvening => 'Bonsoir';

  @override
  String get forYou => 'Pour vous';

  @override
  String get quickPicks => 'Sélection rapide';

  @override
  String get discoverMix => 'Mix Découverte';

  @override
  String get recentlyPlayed => 'Lus récemment';

  @override
  String get yourPlaylists => 'Vos playlists';

  @override
  String get favoritePlaylists => 'Favorite Lirelists';

  @override
  String get sectionAlbums => 'Albums';

  @override
  String get sectionEPs => 'EPs';

  @override
  String get sectionSingles => 'Singles';

  @override
  String get madeForYou => 'Fait pour vous';

  @override
  String get topRated => 'Les mieux notés';

  @override
  String get noContentAvailable => 'Aucun contenu disponible';

  @override
  String get tryRefreshing =>
      'Actualisez ou vérifiez votre connexion au serveur';

  @override
  String get refresh => 'Actualiser';

  @override
  String get errorLoadingSongs => 'Erreur lors du chargement des titres';

  @override
  String get noSongsInGenre => 'Pas de titre de ce genre';

  @override
  String get errorLoadingAlbums => 'Erreur lors du chargement des albums';

  @override
  String get noTopRatedAlbums => 'Aucun album le mieux noté';

  @override
  String get login => 'Connexion';

  @override
  String get serverUrl => 'Adresse du serveur';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get password => 'Mot de passe';

  @override
  String get selectCertificate => 'Sélectionnez le certificat TLS/SSL';

  @override
  String failedToSelectCertificate(String error) {
    return 'Impossible de sélectionner le certificat : $error';
  }

  @override
  String get serverUrlMustStartWith =>
      'L\'adresse du serveur doit commencer par http:// ou https://';

  @override
  String get failedToConnect => 'Échec de la connexion';

  @override
  String get library => 'Bibliothèque';

  @override
  String get search => 'Rechercher';

  @override
  String get settings => 'Paramètres';

  @override
  String get albums => 'Albums';

  @override
  String get artists => 'Artistes';

  @override
  String get songs => 'Titres';

  @override
  String get playlists => 'Playlists';

  @override
  String get genres => 'Genres';

  @override
  String get years => 'Années';

  @override
  String get favorites => 'Favoris';

  @override
  String get nowPlaying => 'En cours de lecture';

  @override
  String get queue => 'File d\'attente';

  @override
  String get lyrics => 'Paroles';

  @override
  String get play => 'Lecture';

  @override
  String get pause => 'Pause';

  @override
  String get next => 'Suivant';

  @override
  String get previous => 'Précédent';

  @override
  String get shuffle => 'Aléatoire';

  @override
  String get repeat => 'Lecture en boucle';

  @override
  String get repeatOne => 'Boucler sur un titre';

  @override
  String get repeatOff => 'Lecture en boucle désactivée';

  @override
  String get addToPlaylist => 'Ajouter à la playlist';

  @override
  String get removeFromPlaylist => 'Retirer de la playlist';

  @override
  String get addToFavorites => 'Ajouter aux favoris';

  @override
  String get removeFromFavorites => 'Retirer des favoris';

  @override
  String get download => 'Télécharger';

  @override
  String get delete => 'Supprimer';

  @override
  String get cancel => 'Annuler';

  @override
  String get ok => 'Ok';

  @override
  String get save => 'Enregistrer';

  @override
  String get close => 'Fermer';

  @override
  String get general => 'Général';

  @override
  String get appearance => 'Apparence';

  @override
  String get playback => 'Lecture';

  @override
  String get storage => 'Stockage';

  @override
  String get about => 'À propos';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get language => 'Langue';

  @override
  String get version => 'Version';

  @override
  String get madeBy => 'Développé par dddevid';

  @override
  String get githubRepository => 'Dépôt GitHub';

  @override
  String get reportIssue => 'Signaler un problème';

  @override
  String get joinDiscord => 'Rejoindre la communauté Discord';

  @override
  String get unknownArtist => 'Artiste inconnu';

  @override
  String get unknownAlbum => 'Album inconnu';

  @override
  String get playAll => 'Tout lire';

  @override
  String get shuffleAll => 'Lecture aléatoire de tous les titres';

  @override
  String get sortBy => 'Trier par';

  @override
  String get sortByName => 'Nom';

  @override
  String get sortByArtist => 'Artiste';

  @override
  String get sortByAlbum => 'Album';

  @override
  String get sortByDate => 'Date';

  @override
  String get sortByDuration => 'Durée';

  @override
  String get ascending => 'Croissant';

  @override
  String get descending => 'Décroissant';

  @override
  String get noLyricsAvailable => 'Paroles non disponibles';

  @override
  String get loading => 'Chargement...';

  @override
  String get error => 'Erreur';

  @override
  String get retry => 'Réessayer';

  @override
  String get noResults => 'Aucun résultat';

  @override
  String get searchHint => 'Rechercher des titres, des albums, des artistes...';

  @override
  String get allSongs => 'Tous les titres';

  @override
  String get allAlbums => 'Tous les albums';

  @override
  String get allArtists => 'Tous les artistes';

  @override
  String trackNumber(int number) {
    return 'Piste n°$number';
  }

  @override
  String songsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres',
      one: '1 titre',
      zero: 'Aucun titre',
    );
    return '$_temp0';
  }

  @override
  String albumsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
      zero: 'Aucun album',
    );
    return '$_temp0';
  }

  @override
  String get logout => 'Déconnexion';

  @override
  String get confirmLogout => 'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get offlineMode => 'Mode hors-connexion';

  @override
  String get radio => 'Radio';

  @override
  String get changelog => 'Journal des changements';

  @override
  String get platform => 'Plateforme';

  @override
  String get server => 'Serveur';

  @override
  String get display => 'Affichage';

  @override
  String get playerInterface => 'Interface du lecteur';

  @override
  String get smartRecommendations => 'Recommandations personnalisées';

  @override
  String get showVolumeSlider => 'Afficher le curseur du volume';

  @override
  String get showVolumeSliderSubtitle =>
      'Afficher le contrôle du volume dans l\'écran de lecture en cours';

  @override
  String get showStarRatings => 'Afficher les notes';

  @override
  String get showStarRatingsSubtitle => 'Noter les pistes et voir les notes';

  @override
  String get showMiniPlayerHeart => 'Bouton Favori sur le mini-lecteur';

  @override
  String get showMiniPlayerHeartSubtitle => 'Add to favorites from mini lireer';

  @override
  String get showMiniPlayerRepeat => 'Bouton Répéter sur le mini-lecteur';

  @override
  String get showMiniPlayerRepeatSubtitle =>
      'Toggle repeat mode from mini lireer';

  @override
  String get showMiniPlayerShuffle => 'Bouton Aléatoire sur le mini-lecteur';

  @override
  String get showMiniPlayerShuffleSubtitle => 'Toggle shuffle from mini lireer';

  @override
  String get enableRecommendations => 'Activer les Recommandations';

  @override
  String get enableRecommendationsSubtitle =>
      'Recevez des suggestions musicales personnalisées';

  @override
  String get listeningData => 'Données d\'écoute';

  @override
  String totalPlays(int count) {
    return 'Lectures au total : $count';
  }

  @override
  String get clearListeningHistory => 'Effacer l\'historique des écoutes';

  @override
  String get confirmClearHistory =>
      'Cela réinitialisera toutes vos données d\'écoute et recommandations. Êtes-vous sûr(e) ?';

  @override
  String get historyCleared => 'Historique d\'écoutes effacé';

  @override
  String get discordStatus => 'Statut Discord';

  @override
  String get discordStatusSubtitle =>
      'Afficher la chanson en cours de lecture sur le profil Discord';

  @override
  String get selectLanguage => 'Sélectionner la langue';

  @override
  String get systemDefault => 'Système par défaut';

  @override
  String get communityTranslations => 'Traduction par la communauté';

  @override
  String get communityTranslationsSubtitle =>
      'Aidez-nous à traduire Musly sur Crowdin';

  @override
  String get checkTranslationUpdates =>
      'Vérifier les mises à jour des traductions';

  @override
  String get checkTranslationUpdatesSubtitle =>
      'Synchroniser les dernières traductions en direct (OTA)';

  @override
  String get checkingTranslationUpdates =>
      'Recherche des mises à jour de traduction…';

  @override
  String get translationsUpdated => 'Traductions mises à jour avec succès !';

  @override
  String get translationsUpToDate => 'Les traductions sont déjà à jour';

  @override
  String get yourLibrary => 'Ma Bibliothèque';

  @override
  String get filterAll => 'Tout';

  @override
  String get faves => 'Favoris';

  @override
  String get filterPlaylists => 'Playlists';

  @override
  String get filterAlbums => 'Albums';

  @override
  String get filterArtists => 'Artistes';

  @override
  String get likedSongs => 'Titres \"J\'aime\"';

  @override
  String get likedAlbums => 'Albums likés';

  @override
  String get noLikedAlbums => 'Aucun album liké pour le moment';

  @override
  String get localMusicLibrary => 'Local Music Bibliothèque';

  @override
  String get mergeLocalLibrary => 'Merge with Server Bibliothèque';

  @override
  String get mergeLocalLibrarySubtitle =>
      'Afficher les musiques locales aux côtés de la bibliothèque serveur';

  @override
  String get localMusicStats => 'Fichiers audio locaux';

  @override
  String get addMusicFolder => 'Ajouter un dossier de musique';

  @override
  String get rescanLocalMusic => 'Rescanner les musiques locales';

  @override
  String get localLibraryEmpty => 'Votre bibliothèque est vide';

  @override
  String get localLibraryEmptySubtitle =>
      'Aucun fichier musical trouvé sur l’appareil. Touchez le bouton pour rescanner.';

  @override
  String get libraryEmpty => 'Votre bibliothèque est vide';

  @override
  String get libraryEmptySubtitle =>
      'Ajoutez des morceaux pour commencer votre écoute.';

  @override
  String get scanForMusic => 'Rechercher des morceaux';

  @override
  String get radioStations => 'Stations radio';

  @override
  String get playlist => 'Playlist';

  @override
  String get internetRadio => 'Radio Internet';

  @override
  String get newPlaylist => 'Nouvelle Playlist';

  @override
  String get playlistName => 'Nom de la liste de lecture';

  @override
  String get create => 'Créer';

  @override
  String get deletePlaylist => 'Supprimer la Playlist';

  @override
  String deletePlaylistConfirmation(String name) {
    return 'Êtes-vous sûr de vouloir supprimer la playlist \"$name \" ?';
  }

  @override
  String playlistDeleted(String name) {
    return 'Playlist \"$name\" supprimée';
  }

  @override
  String errorCreatingPlaylist(Object error) {
    return 'Erreur lors de la création de la playlist : $error';
  }

  @override
  String errorDeletingPlaylist(Object error) {
    return 'Erreur lors de la suppression de la playlist : $error';
  }

  @override
  String playlistCreated(String name) {
    return 'Playlist \"$name\" créée';
  }

  @override
  String get searchTitle => 'Rechercher';

  @override
  String get searchPlaceholder => 'Artistes, chansons, albums';

  @override
  String get tryDifferentSearch => 'Essayez une recherche différente';

  @override
  String get noSuggestions => 'Aucune suggestion';

  @override
  String get browseCategories => 'Parcourir les catégories';

  @override
  String get liveSearchSection => 'Rechercher';

  @override
  String get liveSearch => 'Recherche en direct';

  @override
  String get liveSearchSubtitle =>
      'Mettre à jour les résultats lorsque vous écrivez au lieu d\'afficher une liste déroulante';

  @override
  String get homeSection => 'Accueil';

  @override
  String get showFavoritePlaylistsOnHome =>
      'Playlists favorites sur l\'accueil';

  @override
  String get showFavoritePlaylistsOnHomeSubtitle =>
      'Afficher chaque playlist favorite sur sa propre ligne en haut de l\'écran d\'accueil';

  @override
  String get categoryMadeForYou => 'Fait pour vous';

  @override
  String get categoryNewReleases => 'Nouvelles sorties';

  @override
  String get categoryTopRated => 'Les mieux notés';

  @override
  String get categoryGenres => 'Genres';

  @override
  String get categoryFavorites => 'Favoris';

  @override
  String get categoryRadio => 'Radio';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get tabPlayback => 'Lecture';

  @override
  String get tabStorage => 'Stockage';

  @override
  String get tabServer => 'Serveur';

  @override
  String get tabDisplay => 'Affichage';

  @override
  String get tabSupport => 'Soutien';

  @override
  String get tabAbout => 'À propos';

  @override
  String get sectionAutoDj => 'DJ AUTO';

  @override
  String get autoDjMode => 'Mode DJ Auto';

  @override
  String songsToAdd(int count) {
    return 'Pistes à ajouter : $count';
  }

  @override
  String get sectionReplayGain => 'NORMALISATION DE VOLUME (REPLAYGAIN)';

  @override
  String get replayGainMode => 'Mode de gain';

  @override
  String preamp(String value) {
    return 'Pré-ampli : $value dB';
  }

  @override
  String get preventClipping => 'Empêcher le découpage audio';

  @override
  String fallbackGain(String value) {
    return 'Gain de repli : $value dB';
  }

  @override
  String get sectionStreamingQuality => 'QUALITÉ DE STREAMING';

  @override
  String get enableTranscoding => 'Activer le transcodage';

  @override
  String get qualityWifi => 'Qualité sur réseau Wi-Fi';

  @override
  String get qualityMobile => 'Qualité sur réseau mobile';

  @override
  String get format => 'Format';

  @override
  String get transcodingSubtitle =>
      'Réduire la consommation de données avec une qualité inférieure';

  @override
  String get modeOff => 'Désactivé';

  @override
  String get modeTrack => 'Piste';

  @override
  String get modeAlbum => 'Album';

  @override
  String get sectionServerConnection => 'CONNEXION DU SERVEUR';

  @override
  String get serverType => 'Type de serveur';

  @override
  String get notConnected => 'Non connecté';

  @override
  String get unknown => 'Inconnu';

  @override
  String get sectionMusicFolders => 'RÉPERTOIRES DE MUSIQUE';

  @override
  String get musicFolders => 'Dossiers musicaux';

  @override
  String get noMusicFolders => 'Aucun dossier de musique trouvé';

  @override
  String get sectionSavedProfiles => 'PROFILS ENREGISTRÉS';

  @override
  String get switchProfile => 'Changer de profil';

  @override
  String get switchServer => 'Changer de serveur';

  @override
  String get addProfile => 'Ajouter un profil';

  @override
  String switchProfileConfirmation(String profile) {
    return 'Se connecter à « $profile » ?';
  }

  @override
  String get sectionAccount => 'COMPTE';

  @override
  String get logoutConfirmation =>
      'Êtes-vous sûr de vouloir vous déconnecter ? Cela effacera également toutes les données mises en cache.';

  @override
  String get sectionCacheSettings => 'PARAMÈTRES DU CACHE';

  @override
  String get imageCache => 'Cache d\'images';

  @override
  String get musicCache => 'Cache de musiques';

  @override
  String get bpmCache => 'Cache BPM';

  @override
  String get saveAlbumCovers => 'Enregistrer les pochettes d\'album en local';

  @override
  String get saveSongMetadata =>
      'Enregistrer les métadonnées de la piste en local';

  @override
  String get saveBpmAnalysis => 'Enregistrer les analyses BPM en local';

  @override
  String get sectionCacheCleanup => 'SUPPRESSION DE CACHE';

  @override
  String get clearAllCache => 'Vider tout le cache';

  @override
  String get allCacheCleared => 'Tout le cache a été effacé';

  @override
  String get sectionOfflineDownloads => 'TÉLÉCHARGEMENT HORS LIGNE';

  @override
  String get downloadedSongs => 'Pistes téléchargées';

  @override
  String downloadingLibrary(int progress, int total) {
    return 'Téléchargement de la bibliothèque... $progress/$total';
  }

  @override
  String get downloadAllLibrary => 'Télécharger toute la bibliothèque';

  @override
  String downloadLibraryConfirm(int count) {
    return 'Cette action va télécharger $count pistes sur votre appareil. Cela peut prendre un certain temps et utiliser un espace de stockage significatif.\n\nVoulez-vous continuer ?';
  }

  @override
  String get keepScreenOnDuringDownload => 'Garder l’écran allumé';

  @override
  String get keepScreenOnDuringDownloadSubtitle =>
      'Prevents télécharger from failing when device locks';

  @override
  String get parallelDownloads => 'Parallel Téléchargers';

  @override
  String get parallelDownloadsSubtitle =>
      'Télécharger multiple songs simultaneously';

  @override
  String get downloadSingular => 'télécharger';

  @override
  String get downloadPlural => 'téléchargers';

  @override
  String get slowerButStable => 'Plus lent mais plus stable';

  @override
  String get fasterButMoreData => 'Plus rapide mais consomme plus de données';

  @override
  String get libraryDownloadStarted =>
      'Le téléchargement de la bibliothèque a démarré';

  @override
  String get deleteDownloads => 'Supprimer tous les téléchargements';

  @override
  String get downloadsDeleted => 'Tous les téléchargements ont été supprimés';

  @override
  String get noSongsAvailable =>
      'Aucune musique disponible. Veuillez d\'abord charger votre bibliothèque.';

  @override
  String get sectionBpmAnalysis => 'ANALYSE BPM';

  @override
  String get cachedBpms => 'BPMs en cache';

  @override
  String get cacheAllBpms => 'Mettre en cache tous les BPMs';

  @override
  String get clearBpmCache => 'Vider le cache BPM';

  @override
  String get bpmCacheCleared => 'Cache BPM effacé';

  @override
  String downloadedStats(int count, String size) {
    return 'Chansons $count • $size';
  }

  @override
  String get sectionInformation => 'INFORMATIONS';

  @override
  String get sectionDeveloper => 'DÉVELOPPEURS';

  @override
  String get sectionLinks => 'LIENS';

  @override
  String get githubRepo => 'Dépôt GitHub';

  @override
  String get playingFrom => 'LECTURE DEPUIS';

  @override
  String get live => 'EN DIRECT';

  @override
  String get streamingLive => 'Diffusion en direct';

  @override
  String get stopRadio => 'Arrêter la radio';

  @override
  String get removeFromLiked => 'Supprimer des titres favoris';

  @override
  String get addToLiked => 'Ajouter aux pistes \"J\'aime\"';

  @override
  String get playNext => 'Lecture suivante';

  @override
  String get addToQueue => 'Ajouter à la liste';

  @override
  String get goToAlbum => 'Aller à l’album';

  @override
  String get goToArtist => 'Aller à l\'artiste';

  @override
  String get rateSong => 'Noter la chanson';

  @override
  String rateSongValue(int rating, String stars) {
    return 'Noter la chanson ($rating $stars)';
  }

  @override
  String get ratingRemoved => 'Note effacée';

  @override
  String rated(int rating, String stars) {
    return 'Notée $rating $stars';
  }

  @override
  String get removeRating => 'Supprimer la note';

  @override
  String get downloaded => 'Téléchargé';

  @override
  String downloading(int percent) {
    return 'Téléchargement... $percent%';
  }

  @override
  String get removeDownload => 'Supprimer le téléchargement';

  @override
  String get removeDownloadConfirm =>
      'Supprimer cette chanson du stockage hors-ligne ?';

  @override
  String get downloadRemoved => 'Téléchargement supprimé';

  @override
  String downloadedTitle(String title) {
    return 'Téléchargé \"$title\"';
  }

  @override
  String get downloadFailed => 'Echec du téléchargement';

  @override
  String downloadError(Object error) {
    return 'Erreur de téléchargement : $error';
  }

  @override
  String addedToPlaylist(String title, String playlist) {
    return 'Ajout de «$title» à $playlist';
  }

  @override
  String errorAddingToPlaylist(Object error) {
    return 'Erreur lors de l\'ajout à la playlist : $error';
  }

  @override
  String get noPlaylists => 'Aucune playlist disponible';

  @override
  String get createNewPlaylist => 'Créer une nouvelle playlist';

  @override
  String artistNotFound(String name) {
    return 'Artiste «$name» introuvable';
  }

  @override
  String errorSearchingArtist(Object error) {
    return 'Erreur lors de la recherche de l\'artiste: $error';
  }

  @override
  String get selectArtist => 'Sélectionner un artiste';

  @override
  String get removedFromFavorites => 'Retiré des favoris';

  @override
  String get addedToFavorites => 'Ajouté aux favoris';

  @override
  String get star => 'étoile';

  @override
  String get stars => 'étoiles';

  @override
  String get albumNotFound => 'Album introuvable';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get topSongs => 'Top Chansons';

  @override
  String get connected => 'Connecté';

  @override
  String get noSongPlaying => 'Aucun morceau en cours de lecture';

  @override
  String get internetRadioUppercase => 'RADIO INTERNET';

  @override
  String get playingNext => 'Lecture suivante';

  @override
  String get createPlaylistTitle => 'Créer une liste de lecture';

  @override
  String get playlistNameHint => 'Nom de la liste de lecture';

  @override
  String playlistCreatedWithSong(String name) {
    return 'Liste de lecture «$name» créée avec cette piste';
  }

  @override
  String errorLoadingPlaylists(Object error) {
    return 'Erreur lors du chargement des listes de lecture : $error';
  }

  @override
  String get playlistNotFound => 'Liste de lecture introuvable';

  @override
  String get noSongsInPlaylist => 'Aucune piste dans cette liste de lecture';

  @override
  String get noFavoriteSongsYet => 'Aucune piste favorite pour le moment';

  @override
  String get noFavoriteAlbumsYet => 'Aucun album favori pour le moment';

  @override
  String get listeningHistory => 'Historique d\'écoute';

  @override
  String get noListeningHistory => 'Pas d\'historique d\'écoute';

  @override
  String get songsWillAppearHere =>
      'Les pistes que vous jouez apparaîtront ici';

  @override
  String get sortByTitleAZ => 'Titre (A-Z)';

  @override
  String get sortByTitleZA => 'Titre (Z-A)';

  @override
  String get sortByArtistAZ => 'Artiste (A-Z)';

  @override
  String get sortByArtistZA => 'Artiste (Z-A)';

  @override
  String get sortByAlbumAZ => 'Album (A-Z)';

  @override
  String get sortByAlbumZA => 'Album (Z-A)';

  @override
  String get recentlyAdded => 'Récemment Ajouté';

  @override
  String get noSongsFound => 'Aucune piste trouvée';

  @override
  String get noAlbumsFound => 'Aucun album trouvé';

  @override
  String get noHomepageUrl => 'Aucune URL de page d\'accueil disponible';

  @override
  String get playStation => 'Lancer la station';

  @override
  String get openHomepage => 'Ouvrir la page d\'accueil';

  @override
  String get copyStreamUrl => 'Copier l\'URL du flux';

  @override
  String get failedToLoadRadioStations =>
      'Impossible de charger les stations radio';

  @override
  String get noRadioStations => 'Aucune station radio';

  @override
  String get noRadioStationsHint =>
      'Ajoutez des stations radio dans les paramètres de votre serveur Navidrome pour les voir ici.';

  @override
  String get connectToServerSubtitle =>
      'Connectez-vous à votre serveur Subsonic';

  @override
  String get pleaseEnterServerUrl => 'Veuillez entrer l\'URL du serveur';

  @override
  String get invalidUrlFormat =>
      'L\'URL doit commencer par http:// ou https://';

  @override
  String get pleaseEnterUsername => 'Veuillez entrer le nom d\'utilisateur';

  @override
  String get pleaseEnterPassword => 'Veuillez saisir votre mot de passe';

  @override
  String get legacyAuthentication => 'Authentification héritée';

  @override
  String get legacyAuthSubtitle =>
      'Utiliser pour les anciens serveurs Subsonic';

  @override
  String get allowSelfSignedCerts => 'Autoriser les certificats autosignés';

  @override
  String get allowSelfSignedSubtitle =>
      'Pour les serveurs avec des certificats TLS/SSL personnalisés';

  @override
  String get advancedOptions => 'Options avancées';

  @override
  String get customTlsCertificate => 'Certificat TLS/SSL personnalisé';

  @override
  String get customCertificateSubtitle =>
      'Télécharger un certificat personnalisé pour les serveurs avec une AC non standard';

  @override
  String get selectCertificateFile => 'Sélectionner un fichier de certificat';

  @override
  String get clientCertificate => 'Certificat client (mTLS)';

  @override
  String get clientCertificateSubtitle =>
      'Authentifier ce client en utilisant un certificat (nécessite le serveur mTLS)';

  @override
  String get selectClientCertificate => 'Sélectionnez le certificat client';

  @override
  String get clientCertPassword => 'Mot de passe du certificat (facultatif)';

  @override
  String failedToSelectClientCert(String error) {
    return 'Impossible de sélectionner le certificat client : $error';
  }

  @override
  String get connect => 'Connexion';

  @override
  String get or => 'OU';

  @override
  String get useLocalFiles => 'Utiliser les fichiers locaux';

  @override
  String get startingScan => 'Démarrage de l\'analyse...';

  @override
  String get storagePermissionRequired =>
      'Autorisation d\'accès au stockage requise pour scanner les fichiers locaux';

  @override
  String get noMusicFilesFound =>
      'Aucun fichier de musique trouvé sur votre appareil';

  @override
  String get remove => 'Retirer';

  @override
  String failedToSetRating(Object error) {
    return 'Impossible de définir la note : $error';
  }

  @override
  String get home => 'Accueil';

  @override
  String get playlistsSection => 'LISTES DE LECTURE';

  @override
  String get collapse => 'Réduire';

  @override
  String get expand => 'Étendre';

  @override
  String get createPlaylist => 'Créer une liste de lecture';

  @override
  String get importPlaylist => 'Importer une playlist';

  @override
  String get importPlaylistSubtitle =>
      'Importer depuis Spotify ou YouTube Music (sans connexion requise)';

  @override
  String get checkForUpdates => 'Rechercher des mises à jour';

  @override
  String get checkingForUpdates => 'Recherche de mises à jour…';

  @override
  String get appUpToDate => 'Musly est à jour';

  @override
  String get updateAvailable => 'Mise à jour disponible';

  @override
  String get updateNow => 'Mettre à jour';

  @override
  String get downloadingUpdate => 'Téléchargering update...';

  @override
  String get openOnGitHub => 'Ouvrir sur GitHub';

  @override
  String get skipThisVersion => 'Ignorer cette version';

  @override
  String get updateDownloaded => 'Mise à jour téléchargée';

  @override
  String get likedSongsSidebar => 'Pistes \"J\'aime\"';

  @override
  String playlistSongsCount(int count) {
    return 'Liste de lecture • $count pistes';
  }

  @override
  String get failedToLoadLyrics => 'Impossible de charger les paroles';

  @override
  String get lyricsNotFoundSubtitle =>
      'Les paroles de cette piste n\'ont pas pu être trouvées';

  @override
  String get backToCurrent => 'Revenir à l\'actuel';

  @override
  String get exitFullscreen => 'Quitter le mode plein écran';

  @override
  String get fullscreen => 'Plein écran';

  @override
  String get noLyrics => 'Aucune parole';

  @override
  String get internetRadioMiniPlayer => 'Radio Internet';

  @override
  String get liveBadge => 'EN DIRECT';

  @override
  String get localFilesModeBanner => 'Mode fichiers locaux';

  @override
  String get offlineModeBanner =>
      'Mode hors-ligne – Lecture de la musique téléchargée uniquement';

  @override
  String get updateAvailableSubtitle =>
      'Une nouvelle version de Musly est disponible !';

  @override
  String updateCurrentVersion(String version) {
    return 'Version actuelle : v$version';
  }

  @override
  String updateLatestVersion(String version) {
    return 'Dernière version : v$version';
  }

  @override
  String get whatsNew => 'Quoi de neuf';

  @override
  String get downloadUpdate => 'Télécharger';

  @override
  String get remindLater => 'Me rappeler plus tard';

  @override
  String get seeAll => 'Tout Afficher';

  @override
  String get artistDataNotFound => 'Artiste introuvable';

  @override
  String get addedArtistToQueue => 'Artiste ajouté à la file d\'attente';

  @override
  String get addedArtistToQueueError =>
      'Échec de l\'ajout de l\'artiste à la file d\'attente';

  @override
  String get casting => 'Diffusion';

  @override
  String get dlna => 'DLNA';

  @override
  String get castDlnaBeta => 'Diffusion / DLNA (Bêta)';

  @override
  String get chromecast => 'Chromecast';

  @override
  String get dlnaUpnp => 'DLNA / UPnP';

  @override
  String get disconnect => 'Déconnexion';

  @override
  String get searchingDevices => 'Recherche de périphériques';

  @override
  String get castWifiHint =>
      'Assurez-vous que votre appareil Cast / DLNA\nest sur le même réseau Wi-Fi';

  @override
  String connectedToDevice(String name) {
    return 'Connecté à $name';
  }

  @override
  String failedToConnectDevice(String name) {
    return 'Impossible de se connecter à $name';
  }

  @override
  String get removedFromLikedSongs => 'Retiré des pistes \"J\'aime\"';

  @override
  String get addedToLikedSongs => 'Ajouté aux pistes \"J\'aime\"';

  @override
  String get enableShuffle => 'Activer la lecture aléatoire';

  @override
  String get enableRepeat => 'Activer la répétition';

  @override
  String get connecting => 'Connexion en cours';

  @override
  String get closeLyrics => 'Désactiver les paroles';

  @override
  String errorStartingDownload(Object error) {
    return 'Erreur lors du démarrage du téléchargement : $error';
  }

  @override
  String get errorLoadingGenres => 'Erreur lors du chargement des genres';

  @override
  String get noGenresFound => 'Aucun genre trouvé';

  @override
  String get noAlbumsInGenre => 'Aucun album dans ce genre';

  @override
  String genreTooltip(int songCount, int albumCount) {
    return '$songCount pistes • $albumCount albums';
  }

  @override
  String get sectionJukebox => 'MODE JUKEBOX';

  @override
  String get jukeboxMode => 'Mode Jukebox';

  @override
  String get jukeboxModeSubtitle =>
      'Jouer l\'audio via le serveur au lieu de cet appareil';

  @override
  String get openJukeboxController => 'Ouvrir le contrôleur du Jukebox';

  @override
  String get jukeboxClearQueue => 'Vider la file d\'attente';

  @override
  String get jukeboxShuffleQueue => 'Mélanger la file d\'attente';

  @override
  String get jukeboxQueueEmpty => 'Aucune piste dans la file d\'attente';

  @override
  String get jukeboxNowPlaying => 'En cours de lecture';

  @override
  String get jukeboxQueue => 'File d\'attente';

  @override
  String get jukeboxVolume => 'Volume';

  @override
  String get playOnJukebox => 'Jouer sur le Jukebox';

  @override
  String get addToJukeboxQueue => 'Ajouter à la file d\'attente du Jukebox';

  @override
  String get jukeboxNotSupported =>
      'Le mode Jukebox n\'est pas pris en charge par ce serveur. Activez-le dans la configuration de votre serveur (par exemple EnableJukebox = true dans Navidrome).';

  @override
  String get musicFoldersDialogTitle => 'Sélectionner les dossiers de musique';

  @override
  String get musicFoldersHint =>
      'Laisser tout activer pour utiliser tous les dossiers (par défaut).';

  @override
  String get musicFoldersSaved => 'Sélection de dossier de musique enregistrée';

  @override
  String get artworkStyleSection => 'Style d’illustration';

  @override
  String get artworkCornerRadius => 'Arrondi des coins';

  @override
  String get artworkCornerRadiusSubtitle =>
      'Ajuster l\'apparence des angles des pochettes d\'album';

  @override
  String get artworkCornerRadiusNone => 'Aucun';

  @override
  String get artworkShape => 'Forme';

  @override
  String get artworkShapeRounded => 'Arrondi';

  @override
  String get artworkShapeCircle => 'Cercle';

  @override
  String get artworkShapeSquare => 'Carré';

  @override
  String get artworkShadow => 'Ombre';

  @override
  String get artworkShadowNone => 'Aucun';

  @override
  String get artworkShadowSoft => 'Faible';

  @override
  String get artworkShadowMedium => 'Moyen';

  @override
  String get artworkShadowStrong => 'Fort';

  @override
  String get artworkShadowColor => 'Couleur d\'ombre';

  @override
  String get artworkShadowColorBlack => 'Noir';

  @override
  String get artworkShadowColorAccent => 'Accentuation';

  @override
  String get artworkPreview => 'Aperçu';

  @override
  String artworkCornerRadiusLabel(int value) {
    return '$value pixels';
  }

  @override
  String get noArtwork => 'Pas de pochette d\'album';

  @override
  String get serverUnreachableTitle => 'Impossible d\'atteindre le serveur';

  @override
  String get serverUnreachableSubtitle =>
      'Vérifier votre connexion ou vos paramètres de serveur.';

  @override
  String get openOfflineMode => 'Ouvrir en mode hors connexion';

  @override
  String get appearanceSection => 'Apparence';

  @override
  String get themeLabel => 'Thème';

  @override
  String get accentColorLabel => 'Couleur d\'accentuation';

  @override
  String get circularDesignLabel => 'Design circulaire';

  @override
  String get circularDesignSubtitle =>
      'Interface utilisateur flottante, arrondie avec des panneaux translucides et un effet \"verre flou\" sur le lecteur et la barre de navigation.';

  @override
  String get themeModeSystem => 'Système';

  @override
  String get themeModeLight => 'Clair';

  @override
  String get themeModeDark => 'Sombre';

  @override
  String get liveLabel => 'EN DIRECT';

  @override
  String get discordStatusText => 'Texte de statut Discord';

  @override
  String get discordStatusTextSubtitle =>
      'Deuxième ligne affichée dans l\'activité Discord';

  @override
  String get discordRpcStyleArtist => 'Nom de l\'artiste';

  @override
  String get discordRpcStyleSong => 'Titre de la piste';

  @override
  String get discordRpcStyleApp => 'Nom de l\'application (Musly)';

  @override
  String get sectionVolumeNormalization =>
      'NORMALISATION DU VOLUME (REPLAYGAIN)';

  @override
  String get sectionFadeInOut => 'FONDU ENCHAÎNÉ (CROSSFADE)';

  @override
  String get fadeInOutEnable => 'Activer le fondu (Fade in/out)';

  @override
  String get fadeInOutSubtitle =>
      'Fondu progressif du volume lors de la lecture ou pause';

  @override
  String fadeDuration(int duration) {
    return 'Durée du fondu : $duration ms';
  }

  @override
  String get replayGainModeOff => 'Désactivé';

  @override
  String get replayGainModeTrack => 'Piste';

  @override
  String get replayGainModeAlbum => 'Album';

  @override
  String replayGainPreamp(String value) {
    return 'Pré-ampli : $value dB';
  }

  @override
  String get replayGainPreventClipping => 'Empêcher le découpage audio';

  @override
  String replayGainFallbackGain(String value) {
    return 'Gain de repli : $value dB';
  }

  @override
  String autoDjSongsToAdd(int count) {
    return 'Pistes à ajouter : $count';
  }

  @override
  String get transcodingEnable => 'Activer le transcodage';

  @override
  String get transcodingEnableSubtitle =>
      'Réduire la consommation de données avec une qualité inférieure';

  @override
  String get smartTranscoding => 'Transcodage intelligent';

  @override
  String get smartTranscodingSubtitle =>
      'Ajuste automatiquement la qualité en fonction de votre connexion (Wi-Fi vs données mobiles)';

  @override
  String get smartTranscodingDetectedNetwork => 'Réseau détecté : ';

  @override
  String smartTranscodingActiveBitrate(String bitrate) {
    return 'Débit actif : $bitrate';
  }

  @override
  String get transcodingWifiQuality => 'Qualité sur réseau Wi-Fi';

  @override
  String get transcodingWifiQualitySubtitleSmart =>
      'Utilisé automatiquement en Wi-Fi';

  @override
  String get transcodingWifiQualitySubtitle => 'Débit binaire en Wi-Fi';

  @override
  String get transcodingMobileQuality => 'Qualité sur réseau mobile';

  @override
  String get transcodingMobileQualitySubtitleSmart =>
      'Utilisé automatiquement sur les données mobiles';

  @override
  String get transcodingMobileQualitySubtitle => 'Débit sur données mobiles';

  @override
  String get transcodingFormat => 'Format de transcodage';

  @override
  String get transcodingFormatSubtitle =>
      'Codec audio utilisé pour la diffusion';

  @override
  String get transcodingBitrateOriginal => 'Original (sans transcodage)';

  @override
  String get transcodingFormatOriginal => 'Original (sans perte)';

  @override
  String get imageCacheTitle => 'Cache d\'images';

  @override
  String get imageCacheSubtitle =>
      'Enregistrer les pochettes d\'album en local';

  @override
  String get musicCacheTitle => 'Cache de musiques';

  @override
  String get musicCacheSubtitle =>
      'Enregistrer les métadonnées de la piste en local';

  @override
  String get bpmCacheTitle => 'Cache BPM';

  @override
  String get bpmCacheSubtitle => 'Enregistrer les analyses BPM en local';

  @override
  String get sectionAboutInformation => 'INFORMATIONS';

  @override
  String get sectionAboutDeveloper => 'DÉVELOPPEUR';

  @override
  String get sectionAboutLinks => 'LIENS';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutPlatform => 'Plateforme';

  @override
  String get aboutMadeBy => 'Développé par dddevid';

  @override
  String get aboutGitHub => 'github.com/dddevid';

  @override
  String get aboutLinkGitHub => 'Dépôt GitHub';

  @override
  String get aboutLinkChangelog => 'Journal des modifications';

  @override
  String get aboutLinkReportIssue => 'Signaler un problème';

  @override
  String get aboutLinkDiscord => 'Rejoignez la communauté Discord';

  @override
  String get sectionAnalyticsPrivacy => 'Confidentialité & Données';

  @override
  String get anonymousAnalytics => 'Statistiques anonymes';

  @override
  String get anonymousAnalyticsSubtitle =>
      'Aidez à améliorer Musly grâce aux rapports de plantage anonymes';

  @override
  String get deviceId => 'Identifiant appareil';

  @override
  String deviceIdAnonymous(String id) {
    return 'Identifiant anonyme : $id';
  }

  @override
  String get deviceIdDisabled =>
      'Activez les statistiques pour voir votre identifiant anonyme';

  @override
  String get aboutDeviceId => 'À propos de l\'identifiant de l\'appareil';

  @override
  String get aboutDeviceIdSubtitle =>
      'Il s\'agit d\'un identifiant anonyme généré par l\'application. Il ne peut être lié à votre identité personnelle et est utilisé uniquement pour les statistiques.';

  @override
  String get supportGreeting => 'Bonjour !';

  @override
  String get supportParagraph1 =>
      'I\'m Devid, the developer behind Musly. I built this app because I love music and believe everyone deserves a beautiful, free music lireer.';

  @override
  String get supportParagraph2 =>
      'Musly est un projet totalement gratuit et open-source. Sans publicité, sans traqueur et sans abonnement payant. J’y consacre mon temps libre avec passion pour créer une expérience musicale fluide et moderne.';

  @override
  String get supportParagraph3 =>
      'Cependant, les serveurs de tests, les outils de développement et le café ont un coût. Si Musly fait partie de votre quotidien et que vous souhaitez dire « merci », une petite contribution est une immense aide pour poursuivre le projet.';

  @override
  String get supportParagraph4 =>
      'Aucune obligation bien sûr : votre plaisir d’écoute sur l’application est déjà la plus belle des récompenses !';

  @override
  String get supportDonationTitle => 'Faire un don de soutien';

  @override
  String get supportDonationSubtitle => 'via Revolut – chaque geste compte !';

  @override
  String get supportDiscordTitle => 'Rejoindre la communauté Discord';

  @override
  String get supportDiscordSubtitle =>
      'Discuter, obtenir de l’aide ou proposer de nouvelles idées';

  @override
  String get supportWaysTitle => 'Autres façons d’aider';

  @override
  String get supportWayRate => 'Laisser une note sur l’app store';

  @override
  String get supportWayShare => 'Parler de Musly à vos amis';

  @override
  String get supportWayBugs => 'Signaler un bug ou suggérer une fonctionnalité';

  @override
  String get supportWayEnjoy => 'Simplement profiter de vos musiques !';

  @override
  String get supportMadeWithLove => 'Créé avec passion en Italie';

  @override
  String get playbackSpeed => 'Vitesse de lecture';

  @override
  String get normalSpeed => 'Normale (1x)';

  @override
  String get preservePitch => 'Préserver la tonalité';

  @override
  String get preservePitchSubtitle =>
      'Conserve la hauteur originale des voix lors du changement de vitesse';

  @override
  String get pitch => 'Tonalité';

  @override
  String get pitchPreserved => 'tonalité préservée';

  @override
  String speedTooltipWithPitch(String speed, String pitch) {
    return 'Vitesse $speed • tonalité ${pitch}x';
  }

  @override
  String speedTooltipPitchPreserved(String speed) {
    return 'Vitesse $speed • tonalité préservée';
  }

  @override
  String get sleepTimer => 'Minuteur de sommeil';

  @override
  String get sleepTimerActive => 'Minuteur de veille actif';

  @override
  String get fadeOut => 'Fondu sonore';

  @override
  String fadeOutSubtitle(int seconds) {
    return 'Baisse progressivement le volume sonore sur les $seconds dernières secondes';
  }

  @override
  String get finishCurrentSong => 'Terminer le morceau en cours';

  @override
  String get finishCurrentSongSubtitle =>
      'Met en pause dès que le titre actuel se termine';

  @override
  String sleepTimerMinutes(int count) {
    return '$count min';
  }

  @override
  String sleepTimerHours(int count) {
    return '$count heure';
  }

  @override
  String sleepTimerSetFor(String duration) {
    return 'Minuteur réglé sur $duration';
  }

  @override
  String get customDuration => 'Durée personnalisée…';

  @override
  String get cancelTimer => 'Annuler le minuteur';

  @override
  String get customSleepTimer => 'Minuteur personnalisé';

  @override
  String get set => 'Définir';

  @override
  String get addToPlaylistTitle => 'Ajouter à la playlist';

  @override
  String get yourPlaylistsLabel => 'Your Lirelists';

  @override
  String get enableLrcLibFallback => 'Paroles via LRCLIB';

  @override
  String get lrcLibFallbackSubtitle =>
      'Recherche automatique sur LRCLIB lorsque votre serveur ne propose pas les paroles';

  @override
  String get themeSaved => 'Thème enregistré';

  @override
  String get themeUnsavedChanges => 'Modifications non enregistrées';

  @override
  String get themeUnsavedChangesTitle => 'Modifications non enregistrées';

  @override
  String get themeUnsavedChangesBody =>
      'Des modifications n’ont pas été sauvegardées. Voulez-vous les enregistrer avant de quitter ?';

  @override
  String get discard => 'Abandonner';

  @override
  String get done => 'Terminé';

  @override
  String pickColor(String label) {
    return 'Choisir $label';
  }

  @override
  String get titleStyle => 'Style du titre';

  @override
  String get artistStyle => 'Style de l\'artiste';

  @override
  String get themeActive => 'ACTIF';

  @override
  String get themeSafeMode => 'SÉCURISÉ';

  @override
  String get themeCodeMode => 'CODE';

  @override
  String get themeAnimBadge => 'ANIM';

  @override
  String themeAuthor(String author) {
    return 'par $author';
  }

  @override
  String get audioFocusDenied =>
      'Impossible de démarrer la lecture — une autre application utilise le focus audio';

  @override
  String get addToLibrary => 'Ajouter à la bibliothèque';

  @override
  String get alreadyInLibrary => 'Morceau déjà présent dans la bibliothèque';

  @override
  String get selectPlaylist => 'Select Lirelist';

  @override
  String get endOfSong => 'Fin du morceau';

  @override
  String get muslyConnect => 'Musly Connect';

  @override
  String get connectToDevice => 'Se connecter à un appareil';

  @override
  String get currentlyPlayingOn => 'Actuellement en lecture sur';

  @override
  String get noDevicesFound =>
      'Aucun autre appareil Musly détecté sur votre réseau Wi-Fi.';

  @override
  String get transferPlaybackHere => 'Transfer lireback here';

  @override
  String playbackTransferredTo(String device) {
    return 'Lireback transferred to $device';
  }

  @override
  String get muslyBeatSync => 'Musly BeatSync';

  @override
  String get beatSyncSubtitle =>
      'Synchronisez plusieurs téléphones et ordinateurs en Wi-Fi comme haut-parleurs surround avec une précision à la milliseconde.';

  @override
  String get hostParty => 'Lancer une session';

  @override
  String get joinParty => 'Rejoindre une session';

  @override
  String get leaveParty => 'Quitter la session';

  @override
  String get audioPhaseCalibration => 'Calibrage de phase audio';

  @override
  String get phaseCalibrationSubtitle =>
      'Ajustez en cas de décalage avec des écouteurs Bluetooth ou enceintes externes.';

  @override
  String get partySpeakers => 'Enceintes de la session';

  @override
  String get muslyWrapped => 'Rétrospective Musly';

  @override
  String get wrappedSeasonal => 'Musly Lireback is Seasonal';

  @override
  String get playYourTopSongs => 'Lire Your Top Morceaux';

  @override
  String get milestone50SongsTitle => 'Merci de tout cœur !';

  @override
  String get milestone50SongsBadge => 'CAP DES 50 MORCEAUX';

  @override
  String get milestone50SongsMessage =>
      'Vous venez d’écouter plus de 50 morceaux sur Musly ! Merci de nous faire confiance pour votre quotidien musical.';

  @override
  String get continueListening => 'Continuer l’écoute';

  @override
  String get lyricsUnderArtwork => 'Paroles sous la pochette';

  @override
  String get lyricsUnderArtworkSubtitle =>
      'Show currently synced lyric line under the album cover in the full-screen lireer';

  @override
  String get lyricsDisplaySection => 'AFFICHAGE DES PAROLES';

  @override
  String get lyricsBlurUnfocused => 'Flou des lignes secondaires';

  @override
  String get lyricsBlurUnfocusedSubtitle =>
      'Applique un flou cinématique élégant sur les lignes précédentes et suivantes';

  @override
  String get lyricsAlignment => 'Alignement des paroles';

  @override
  String get lyricsAlignmentCentered => 'Centré';

  @override
  String get lyricsAlignmentLeft => 'Aligné à gauche';

  @override
  String get alignLeft => 'À gauche';

  @override
  String get alignCenter => 'Centré';

  @override
  String get lyricsGlowEffect => 'Lueur sur la ligne active';

  @override
  String get lyricsGlowEffectSubtitle =>
      'Subtle glow effect on currently lireing lyric line';

  @override
  String get lyricsKeepScreenOn => 'Garder l’écran allumé';

  @override
  String get lyricsKeepScreenOnSubtitle =>
      'Empêche l’écran de se verrouiller pendant la lecture des paroles';

  @override
  String get hideWindowTitlebar => 'Masquer la barre de titre de la fenêtre';

  @override
  String get hideWindowTitlebarSubtitle =>
      'Masque la barre de titre système (idéal pour Linux Wayland et gestionnaires en tuiles)';

  @override
  String get sectionSmartCrossfade => 'Transitions et Enchaînements';

  @override
  String get trackCrossfade => 'Enchaînement des pistes';

  @override
  String get crossfadeOffSubtitle => 'Transitions enchaînées désactivées';

  @override
  String crossfadeDurationSubtitle(int seconds) {
    return '$seconds secondes de transition enchaînée';
  }

  @override
  String crossfadeDurationBadge(int seconds) {
    return '${seconds}s';
  }

  @override
  String get sectionGaplessPlayback => 'Lecture sans blanc';

  @override
  String get gaplessPlayback => 'Lecture sans blanc (Gapless)';

  @override
  String get gaplessPlaybackSubtitle =>
      'Enchaînement direct des pistes sans interruption';

  @override
  String get sectionLyrics => 'Paroles';

  @override
  String get networkWifi => 'Wi-Fi';

  @override
  String get networkMobile => 'Réseau mobile';

  @override
  String get downloadFolder => 'Télécharger Folder';

  @override
  String get downloadFolderDefault => 'Par défaut (Stockage interne)';

  @override
  String get activeDownloads => 'Téléchargements actifs';

  @override
  String get noDownloadsInProgress => 'No téléchargers in progress';

  @override
  String get playlistDownloads => 'Lirelist Téléchargers';

  @override
  String playlistSongsDownloadedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs téléchargered',
      one: '1 song téléchargered',
    );
    return '$_temp0';
  }

  @override
  String get songsStreamCache => 'Morceaux & Streaming Cache';

  @override
  String get imageArtworkCache => 'Cache des pochettes & images';

  @override
  String cacheDiskUsage(String size) {
    return '$size utilisés sur le disque';
  }

  @override
  String totalCacheDiskUsage(String size) {
    return 'Espace cache total : $size';
  }

  @override
  String get clearAudioCacheTooltip => 'Vider le cache musical';

  @override
  String get clearImageCacheTooltip => 'Vider le cache des images';

  @override
  String get audioCacheCleared => 'Cache audio effacé';

  @override
  String get imageCacheCleared => 'Cache des pochettes vidé avec succès';

  @override
  String folderAdded(String path) {
    return 'Dossier ajouté : $path';
  }

  @override
  String get removeFolderTitle => 'Retirer Folder';

  @override
  String removeFolderConfirm(String path) {
    return 'Retirer \"$path\" from scan paths?';
  }

  @override
  String get folderRemoved => 'Dossier supprimé';

  @override
  String get loadingLibrary => 'Chargement de la bibliothèque…';

  @override
  String get libraryEmptyError =>
      'Bibliothèque appears to be empty or failed to load. Make sure your server supports full library scanning.';

  @override
  String get serverStatusConnected => 'CONNECTÉ';

  @override
  String get serverStatusConnecting => 'CONNEXION EN COURS…';

  @override
  String get serverStatusOffline => 'HORS LIGNE';

  @override
  String get serverStatusNotConnected => 'Non connecté';

  @override
  String get switchServerButton => 'Changer';

  @override
  String get savedServersSection => 'SERVEURS & SOURCES ENREGISTRÉS';

  @override
  String get manage => 'Gérer';

  @override
  String get serverActiveBadge => 'ACTIF';

  @override
  String get addServerOrService => 'Ajouter un serveur / service';

  @override
  String get welcomeTourTitle => 'Guide de bienvenue';

  @override
  String get welcomeTourSubtitle =>
      'Relire the introductory onboarding experience';

  @override
  String get muslyPlaybackDev => 'Lireback Preview (Test Mode)';

  @override
  String get muslyPlaybackDevSubtitle =>
      'Découvrez votre rétrospective musicale sans attendre le mois de novembre';

  @override
  String get muslyPlaybackAnnual => 'Musly Lireback';

  @override
  String get muslyPlaybackAnnualSubtitle =>
      'Votre rétrospective annuelle se débloque automatiquement entre fin novembre et mi-janvier.\n\nContinuez d’écouter votre musique pour enrichir votre univers sonore !';

  @override
  String get sectionAboutSupport => 'SOUTIEN & COMMUNAUTÉ';

  @override
  String get thanksForRating => 'Merci pour votre note !';

  @override
  String get rateMusly => 'Noter Musly';

  @override
  String get alreadyRatedSubtitle => 'Vous avez déjà noté l\'application';

  @override
  String get shareFeedbackSubtitle => 'Donnez votre avis sur l’application';

  @override
  String get supportMuslyTitle => 'Soutenir Musly';

  @override
  String get supportMuslySubtitle => 'Rejoindre le Discord ou faire un don';

  @override
  String get rateMuslyDialogTitle => 'Votre avis sur Musly';

  @override
  String get rateMuslyDialogQuestion =>
      'Comment évaluez-vous votre expérience d’écoute ?';

  @override
  String get optionalFeedbackHint => 'Remarque ou suggestion (facultatif)…';

  @override
  String get submit => 'Envoyer';

  @override
  String get thankYouFeedback => 'Merci pour votre retour !';

  @override
  String devPlaybackTapsAway(int count) {
    return '$count taps away from Developer Lireback Preview';
  }

  @override
  String get devPlaybackUnlocked => 'Developer Lireback Preview unlocked!';

  @override
  String get craftedWith => 'Conçu avec ';

  @override
  String get inItaly => ' en Italie';

  @override
  String get switchServerTitle => 'Changer de serveur';

  @override
  String get switchServerSubtitle =>
      'Sélectionnez un serveur actif ou une source musicale';

  @override
  String get addServerButton => 'Ajouter un serveur';

  @override
  String get noServersSavedYet => 'Aucun serveur enregistré pour le moment';

  @override
  String connectedTo(String name) {
    return 'Connecté à $name';
  }

  @override
  String errorConnectingServer(String error) {
    return 'Erreur de connexion au serveur : $error';
  }

  @override
  String get renameServerProfile => 'Renommer le profil serveur';

  @override
  String get profileNameLabel => 'Nom du profil';

  @override
  String get enterNewNameHint => 'Saisissez un nouveau nom';

  @override
  String get removeServerTitle => 'Retirer Server';

  @override
  String removeServerConfirm(String name) {
    return 'Voulez-vous vraiment supprimer « $name » de vos serveurs enregistrés ?';
  }

  @override
  String get noPlaylistsFound => 'No lirelists found';

  @override
  String get supportDialogDescription =>
      'Musly est un projet libre et open-source. Votre soutien permet de faire vivre et évoluer l’application !';

  @override
  String get supportDialogJoinDiscord => 'Rejoindre notre Discord';

  @override
  String get supportDialogDiscordSubtitle =>
      'Aide, fonctionnalités en avant-première et échanges';

  @override
  String get supportDialogDonateTitle => 'Faire un don';

  @override
  String get supportDialogDonateSubtitle =>
      'Participer aux frais d’hébergement et encourager le développement';

  @override
  String get dontShowAgain => 'Ne plus afficher';

  @override
  String get maybeLater => 'Plus tard';

  @override
  String get addAllToQueue => 'Tout ajouter à la file d\'attente';

  @override
  String songsAddedToQueue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux ajoutés à la file',
      one: '1 morceau ajouté à la file',
    );
    return '$_temp0';
  }

  @override
  String get searchInAlbum => 'Rechercher in album';

  @override
  String get searchInPlaylist => 'Rechercher in lirelist';

  @override
  String get filterTracks => 'Filtrer les pistes…';

  @override
  String get filterSongs => 'Filtrer les morceaux…';

  @override
  String get noSongsInQueue => 'Aucun morceau dans la file d’attente';

  @override
  String get moreOptions => 'Plus d\'options';

  @override
  String get upNext => 'À suivre';

  @override
  String get removeSelected => 'Retirer selected';

  @override
  String get reorderSongs => 'Réorganiser la file';

  @override
  String get selectSongs => 'Sélectionner des morceaux';

  @override
  String get doneReordering => 'Terminé';

  @override
  String get downloadAlbum => 'Télécharger album';

  @override
  String get downloadPlaylist => 'Télécharger lirelist';

  @override
  String get downloadedTapToRemove => 'Téléchargered — tap to remove';

  @override
  String get downloadingTapToCancel => 'Téléchargering — tap to cancel';

  @override
  String get removeDownloadsTitle => 'Retirer téléchargers?';

  @override
  String removeAlbumDownloadsConfirm(int count, String name) {
    return 'Retirer all $count téléchargered songs from \"$name\"?';
  }

  @override
  String removePlaylistDownloadsConfirm(int count, String name) {
    return 'Retirer all $count téléchargered songs from \"$name\"?';
  }

  @override
  String queuedSongsForDownload(int count) {
    return 'Queued $count songs for télécharger…';
  }

  @override
  String get songRemovedFromPlaylist => 'Song removed from lirelist';

  @override
  String errorRemovingSong(String error) {
    return 'Impossible de retirer le morceau : $error';
  }

  @override
  String errorReorderingSong(String error) {
    return 'Impossible de réorganiser la file : $error';
  }

  @override
  String get removeSongsTitle => 'Retirer songs';

  @override
  String removePlaylistSongsConfirm(int count, String name) {
    return 'Retirer $count song(s) from \"$name\"?';
  }

  @override
  String removedSongsFromPlaylist(int count) {
    return 'Retirerd $count song(s) from lirelist';
  }

  @override
  String get alreadyInPlaylist => 'Déjà dans la playlist';

  @override
  String alreadyInPlaylistConfirm(String title, String playlist) {
    return '\"$title\" est déjà dans \"$playlist\". Voulez-vous quand même l\'ajouter ?';
  }

  @override
  String get addAnyway => 'Ajouter quand même';

  @override
  String get offlineModeQuestion => 'Passer en mode hors-ligne ?';

  @override
  String get drumroll => 'ROULEMENT DE TAMBOURS…';

  @override
  String get readyToDiscoverTopSong => 'Prêt à découvrir\nvotre titre n°1 ?';

  @override
  String get tapToBegin => 'Touchez pour commencer';

  @override
  String get minutesListened => 'MINUTES D’ÉCOUTE';

  @override
  String get totalHours => 'Heures totales';

  @override
  String get uniqueTracks => 'Titres uniques';

  @override
  String get topSongsHeader => 'TOP TITRES';

  @override
  String get yourMostListenedSongs => 'Vos morceaux les plus écoutés';

  @override
  String get topArtistsHeader => 'TOP ARTISTES';

  @override
  String playsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lires',
      one: '1 lire',
    );
    return '$_temp0';
  }

  @override
  String get topSongBadge => 'Titre n°1';

  @override
  String get topArtistMetric => 'Artiste phare';

  @override
  String get genreMetric => 'Genre';

  @override
  String get muslyPlaybackHeader => 'RÉTROSPECTIVE MUSLY';

  @override
  String get enableMuslyConnect => 'Activer Musly Connect';

  @override
  String get enableMuslyConnectSubtitle =>
      'Détecte les appareils connectés sur le même réseau Wi-Fi pour piloter l’écoute à distance';

  @override
  String get availableDevices => 'Appareils disponibles';

  @override
  String get lanDiscoveryActive =>
      'Recherche locale active • Aucun appareil à proximité';

  @override
  String nearbyDevicesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appareils détectés',
      one: '1 appareil détecté',
    );
    return '$_temp0';
  }

  @override
  String get minutes => 'Minutes';

  @override
  String get nowPlayingHeader => 'EN COURS DE LECTURE';

  @override
  String get privacyFirstTitle => 'Priorité à votre vie privée';

  @override
  String get privacyFirstSubtitle =>
      'Vos données vous appartiennent. Toujours.';

  @override
  String get noDataSellingTitle => 'Aucune vente de données';

  @override
  String get noDataSellingDescription =>
      'Vos données personnelles ne sont jamais vendues, partagées ni transmises à qui que ce soit.';

  @override
  String get localFirstStorageTitle => 'Stockage 100% local';

  @override
  String get localFirstStorageDescription =>
      'Votre bibliothèque musicale, historique et identifiants restent exclusivement sur votre appareil.';

  @override
  String get privateOpenTitle => '100% Privé et Open-Source';

  @override
  String get privateOpenDescription =>
      'Musly ne contient aucun traqueur tiers ni outil de télémétrie publicitaire.';

  @override
  String get readFullPrivacyPolicy => 'Lire la politique de confidentialité';

  @override
  String get viewCompleteDetailsWebsite =>
      'Voir tous les détails sur notre site web';

  @override
  String get understandAndContinue => 'J’ai compris et je continue';

  @override
  String get declineAndExit => 'Refuser et quitter';

  @override
  String get exitApp => 'Quitter l’application';

  @override
  String get stop => 'Arrêter';

  @override
  String get closeQueue => 'Fermer Queue';

  @override
  String get timerOff => 'Désactivé';

  @override
  String get history => 'Historique';

  @override
  String get searchInLibrary => 'Rechercher in Bibliothèque';

  @override
  String get add => 'Ajouter';

  @override
  String get clear => 'Effacer';

  @override
  String get back => 'Retour';

  @override
  String get previousSlide => 'Précédent';

  @override
  String get nextSlide => 'Suivant';

  @override
  String get radios => 'Radios';

  @override
  String get downloads => 'Téléchargements';

  @override
  String get noDownloadedSongsYet => 'No téléchargered songs yet';

  @override
  String get noDownloadedAlbumsYet => 'No téléchargered albums yet';

  @override
  String get connectedToWebStream => 'Connecté au flux Web';

  @override
  String get allowSelfSignedCertificatesSubtitle =>
      'Utile pour un réseau local interne ou un certificat SSL auto-signé';

  @override
  String get legacyAuthenticationSubtitle =>
      'Requis pour les anciennes versions des serveurs Subsonic';

  @override
  String get certificateFileSubtitle => 'Fichier .crt, .pem ou .cer';

  @override
  String get clientIdentityFileSubtitle =>
      'Fichier d’identité client .p12 ou .pfx';

  @override
  String get copyError => 'Copier l\'erreur';

  @override
  String get errorCopiedToClipboard => 'Erreur copiée dans le presse-papiers';

  @override
  String get failedToUpdateFavorite =>
      'Impossible de mettre à jour le statut favori';

  @override
  String queuedSongsFromAlbumsForDownload(int songCount, int albumCount) {
    return 'Queued $songCount songs from $albumCount albums for télécharger…';
  }

  @override
  String get downloadAllAlbums => 'Télécharger All Albums';

  @override
  String get downloadAllFavorites => 'Télécharger All Favoris';

  @override
  String get downloadAll => 'Tout télécharger';

  @override
  String get createPlaylistSubtitle =>
      'Build a custom lirelist with your favorite tracks';

  @override
  String get addMusicSource => 'Ajouter une source musicale';

  @override
  String get addMusicSourceSubtitle =>
      'Connecter Navidrome, Jellyfin ou Web Stream';

  @override
  String get removeFromFavoritesTitle => 'Retirer from Favoris?';

  @override
  String removeFromFavoritesConfirm(String title) {
    return 'Voulez-vous retirer « $title » de vos favoris ?';
  }

  @override
  String failedToRemove(String error) {
    return 'Impossible de retirer : $error';
  }

  @override
  String streamUrlLabel(String url) {
    return 'URL du flux : $url';
  }

  @override
  String get shuffleNewSelection => 'Nouvelle sélection aléatoire';

  @override
  String get sortDurationLongest => 'Durée (les plus longs d’abord)';

  @override
  String get connectToServer => 'Se connecter au serveur';

  @override
  String get renameProfile => 'Renommer le profil';

  @override
  String get addWebStream => 'Ajouter un flux Web';

  @override
  String get addWebStreamSubtitle => 'Diffusion instantanée sans compte requis';

  @override
  String get recentSearches => 'Recent Rechercheres';

  @override
  String get createPlaylistToGetStarted => 'Create a lirelist to get started';

  @override
  String get addRadioStationsHint =>
      'Ajoutez des stations de radio dans les paramètres de votre serveur pour les voir ici.';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingGetStarted => 'Commencer';

  @override
  String get previousSlideTooltip => 'Précédent (Flèche gauche)';

  @override
  String get nextSlideTooltip => 'Suivant (Flèche droite / Espace)';

  @override
  String get onboardingSlide1TitlePrefix => 'Your Music Bibliothèque,\n';

  @override
  String get onboardingSlide1TitleHighlight => 'Dans votre poche.';

  @override
  String get onboardingSlide1Description =>
      'Connect to Navidrome, Subsonic, Jellyfin, or lire local files with bit-perfect lossless quality.';

  @override
  String get onboardingSlide1Feature1Title => 'Liberté auto-hébergée';

  @override
  String get onboardingSlide1Feature1Desc =>
      'Compatibilité totale avec les serveurs Subsonic, Navidrome et Jellyfin.';

  @override
  String get onboardingSlide1Feature2Title => 'Fichiers locaux pris en charge';

  @override
  String get onboardingSlide1Feature2Desc =>
      'Lire your offline collection directly without server setup.';

  @override
  String get onboardingSlide1Feature3Title => 'Son Hi-Res sans perte';

  @override
  String get onboardingSlide1Feature3Desc =>
      'Bit-perfect FLAC, ALAC, Opus, and gapless audio lireback.';

  @override
  String get onboardingSlide2TitlePrefix => 'Mix intelligents,\n';

  @override
  String get onboardingSlide2TitleHighlight => 'Pensés pour vous.';

  @override
  String get onboardingSlide2Description =>
      'Musly analyse vos écoutes sur l’appareil pour composer des sélections quotidiennes sur mesure.';

  @override
  String get onboardingSlide2Feature1Title => 'Profilage musical intelligent';

  @override
  String get onboardingSlide2Feature1Desc =>
      'Learns lire frequencies, skips, and ratings with recency decay.';

  @override
  String get onboardingSlide2Feature2Title => 'Mix quotidiens personnalisés';

  @override
  String get onboardingSlide2Feature2Desc =>
      'Automatic Made For You, Listen Again, and Top Hits lirelists.';

  @override
  String get onboardingSlide2Feature3Title => '100% calculé sur votre appareil';

  @override
  String get onboardingSlide2Feature3Desc =>
      'Votre profil d’écoute reste strictement sur votre téléphone, en toute confidentialité.';

  @override
  String get onboardingSlide3TitlePrefix => 'Vie privée respectée.\n';

  @override
  String get onboardingSlide3TitleHighlight => 'Zéro pub, zéro pistage.';

  @override
  String get onboardingSlide3Description =>
      'Zero analytics, zero telemetry. Enjoy time-synced lyrics, offline téléchargers, and desktop sync in total privacy.';

  @override
  String get onboardingSlide3Feature1Title => 'Zéro télémétrie ni traceur';

  @override
  String get onboardingSlide3Feature1Desc =>
      'Aucun SDK publicitaire, code source ouvert et vérifiable.';

  @override
  String get onboardingSlide3Feature2Title => 'Paroles synchronisées';

  @override
  String get onboardingSlide3Feature2Desc =>
      'Affichage karaoké en temps réel avec secours automatique via LRCLIB.';

  @override
  String get onboardingSlide3Feature3Title => 'Offline Télécharger Manager';

  @override
  String get onboardingSlide3Feature3Desc =>
      'Cache full lirelists and albums with batch téléchargering.';

  @override
  String get finishTour => 'Terminer la visite';

  @override
  String get skip => 'Passer';

  @override
  String get profileNameOptional => 'Nom du profil (facultatif)';

  @override
  String get serverUrlRequired => 'URL du serveur *';

  @override
  String get lanServerUrlOptional => 'URL locale LAN (facultatif)';

  @override
  String get usernameRequired => 'Nom d’utilisateur *';

  @override
  String get passwordRequired => 'Mot de passe *';

  @override
  String get playingInSync => 'Lireing in sync';

  @override
  String get switchedBackToThisDevice => 'Lecture basculée sur cet appareil';

  @override
  String connectedToDeviceName(String device) {
    return 'Connecté à $device';
  }

  @override
  String get whatDoYouWantToPlay => 'What do you want to lire?';

  @override
  String get noLyricsFound => 'Aucune parole trouvée';

  @override
  String get dynamicColor => 'Couleurs dynamiques (Monet)';

  @override
  String get muslyPlayback => 'Musly Lireback';

  @override
  String get synthesizingUniverse => 'Création de votre univers musical…';

  @override
  String get getReadyForBeatDrop => 'Préparez-vous à monter le son…';

  @override
  String yourYearInSound(int year) {
    return 'Votre année $year\nen musique';
  }

  @override
  String get yourYearInSoundSubtitle =>
      'Vous avez exploré de nouveaux horizons, vibré et créé des souvenirs en musique.';

  @override
  String get yourMusicalChronotype => 'VOTRE CHRONOTYPE MUSICAL';

  @override
  String get genreGalaxy => 'GALAXIE DES GENRES';

  @override
  String get soundsThatGuidedYou => 'Les styles qui ont guidé votre année';

  @override
  String get yourMusicalAnchors => 'Vos piliers musicaux';

  @override
  String get yourListeningPersonality => 'VOTRE PERSONNALITÉ MUSICALE';

  @override
  String get yourYearInReviewIsReady =>
      'Votre rétrospective musicale est prête !';

  @override
  String get chronotypeMidnightWanderer => 'Midnight Wanderer 🌙';

  @override
  String get chronotypeMidnightWandererDesc =>
      'Your deepest music moments unfold late at night when the world is quiet.';

  @override
  String get chronotypeSunriseHarmonizer => 'Sunrise Harmonizer ☀️';

  @override
  String get chronotypeSunriseHarmonizerDesc =>
      'You kickstart every morning with rhythm, setting the soundtrack for the entire day.';

  @override
  String get chronotypeAfternoonFlow => 'Afternoon Flow ⚡';

  @override
  String get chronotypeAfternoonFlowDesc =>
      'Midday is your prime listening peak, powering through your momentum with high-energy sound.';

  @override
  String get chronotypeTwilightLounger => 'Twilight Lounger 🌆';

  @override
  String get chronotypeTwilightLoungerDesc =>
      'Evenings are made for unwinding and losing yourself in immersive album journeys.';

  @override
  String get archetypeLuminary => 'Le Visionnaire';

  @override
  String get archetypeLuminaryBadge => 'EXPLORATEUR SONORE';

  @override
  String get archetypeLuminaryDesc =>
      'Vous explorez des genres variés et cherchez constamment de nouveaux horizons musicaux.';

  @override
  String get archetypeLuminaryTrait1 => 'Goût éclectique';

  @override
  String get archetypeLuminaryTrait2 => 'Fluide entre les genres';

  @override
  String get archetypeLuminaryTrait3 => 'Grande soif de découverte';

  @override
  String get archetypeDevotee => 'Le Dévoué';

  @override
  String get archetypeDevoteeBadge => 'SUPERFAN';

  @override
  String get archetypeDevoteeDesc =>
      'Quand vous aimez un artiste ou un album, vous l\'écoutez en boucle avec une passion sans égale.';

  @override
  String get archetypeDevoteeTrait1 => 'Fidélité absolue';

  @override
  String get archetypeDevoteeTrait2 => 'Écoute d\'albums entiers';

  @override
  String get archetypeDevoteeTrait3 => 'Lien émotionnel fort';

  @override
  String get archetypeNightOwl => 'Le Noctambule';

  @override
  String get archetypeNightOwlBadge => 'ONDES NOCTURNES';

  @override
  String get archetypeNightOwlDesc =>
      'Votre âme s\'épanouit dans les atmosphères de minuit, les accords feutrés et les sessions sous les étoiles.';

  @override
  String get archetypeNightOwlTrait1 => 'Atmosphérique';

  @override
  String get archetypeNightOwlTrait2 => 'Introspectif';

  @override
  String get archetypeNightOwlTrait3 => 'Rythme de nuit';

  @override
  String get archetypeSunrise => 'L\'Harmoniseur d\'Aurore';

  @override
  String get archetypeSunriseBadge => 'CATALYSEUR D\'ÉNERGIE';

  @override
  String get archetypeSunriseDesc =>
      'Vous illuminez le monde avec des ondes positives et laissez les mélodies dynamiques porter votre journée.';

  @override
  String get archetypeSunriseTrait1 => 'Énergisant';

  @override
  String get archetypeSunriseTrait2 => 'Énergie matinale';

  @override
  String get archetypeSunriseTrait3 => 'Élan rythmique';

  @override
  String get archetypeAlchemist => 'L\'Alchimiste Sonore';

  @override
  String get archetypeAlchemistBadge => 'CRÉATEUR D\'AMBIANCE';

  @override
  String get archetypeAlchemistDesc =>
      'Vous transformez les moments du quotidien en expériences cinématographiques grâce à des bandes-son parfaites.';

  @override
  String get archetypeAlchemistTrait1 => 'Instinct de curateur';

  @override
  String get archetypeAlchemistTrait2 => 'Ambiance cinématographique';

  @override
  String get archetypeAlchemistTrait3 => 'Maître des ambiances';

  @override
  String get percentileTop05 => 'Top 0.5% Global Listener';

  @override
  String get percentileTop1 => 'Top 1% Global Listener';

  @override
  String get percentileTop5 => 'Top 5% Global Listener';

  @override
  String get percentileTop10 => 'Top 10% Global Listener';

  @override
  String get percentileTopAficionado => 'Top Music Aficionado';

  @override
  String get superfanBadge01 => 'Top 0.1% Superfan';

  @override
  String get superfanBadge1 => 'Top 1% Fan';

  @override
  String get superfanBadge5 => 'Top 5% Fan';

  @override
  String get tabAndroidAuto => 'Android Auto';

  @override
  String get androidAutoNotSupported =>
      'Android Auto n\'est pas pris en charge sur cet appareil.';

  @override
  String get androidAutoCategories => 'Catégories';

  @override
  String get androidAutoPerformance => 'Performances';

  @override
  String get androidAutoShowRecent => 'Afficher les récents';

  @override
  String get androidAutoShowFavorites => 'Afficher les favoris';

  @override
  String get androidAutoShowAlbums => 'Afficher les albums';

  @override
  String get androidAutoShowArtists => 'Afficher les artistes';

  @override
  String get androidAutoShowPlaylists => 'Afficher les playlists';

  @override
  String get androidAutoShowGenres => 'Afficher les genres';

  @override
  String get androidAutoShowRadio => 'Afficher la radio';

  @override
  String get androidAutoShowDownloads => 'Afficher les téléchargements';

  @override
  String get androidAutoMaxItems => 'Limite d\'éléments';

  @override
  String get androidAutoMaxItemsDesc =>
      'Nombre maximal d\'éléments à charger par catégorie';

  @override
  String get androidAutoNowPlaying => 'Lecture en cours';

  @override
  String get androidAutoRecent => 'Récents';

  @override
  String get androidAutoFavorites => 'Favoris';

  @override
  String get androidAutoAlbums => 'Albums';

  @override
  String get androidAutoArtists => 'Artistes';

  @override
  String get androidAutoPlaylists => 'Playlists';

  @override
  String get androidAutoGenres => 'Genres';

  @override
  String get androidAutoRadio => 'Radio';

  @override
  String get androidAutoDownloads => 'Téléchargements';

  @override
  String get androidAutoShuffle => 'Lecture aléatoire';

  @override
  String get androidAutoQueue => 'File d\'attente';

  @override
  String get androidAutoEmptyFavorites => 'Aucun morceau favori';

  @override
  String get androidAutoEmptyRadio => 'Aucune station de radio configurée';

  @override
  String get androidAutoEmptyDownloads => 'Aucun morceau téléchargé';

  @override
  String get androidAutoLoading => 'Chargement…';

  @override
  String get androidAutoOnlineStream => 'Flux en ligne';

  @override
  String get androidAutoServerSection => 'Serveur';

  @override
  String get androidAutoDefaultServer => 'Serveur par défaut';

  @override
  String get androidAutoDefaultServerDesc =>
      'Sélectionnez le serveur à utiliser au démarrage d\'Android Auto';

  @override
  String get androidAutoUseActiveServer =>
      'Utiliser le serveur actif de l\'application';

  @override
  String get desktopOverlaySection => 'Overlay Bureau';

  @override
  String get spotverlayTitle => 'Spotverlay';

  @override
  String get spotverlayDescription =>
      'Si vous souhaitez un overlay élégant et léger \"Made for Musly\", vous pouvez utiliser Spotverlay (https://github.com/dddevid/Spotverlay)';
}
