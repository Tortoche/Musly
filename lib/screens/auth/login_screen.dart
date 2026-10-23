import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'package:musly/models/server_config.dart';
import 'package:musly/providers/auth_provider.dart';
import 'package:musly/services/local_music_service.dart';
import 'package:musly/services/storage_service.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/utils/screen_helper.dart';
import 'package:musly/services/tv_detection_service.dart';
import 'package:musly/widgets/navigation/tv_remote_scope.dart';

enum _LoginErrorType {
  ssl,
  credentials,
  notFound,
  timeout,
  connection,
  format,
  generic,
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController(text: 'https://music.corentinjanin.fr');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _scrollController = ScrollController();

  bool _useLegacyAuth = false;
  bool _allowSelfSignedCertificates = false;
  bool _obscurePassword = true;
  bool _showAdvancedOptions = false;
  String _serverFamily = 'subsonic';
  String? _customCertificatePath;
  String? _customCertificateName;
  final _profileNameController = TextEditingController();

  String? _clientCertificatePath;
  String? _clientCertificateName;
  final _clientCertPasswordController = TextEditingController();
  bool _obscureClientCertPassword = true;
  bool _isScanning = false;
  double _scanProgress = 0.0;
  String _scanStatus = '';

  String? _loginError;

  @override
  void initState() {
    super.initState();

    _serverController.addListener(_clearError);
    _usernameController.addListener(_clearError);
    _passwordController.addListener(_clearError);
    _profileNameController.addListener(_clearError);

    if (_serverController.text.trim().isEmpty) {
      _serverController.text = 'https://music.corentinjanin.fr';
    }
    _serverFocusNode.addListener(_onTvFocusChange);
    _usernameFocusNode.addListener(_onTvFocusChange);
    _passwordFocusNode.addListener(_onTvFocusChange);

    _loadSavedServerFamily();
  }

  void _onTvFocusChange() {
    if (!mounted) return;

    final isTv =
        Provider.of<TvDetectionService>(context, listen: false).isTvMode;
    if (isTv) {
      // Rebuild to apply the extra bottom padding
      setState(() {});

      // A small delay lets the TV keyboard animation start, and then we force scroll
      // the focused field to the top 20% of the screen so it's not covered by the keyboard overlay.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        if (_serverFocusNode.hasFocus) {
          Scrollable.ensureVisible(_serverFocusNode.context!,
              alignment: 0.15, duration: const Duration(milliseconds: 300));
        } else if (_usernameFocusNode.hasFocus) {
          Scrollable.ensureVisible(_usernameFocusNode.context!,
              alignment: 0.15, duration: const Duration(milliseconds: 300));
        } else if (_passwordFocusNode.hasFocus) {
          Scrollable.ensureVisible(_passwordFocusNode.context!,
              alignment: 0.15, duration: const Duration(milliseconds: 300));
        }
      });
    }
  }

  Future<void> _loadSavedServerFamily() async {
    final family = await StorageService().getLastSelectedFamily();
    if (family != null && family.isNotEmpty && mounted) {
      setState(() {
        _serverFamily = family;
      });
    }
  }

  void _clearError() {
    if (_loginError != null && mounted) {
      setState(() => _loginError = null);
    }
  }

  _LoginErrorType _categoriseError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('ssl') ||
        lower.contains('certificate') ||
        lower.contains('handshake') ||
        lower.contains('tls')) {
      return _LoginErrorType.ssl;
    }
    if (lower.contains('invalid username') ||
        lower.contains('wrong password') ||
        lower.contains('unauthorized') ||
        lower.contains('401')) {
      return _LoginErrorType.credentials;
    }
    if (lower.contains('not found') ||
        lower.contains('404') ||
        lower.contains('url path')) {
      return _LoginErrorType.notFound;
    }
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return _LoginErrorType.timeout;
    }
    if (lower.contains('cannot connect') ||
        lower.contains('connection refused') ||
        lower.contains('network') ||
        lower.contains('socket')) {
      return _LoginErrorType.connection;
    }
    if (lower.contains('url format') || lower.contains('http')) {
      return _LoginErrorType.format;
    }
    return _LoginErrorType.generic;
  }

  Widget _buildErrorCard(ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final error = _loginError ??
        (authProvider.state == AuthState.error ? authProvider.error : null);
    if (error == null || error.isEmpty) return const SizedBox.shrink();

    final type = _categoriseError(error);

    IconData icon;
    Color color;
    String? hint;

    switch (type) {
      case _LoginErrorType.ssl:
        icon = CupertinoIcons.lock_slash;
        color = const Color(0xFFFF9500);
        if (!_allowSelfSignedCertificates) {
          hint = 'Activez "Autoriser les certificats auto-signés" ci-dessous.';
        }
      case _LoginErrorType.credentials:
        icon = CupertinoIcons.person_badge_minus;
        color = AppTheme.brandRed;
        hint = 'Vérifiez votre nom d\'utilisateur et votre mot de passe puis réessayez.';
      case _LoginErrorType.notFound:
        icon = CupertinoIcons.question_circle;
        color = const Color(0xFFFF9500);
        hint = 'Vérifiez le chemin d\'URL du serveur (ex. /navidrome, /airsonic).';
      case _LoginErrorType.timeout:
        icon = CupertinoIcons.timer;
        color = const Color(0xFFFF9500);
        hint = 'Le serveur a mis trop de temps à répondre. Vérifiez votre connexion.';
      case _LoginErrorType.connection:
        icon = CupertinoIcons.wifi_slash;
        color = const Color(0xFFFF9500);
        hint = null;
      case _LoginErrorType.format:
        icon = CupertinoIcons.link;
        color = const Color(0xFFFF9500);
        hint = 'L\'URL doit commencer par http:// ou https://';
      case _LoginErrorType.generic:
        icon = CupertinoIcons.exclamationmark_triangle;
        color = AppTheme.brandRed;
        hint = null;
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    error,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy_rounded,
                      size: 16, color: color.withValues(alpha: 0.7)),
                  tooltip:
                      AppLocalizations.of(context)?.copyError ?? 'Copy error',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: error));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)
                                  ?.errorCopiedToClipboard ??
                              'Erreur copiée dans le presse-papier',
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        width: 260,
                      ),
                    );
                  },
                ),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(
                  hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
            if (type == _LoginErrorType.ssl &&
                !_allowSelfSignedCertificates) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _allowSelfSignedCertificates = true;
                      _loginError = null;
                    });
                  },
                  child: Text(
                    Platform.isIOS || Platform.isAndroid
                        ? 'Appuyez pour activer les certificats auto-signés'
                        : 'Cliquez pour activer les certificats auto-signés',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: color,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _serverController.removeListener(_clearError);
    _usernameController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _profileNameController.removeListener(_clearError);
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _profileNameController.dispose();
    _clientCertPasswordController.dispose();
    _serverFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool _isRemoteInsecureHttp(String url) {
    final trimmed = url.trim().toLowerCase();
    if (!trimmed.startsWith('http://')) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host.endsWith('.local') ||
        host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        RegExp(r'^172\.(1[6-9]|2[0-9]|3[0-1])\.').hasMatch(host)) {
      return false;
    }
    return true;
  }

  Future<void> _pickClientCertificate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['p12', 'pfx', 'pem'],
        dialogTitle: 'Sélectionner le certificat client',
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _clientCertificatePath = result.files.single.path;
          _clientCertificateName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!
                  .failedToSelectClientCert(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickCertificateFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pem', 'crt', 'cer', 'p12', 'pfx', 'der'],
        dialogTitle: 'Sélectionner le certificat TLS/SSL',
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _customCertificatePath = result.files.single.path;
          _customCertificateName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!
                  .failedToSelectCertificate(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _login() async {
    if (_serverFamily != 'youtube') {
      if (!_formKey.currentState!.validate()) return;
    }

    setState(() => _loginError = null);

    final serverUrl = _serverFamily == 'youtube'
        ? 'https://music.youtube.com'
        : _serverController.text.trim();

    if (_serverFamily != 'youtube' &&
        !serverUrl.startsWith('http://') &&
        !serverUrl.startsWith('https://')) {
      setState(
        () => _loginError = 'L\'URL du serveur doit commencer par http:// ou https://',
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileName = _profileNameController.text.trim();
    final success = await authProvider.login(
      serverUrl: serverUrl,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      useLegacyAuth: _useLegacyAuth,
      allowSelfSignedCertificates: _allowSelfSignedCertificates,
      customCertificatePath: _customCertificatePath,
      clientCertificatePath: _clientCertificatePath,
      clientCertificatePassword: _clientCertPasswordController.text.isEmpty
          ? null
          : _clientCertPasswordController.text,
      profileName: profileName.isEmpty ? null : profileName,
      serverFamily: _serverFamily,
    );

    if (!success && mounted) {
      setState(
        () => _loginError = authProvider.error ?? 'Échec de connexion au serveur',
      );
    }
  }

  Future<void> _useLocalFiles() async {
    final localService = Provider.of<LocalMusicService>(context, listen: false);

    final granted = await localService.requestPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.storagePermissionRequired,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (Platform.isIOS) {
      setState(() {
        _isScanning = true;
        _scanProgress = 0.0;
        _scanStatus = 'Sélectionnez vos fichiers audio...';
      });
      try {
        final added = await localService.pickAndAddFiles();
        if (mounted) {
          if (localService.songs.isNotEmpty) {
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            await authProvider.setLocalOnlyMode(true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(added == 0
                    ? 'Aucun fichier sélectionné. Choisissez vos fichiers musicaux.'
                    : AppLocalizations.of(context)!.noMusicFilesFound),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } finally {
        if (mounted) setState(() => _isScanning = false);
      }
      return;
    }

    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
      _scanStatus = 'Démarrage de l\'analyse...';
    });

    void updateProgress() {
      if (mounted) {
        setState(() {
          _scanProgress = localService.scanProgress;
          _scanStatus = localService.scanStatus;
        });
      }
    }

    localService.addListener(updateProgress);

    try {
      await localService.scanForMusic();

      if (mounted) {
        if (localService.songs.isNotEmpty) {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          await authProvider.setLocalOnlyMode(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.noMusicFilesFound),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } finally {
      localService.removeListener(updateProgress);
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoading = authProvider.state == AuthState.authenticating;
    final theme = Theme.of(context);
    final isBusy = isLoading || _isScanning;

    final isTv = Provider.of<TvDetectionService>(context).isTvMode;
    final bool anyFieldFocused = _serverFocusNode.hasFocus ||
        _usernameFocusNode.hasFocus ||
        _passwordFocusNode.hasFocus;

    // Add extra padding at the bottom when a field is focused on TV so there's enough room to scroll it up
    final bottomPadding =
        (isTv && anyFieldFocused) ? 400.0 : ScreenHelper.loginPadding(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              ScreenHelper.loginPadding(context),
              ScreenHelper.loginPadding(context),
              ScreenHelper.loginPadding(context),
              bottomPadding,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isTv ? 600 : 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Center(
                        child: Container(
                          width: ScreenHelper.loginLogoSize(context),
                          height: ScreenHelper.loginLogoSize(context),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Transform.translate(
                              offset: const Offset(0, 8),
                              child: Image.asset(
                                'assets/logobig.png',
                                width: ScreenHelper.loginLogoSize(context),
                                height: ScreenHelper.loginLogoSize(context),
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        AppLocalizations.of(context)!.appName,
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontSize:
                              ScreenHelper.isSmallScreen(context) ? 32 : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.connectToServerSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.lightSecondaryText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _SavedProfilesSwitcher(
                        onProfileSelected: (profile) async {
                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          await authProvider.switchProfile(profile);
                          if (mounted && authProvider.error != null) {
                            setState(
                              () => _loginError = authProvider.error,
                            );
                          }
                        },
                        onProfileDeleted: (profile) async {
                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          await authProvider.deleteProfile(profile);
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      _ServerFamilyToggle(
                        serverFamily: _serverFamily,
                        onChanged: (v) {
                          setState(() {
                            _serverFamily = v;
                            _useLegacyAuth = false;
                          });
                          StorageService().saveLastSelectedFamily(v);
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_serverFamily == 'local') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF34C759).withValues(alpha: 0.08),
                            border: Border.all(
                              color: const Color(0xFF34C759)
                                  .withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.folder_badge_plus,
                                    color: Color(0xFF34C759),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Écoutez vos fichiers audio stockés localement sur cet appareil sans aucun serveur.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? Colors.white70
                                                : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: isBusy ? null : _useLocalFiles,
                                  icon: _isScanning
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Icon(CupertinoIcons.folder_open),
                                  label: Text(
                                    _isScanning
                                        ? _scanStatus
                                        : 'Analyser et écouter les fichiers locaux',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF34C759),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              if (_isScanning) ...[
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value:
                                      _scanProgress > 0 ? _scanProgress : null,
                                  backgroundColor: const Color(0xFF34C759)
                                      .withValues(alpha: 0.2),
                                  color: const Color(0xFF34C759),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else if (_serverFamily == 'youtube') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000).withAlpha(20),
                            border: Border.all(
                              color: const Color(0xFFFF0000).withAlpha(80),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.info_circle,
                                color: Color(0xFFFF0000),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Le streaming Web diffuse la musique directement en ligne. Aucun compte requis — appuyez sur Connexion.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _serverController,
                          focusNode: _serverFocusNode,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _usernameFocusNode.requestFocus(),
                          decoration: InputDecoration(
                            labelText:
                                AppLocalizations.of(context)?.serverUrl ??
                                    'URL du serveur',
                            hintText: _serverFamily == 'jellyfin'
                                ? 'https://jellyfin.example.com'
                                : 'https://your-server.com',
                            prefixIcon: const Icon(CupertinoIcons.globe),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return AppLocalizations.of(context)?.pleaseEnterServerUrl ?? 'Veuillez entrer l\'URL du serveur';
                            }
                            final url = value.trim();
                            if (!url.startsWith('http://') &&
                                !url.startsWith('https://')) {
                              return AppLocalizations.of(context)?.serverUrlMustStartWith ?? 'L\'URL doit commencer par http:// ou https://';
                            }
                            return null;
                          },
                        ),
                        if (_isRemoteInsecureHttp(_serverController.text)) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                    CupertinoIcons.exclamationmark_shield_fill,
                                    size: 16,
                                    color: Colors.amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'HTTP non sécurisé : les mots de passe et flux ne sont pas chiffrés sur le réseau. HTTPS recommandé.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.amber[200]
                                          : Colors.amber[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _usernameController,
                          focusNode: _usernameFocusNode,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _passwordFocusNode.requestFocus(),
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)?.username ??
                                'Username',
                            prefixIcon: const Icon(CupertinoIcons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return AppLocalizations.of(context)?.pleaseEnterUsername ?? 'Veuillez entrer le nom d\'utilisateur';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!isBusy) _login();
                          },
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)?.password ??
                                'Password',
                            prefixIcon: const Icon(CupertinoIcons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? CupertinoIcons.eye
                                    : CupertinoIcons.eye_slash,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(context)?.pleaseEnterPassword ?? 'Veuillez saisir votre mot de passe';
                            }
                            return null;
                          },
                        ),
                      ],
                      if (_serverFamily == 'subsonic') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            CupertinoSwitch(
                              value: _useLegacyAuth,
                              activeTrackColor: theme.colorScheme.primary,
                              onChanged: (value) {
                                setState(() {
                                  _useLegacyAuth = value;
                                });
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Authentification héritée (Legacy)',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  Text(
                                    'Pour les anciennes versions de Subsonic',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_serverFamily == 'subsonic' ||
                          _serverFamily == 'jellyfin') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            CupertinoSwitch(
                              value: _allowSelfSignedCertificates,
                              activeTrackColor: theme.colorScheme.primary,
                              onChanged: (value) {
                                setState(() {
                                  _allowSelfSignedCertificates = value;
                                });
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Autoriser les certificats auto-signés',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  Text(
                                    'Pour les serveurs avec certificats auto-signés',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showAdvancedOptions = !_showAdvancedOptions;
                            });
                          },
                          child: Row(
                            children: [
                              Icon(
                                _showAdvancedOptions
                                    ? CupertinoIcons.chevron_down
                                    : CupertinoIcons.chevron_right,
                                size: 18,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Options avancées',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_showAdvancedOptions) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _profileNameController,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)
                                      ?.profileNameOptional ??
                                  'Nom du profil (optionnel)',
                              hintText: 'e.g. Home, Work, VPN',
                              prefixIcon: const Icon(CupertinoIcons.tag),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Certificat TLS/SSL personnalisé',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Importer un certificat pour les serveurs avec autorité personnalisée',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                if (_customCertificateName != null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.brightness == Brightness.dark
                                          ? const Color(0xFF3C3C3E)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          CupertinoIcons.doc_fill,
                                          size: 20,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _customCertificateName!,
                                            style: theme.textTheme.bodyMedium,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            CupertinoIcons.xmark_circle_fill,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _customCertificatePath = null;
                                              _customCertificateName = null;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _pickCertificateFile,
                                      icon: const Icon(
                                          CupertinoIcons.doc_on_clipboard),
                                      label: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!
                                            .selectCertificate,
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            theme.colorScheme.primary,
                                        side: BorderSide(
                                          color: theme.colorScheme.primary
                                              .withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Certificat client (mTLS)',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PKCS#12 (.p12/.pfx) client certificate for mutual TLS authentication',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                if (_clientCertificateName != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.brightness == Brightness.dark
                                          ? const Color(0xFF3C3C3E)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          CupertinoIcons.lock_shield_fill,
                                          size: 20,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _clientCertificateName!,
                                            style: theme.textTheme.bodyMedium,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            CupertinoIcons.xmark_circle_fill,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _clientCertificatePath = null;
                                              _clientCertificateName = null;
                                              _clientCertPasswordController
                                                  .clear();
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _clientCertPasswordController,
                                    obscureText: _obscureClientCertPassword,
                                    decoration: InputDecoration(
                                      labelText: AppLocalizations.of(context)
                                              ?.clientCertPassword ??
                                          'Mot de passe du certificat',
                                      hintText:
                                          'Mot de passe du fichier .p12 / .pfx (optionnel)',
                                      prefixIcon: const Icon(
                                          CupertinoIcons.lock_shield),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureClientCertPassword
                                              ? CupertinoIcons.eye
                                              : CupertinoIcons.eye_slash,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscureClientCertPassword =
                                                !_obscureClientCertPassword;
                                          });
                                        },
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ] else
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _pickClientCertificate,
                                      icon: const Icon(Icons.security_rounded),
                                      label: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!
                                            .selectClientCertificate,
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            theme.colorScheme.primary,
                                        side: BorderSide(
                                          color: theme.colorScheme.primary
                                              .withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      if (_serverFamily != 'local') ...[
                        const SizedBox(height: 24),
                        _buildErrorCard(theme),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: TvFocusableCard(
                            onTap: isLoading ? null : _login,
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isLoading
                                    ? theme.colorScheme.primary
                                        .withValues(alpha: 0.5)
                                    : theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      AppLocalizations.of(context)?.connect ?? 'Connexion',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: ThemeData
                                                    .estimateBrightnessForColor(
                                                        theme.colorScheme
                                                            .primary) ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedProfilesSwitcher extends StatefulWidget {
  final Future<void> Function(ServerConfig) onProfileSelected;
  final Future<void> Function(ServerConfig) onProfileDeleted;

  const _SavedProfilesSwitcher({
    required this.onProfileSelected,
    required this.onProfileDeleted,
  });

  @override
  State<_SavedProfilesSwitcher> createState() => _SavedProfilesSwitcherState();
}

class _SavedProfilesSwitcherState extends State<_SavedProfilesSwitcher> {
  Future<List<ServerConfig>>? _profilesFuture;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _reload();
    }
  }

  void _reload() {
    _profilesFuture = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).getSavedProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServerConfig>>(
      future: _profilesFuture,
      builder: (context, snap) {
        final profiles = snap.data ?? [];
        if (profiles.isEmpty) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profils enregistrés',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profiles.map((profile) {
                final label = profile.name?.isNotEmpty == true
                    ? profile.name!
                    : '${profile.username}@${Uri.tryParse(profile.serverUrl)?.host ?? profile.serverUrl}';
                return InputChip(
                  avatar: const Icon(
                    CupertinoIcons.person_crop_circle,
                    size: 18,
                  ),
                  label: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  tooltip: '${profile.username} – ${profile.serverUrl}',
                  onPressed: () async {
                    await widget.onProfileSelected(profile);
                    if (mounted) setState(_reload);
                  },
                  onDeleted: () async {
                    await widget.onProfileDeleted(profile);
                    if (mounted) setState(_reload);
                  },
                  deleteIcon: const Icon(CupertinoIcons.xmark_circle, size: 16),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            Text(
              'Touchez un profil pour vous connecter • × pour supprimer',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ServerFamilyToggle extends StatelessWidget {
  final String serverFamily;
  final ValueChanged<String> onChanged;

  const _ServerFamilyToggle({
    required this.serverFamily,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white70 : Colors.black87;

    final isTv =
        Provider.of<TvDetectionService>(context, listen: false).isTvMode;
    final chips = [
      (
        label: 'Subsonic',
        family: 'subsonic',
        icon: CupertinoIcons.music_note_2,
        activeColor: const Color(0xFF6366F1),
      ),
      (
        label: 'Jellyfin',
        family: 'jellyfin',
        icon: CupertinoIcons.tv_fill,
        activeColor: const Color(0xFF00A4DC),
      ),
      if (!kIsWeb && !Platform.isIOS && !isTv)
        (
          label: 'Streaming Web',
          family: 'youtube',
          icon: CupertinoIcons.play_rectangle_fill,
          activeColor: const Color(0xFFFF3B30),
        ),
      if (!isTv)
        (
          label: 'Fichiers Locaux',
          family: 'local',
          icon: CupertinoIcons.folder_fill,
          activeColor: const Color(0xFF34C759),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Source de musique',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.2,
          ),
          itemCount: chips.length,
          itemBuilder: (context, index) {
            final c = chips[index];
            final selected = serverFamily == c.family;
            return TvFocusableCard(
              onTap: () => onChanged(c.family),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? c.activeColor.withAlpha(28)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03)),
                  border: Border.all(
                    color: selected
                        ? c.activeColor
                        : (isDark ? Colors.white12 : Colors.black12),
                    width: selected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      c.icon,
                      size: 17,
                      color: selected ? c.activeColor : labelColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        c.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected ? c.activeColor : labelColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
