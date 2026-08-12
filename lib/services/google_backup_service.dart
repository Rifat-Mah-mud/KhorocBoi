import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'storage_service.dart';

enum BackupSyncStatus {
  idle,
  signingIn,
  syncing,
  success,
  error,
}

class BackupState {
  final GoogleSignInAccount? account;
  final DateTime? lastSyncedAt;
  final BackupSyncStatus status;
  final String? message;
  final bool ready;

  /// Bumps whenever local Hive data was changed by a restore/sync.
  final int dataRevision;

  const BackupState({
    this.account,
    this.lastSyncedAt,
    this.status = BackupSyncStatus.idle,
    this.message,
    this.ready = false,
    this.dataRevision = 0,
  });

  bool get isSignedIn => account != null;

  BackupState copyWith({
    GoogleSignInAccount? account,
    DateTime? lastSyncedAt,
    BackupSyncStatus? status,
    String? message,
    bool? ready,
    int? dataRevision,
    bool clearAccount = false,
    bool clearMessage = false,
  }) {
    return BackupState(
      account: clearAccount ? null : (account ?? this.account),
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      ready: ready ?? this.ready,
      dataRevision: dataRevision ?? this.dataRevision,
    );
  }
}

/// Google Sign-In + Drive appDataFolder backup/restore.
///
/// Flow the user expects:
/// 1) Sign in once with Gmail
/// 2) Every local change auto-uploads the full snapshot
/// 3) Reinstall + same Gmail → exact restore of previous data
class GoogleBackupService {
  GoogleBackupService(this._storage);

  static const _backupFileName = 'khorocboi_backup.json';
  static const _prefsLastSyncKey = 'google_backup_last_sync';
  static const _scopes = <String>[
    drive.DriveApi.driveAppdataScope,
  ];

  final StorageService _storage;
  final GoogleSignIn _signIn = GoogleSignIn.instance;
  final _stateController = StreamController<BackupState>.broadcast();

  BackupState _state = const BackupState();
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;
  Timer? _debounce;
  bool _initialized = false;
  bool _syncInFlight = false;

  BackupState get state => _state;
  Stream<BackupState> get stateStream => _stateController.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final lastRaw = prefs.getString(_prefsLastSyncKey);
    final lastSynced =
        lastRaw == null ? null : DateTime.tryParse(lastRaw);

    final clientId = ApiConfig.googleWebClientId.trim();
    if (clientId.isEmpty || clientId.contains('YOUR_')) {
      _emit(
        _state.copyWith(
          ready: true,
          lastSyncedAt: lastSynced,
          status: BackupSyncStatus.error,
          message:
              'Add your Google Web client ID in api_config.dart to enable backup.',
        ),
      );
      return;
    }

    try {
      await _signIn.initialize(serverClientId: clientId);
      _authSub = _signIn.authenticationEvents.listen(
        _onAuthEvent,
        onError: (Object e) {
          debugPrint('Google auth event error: $e');
        },
      );

      _emit(_state.copyWith(ready: true, lastSyncedAt: lastSynced));
      await _signIn.attemptLightweightAuthentication();
    } catch (e) {
      _emit(
        _state.copyWith(
          ready: true,
          lastSyncedAt: lastSynced,
          status: BackupSyncStatus.error,
          message: 'Google Sign-In setup failed: $e',
        ),
      );
    }
  }

  void _onAuthEvent(GoogleSignInAuthenticationEvent event) {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn(:final user):
        final wasSignedIn = _state.account != null;
        _emit(_state.copyWith(account: user, clearMessage: true));
        // First sign-in / session restore → pull cloud (exact restore if empty).
        if (!wasSignedIn) {
          unawaited(syncNow(force: true));
        }
      case GoogleSignInAuthenticationEventSignOut():
        _emit(_state.copyWith(clearAccount: true));
    }
  }

  void _emit(BackupState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  Future<bool> _hasNetwork() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> signIn() async {
    _emit(
      _state.copyWith(
        status: BackupSyncStatus.signingIn,
        clearMessage: true,
      ),
    );
    try {
      if (!_signIn.supportsAuthenticate()) {
        throw StateError('Google Sign-In is not supported on this platform.');
      }
      await _signIn.authenticate();
      // Auth event listener triggers syncNow.
      _emit(_state.copyWith(status: BackupSyncStatus.idle));
    } catch (e) {
      _emit(
        _state.copyWith(
          status: BackupSyncStatus.error,
          message: 'Sign-in failed: $e',
        ),
      );
    }
  }

  Future<void> signOut() async {
    await _signIn.signOut();
    _emit(
      _state.copyWith(
        clearAccount: true,
        status: BackupSyncStatus.idle,
        clearMessage: true,
      ),
    );
  }

  /// Sync with Google Drive.
  ///
  /// [pushOnly] = upload local snapshot only (used after every edit/delete).
  /// Full sync pulls first: empty local → exact restore; else merge, then push.
  Future<void> syncNow({
    bool force = true,
    bool pushOnly = false,
  }) async {
    final account = _state.account;
    if (account == null) {
      _emit(
        _state.copyWith(
          status: BackupSyncStatus.error,
          message: 'Sign in with Google to sync history.',
        ),
      );
      return;
    }

    if (!await _hasNetwork()) {
      _emit(
        _state.copyWith(
          status: BackupSyncStatus.error,
          message: 'No internet connection.',
        ),
      );
      return;
    }

    if (_syncInFlight) return;
    _syncInFlight = true;

    _emit(
      _state.copyWith(
        status: BackupSyncStatus.syncing,
        clearMessage: true,
      ),
    );

    try {
      final driveApi = await _driveApiFor(account);
      final remoteId = await _findBackupFileId(driveApi);
      var dataChanged = false;

      if (!pushOnly && remoteId != null) {
        final remoteJson = await _downloadBackup(driveApi, remoteId);
        if (remoteJson != null) {
          if (!_storage.hasAnyTabs) {
            // Reinstall / empty device → restore exactly.
            await _storage.replaceAllFromBackup(remoteJson);
            dataChanged = true;
          } else {
            final merged = await _storage.mergeFromBackup(remoteJson);
            dataChanged = merged > 0;
          }
        }
      }

      // Local is source of truth after edits/deletes — always push snapshot.
      await _uploadBackup(driveApi, existingFileId: remoteId);

      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsLastSyncKey, now.toIso8601String());

      _emit(
        _state.copyWith(
          status: BackupSyncStatus.success,
          lastSyncedAt: now,
          message: dataChanged
              ? 'History restored from Google Drive.'
              : 'Backup saved to Google Drive.',
          dataRevision:
              dataChanged ? _state.dataRevision + 1 : _state.dataRevision,
        ),
      );
    } catch (e) {
      debugPrint('Backup sync failed: $e');
      _emit(
        _state.copyWith(
          status: BackupSyncStatus.error,
          message: 'Sync failed: $e',
        ),
      );
    } finally {
      _syncInFlight = false;
    }
  }

  /// Debounced upload after every local change (notes / delete).
  void scheduleUploadAfterEdit() {
    if (_state.account == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      unawaited(syncNow(force: true, pushOnly: true));
    });
  }

  /// App-start restore when already signed in.
  Future<void> maybeAutoSync() async {
    if (_state.account == null) return;
    if (!await _hasNetwork()) return;
    await syncNow(force: true, pushOnly: false);
  }

  Future<drive.DriveApi> _driveApiFor(GoogleSignInAccount account) async {
    var authorization =
        await account.authorizationClient.authorizationForScopes(_scopes);
    authorization ??=
        await account.authorizationClient.authorizeScopes(_scopes);

    final client = authorization.authClient(scopes: _scopes);
    return drive.DriveApi(client);
  }

  Future<String?> _findBackupFileId(drive.DriveApi api) async {
    final listed = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName' and trashed = false",
      $fields: 'files(id, name, modifiedTime)',
    );
    final files = listed.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }

  Future<Map<String, dynamic>?> _downloadBackup(
    drive.DriveApi api,
    String fileId,
  ) async {
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  }

  Future<void> _uploadBackup(
    drive.DriveApi api, {
    String? existingFileId,
  }) async {
    final payload = utf8.encode(jsonEncode(_storage.exportBackup()));
    final media = drive.Media(Stream.value(payload), payload.length);

    if (existingFileId != null) {
      await api.files.update(
        drive.File()..name = _backupFileName,
        existingFileId,
        uploadMedia: media,
      );
      return;
    }

    await api.files.create(
      drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'],
      uploadMedia: media,
    );
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await _authSub?.cancel();
    await _stateController.close();
  }
}
