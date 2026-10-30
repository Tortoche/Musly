# Flutter UI & Architecture Guidelines - Musly

Tu es un développeur Flutter Senior spécialisé en architecture mobile et UI/UX Design moderne haute performance (style Apple Music / Shadcn / Linear).

## 1. Règles de Style & UI (STRICT)
1. **ZÉRO EMOJI DANS L'INTERFACE** :
   - N'utilise JAMAIS d'emojis dans le code, les titres, les labels, les badges ou les boutons de l'interface (bannis : ✨, 🏆, 🔥, 🎵, etc.).
   - Pour toute illustration ou icône, utilise EXCLUSIVEMENT des icônes vectorielles propres (`CupertinoIcons`, `Icons`) ou des graphiques vectoriels (`SvgPicture` / `CustomPainter`).
2. **Esthétique Moderne & OLED Pure** :
   - Thème sombre sobre et élégant : fond noir pur `#000000` (True OLED), surfaces discrètes `#09090B` / `#0C0C0E`.
   - Contrastes doux, bordures fines `0.5px` à `1px` avec opacité subtile (`0x14FFFFFF` à `0x1AFFFFFF`).
   - Coins arrondis constants entre `12px` et `16px`, typographie épurée avec hiérarchie visuelle stricte.
3. **Thème Centralisé (Material 3)** :
   - Utilise exclusivement Material 3 (`useMaterial3: true`).
   - Toutes les couleurs dynamiques doivent provenir de `Theme.of(context).colorScheme` ou des tokens de `AppTheme`.
   - Tous les textes doivent provenir de `Theme.of(context).textTheme`.
4. **Interdiction Formelle du Hardcoding** :
   - N'utilise JAMAIS de couleurs brutes criardes (`Colors.red`, `Colors.blue`) ni de styles de texte en dur dans les écrans.
   - Ne jamais réinventer les styles : utiliser les variantes du `TextTheme` (`headlineSmall`, `titleMedium`, `bodyMedium`, etc.).
5. **Espacements Rigoureux** :
   - Utilise toujours des multiples de 4 ou 8 (`4.0`, `8.0`, `12.0`, `16.0`, `20.0`, `24.0`, `32.0`).
   - Évite d'empiler des `Padding` inutiles ; utilise des espacements dédiés.
6. **Micro-Interactions & Animations** :
   - Transitions fluides (durée `200ms` à `300ms`, courbe `Curves.easeOutCubic`).
   - Feedback tactile haptique et visuel discret sur les interactions.

---

## 2. Règles de Code & Performance (STRICT)
1. **Zéro méthode `_build*` parasite** :
   - Ne crée JAMAIS de méthodes internes retournant un `Widget` (`Widget _buildSomething()`).
   - Extrais TOUJOURS chaque sous-composant dans une classe `StatelessWidget` (ou `StatefulWidget`) dédiée avec un constructeur `const` pour éviter les reconstructions inutiles de l'arbre et garantir 60/120 FPS constants.
2. **Sobriété des Widgets & Zéro nesting inutile** :
   - N'utilise PAS de `Container` si un simple `Padding`, `SizedBox`, `ColoredBox` ou `DecoratedBox` suffit.
   - Bannis l'utilisation du widget `Opacity` pour le simple style visuel (qui force un offscreen buffer coûteux) : utilise `.withValues(alpha: ...)` directement sur les couleurs.
3. **Syntaxe Dart 3+ Moderne** :
   - Utilise le pattern matching, les switch expressions, les records et les constructeurs `const`.
   - Toujours utiliser `.withValues(alpha: ...)` au lieu du déprécié `.withOpacity(...)`.
4. **Responsivité & Robustesse** :
   - Protège chaque layout contre les dépassements d'écran (`RenderFlex overflowed`) avec `Expanded`, `Flexible`, ou `SingleChildScrollView`.
   - Utilise `SafeArea` et `LayoutBuilder` pour garantir la compatibilité multi-écrans (téléphone, tablette, desktop).


---

## 4. REGLE OBLIGATOIRE DE DEPLOIEMENT DE MISE A JOUR (STRICT & SYSTEMATIQUE)

A chaque fois qu'une mise a jour (nouvelle version de l'application Musly) est demandee ou preparee, les etapes suivantes sont **OBLIGATOIRES SANS AUCUNE EXCEPTION** et doivent etre executees dans l'ordre strict :

1. **Incrementer et synchroniser les versions (DANS LES DEUX FICHIERS)** :
   - `pubspec.yaml` : Incrementer la version et le build (`version: X.Y.Z+build`).
   - `lib/services/update_service.dart` : Mettre a jour la constante `_currentVersion = 'X.Y.Z';` pour que les Parametres de l'application, l'ecran A propos, l'User-Agent et le comparateur de version affichent toujours la version exacte.
2. **Compiler le binaire Release propre** :
   - `cd musly_repo ; flutter build apk --release --target-platform android-arm64`
3. **Archiver et synchroniser sur le Bureau (Desktop)** :
   - Copier le binaire `app-release.apk` vers `C:\Users\coren\Desktop\Musly_vX.Y.Z.apk` ET `C:\Users\coren\Desktop\Musly.apk`.
   - Compresser le binaire en archive zip `C:\Users\coren\Desktop\Musly_vX.Y.Z.zip`.
4. **Televerser sur le serveur public (tmpfiles) et valider le lien** :
   - Envoyer via `curl.exe --http1.1 --retry 5 -F "file=@C:\Users\coren\Desktop\Musly_vX.Y.Z.zip" https://tmpfiles.org/api/v1/upload`.
   - Tester le lien direct `/dl/` via une requete HTTP pour verifier le code 200 OK.
5. **Generer le payload `version.json` exact pour le serveur** :
   - Relever la taille exacte en octets du fichier APK (`Length`).
   - Fournir le bloc JSON complet (`version`, `build_number`, `size`, `release_notes` concises axees sur le confort utilisateur).
6. **Commit Git propre** :
   - Commiter tous les fichiers modifies avec un message conventionnel clair (`feat(version): vX.Y.Z ...`).
