import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'storage_service.dart';

enum BackupSyncStatus {
  idle,
  connecting,
  syncing,
  success,
  error,
}

class BackupState {
  final String? email;
  final DateTime? lastSyncedAt;
  final BackupSyncStatus status;
  final String? message;
  final bool ready;
  final int dataRevision;

  const BackupState({
    this.email,
    this.lastSyncedAt,
    this.status = BackupSyncStatus.idle,
    this.message,
    this.ready = false,
    this.dataRevision = 0,
  });

  bool get isConnected => email != null && email!.isNotEmpty;

  BackupState copyWith({
    String? email,
    DateTime? lastSyncedAt,
    BackupSyncStatus? status,
    String? message,
    bool? ready,
    int? dataRevision,
    bool clearEmail = false,
    bool clearMessage = false,
  }) {
    return BackupState(
      email: clearEmail ? null : (email ?? this.email),
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      ready: ready ?? this.ready,
      dataRevision: dataRevision ?? this.dataRevision,
    );
  }
}

/// Email + passcode backup against khorocboi-server.
///
/// 1) User sets email and a 4+ digit passcode once
/// 2) Every local change auto-uploads the full snapshot
/// 3) Reinstall + same email/passcode restores the previous data
class CloudSyncService {
  CloudSyncService(this._storage);

  static const _prefsEmailKey = 'cloud_sync_email';
  static const _prefsCodeKey = 'cloud_sync_code';
  static const _prefsLastSyncKey = 'cloud_sync_last_sync';
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _codePattern = RegExp(r'^\d{4,}$');

  final StorageService _storage;
  final _stateController = StreamController<BackupState>.broadcast();

  BackupState _state = const BackupState();
  Timer? _debounce;
  bool _initialized = false;
  bool _syncInFlight = false;
  String? _code;

  BackupState get state => _state;
  Stream<BackupState> get stateStream => _stateController.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_prefsEmailKey);
    _code = prefs.getString(_prefsCodeKey);
    final lastRaw = prefs.getString(_prefsLastSyncKey);
    final lastSynced = lastRaw == null ? null : DateTime.tryParse(lastRaw);

    final baseUrl = ApiConfig.syncServerUrl.trim();
    if (baseUrl.isEmpty || baseUrl.contains('YOUR_')) {
      _emit(
        _state.copyWith(
          ready: true,
          email: email,
          lastSyncedAt: lastSynced,
          status: BackupSyncStatus.error,
          message:
              'Add your khorocboi-server URL in api_config.dart to enable sync.',
        ),
      );
      return;
    }

    _emit(
      _state.copyWith(
        ready: true,
        email: email,
        lastSyncedAt: lastSynced,
      ),
    );
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

  String? validateCredentials(String email, String code) {
    final trimmedEmail = email.trim().toLowerCase();
    if (!_emailPattern.hasMatch(trimmedEmail)) {
      return 'Enter a valid email address.';
    }
    if (!_codePattern.hasMatch(code)) {
      return 'Passcode must be at least 4 digits.';
    }
    return null;
  }

  /// Save email + passcode, then restore (if any) and upload local data.
  Future<void> connect({
    required String email,
    required String code,
  }) async {
    final error = validateCredentials(email, code);
    if (error != null) {
      _emit(
        _state.copyWith(
          status: BackupSyncStatus.error,
          message: error,
        ),
      );
      return;
    }

    _emit(
      _state.copyWith(
        status: BackupSyncStatus.connecting,
        clearMessage: true,
      ),
    );

    if (!await _hasNetwork()) {
      _emit(
        _state.copyWith(
          status: BackupSyncStatus.error,
          message: 'No internet connection.',
        ),
      );
      return;
    }

    final normalizedEmail = email.trim().toLowerCase();

    try {
      final remote = await _restore(normalizedEmail, code);
      _code = code;
      await _persistCredentials(normalizedEmail, code);
      _emit(_state.copyWith(email: normalizedEmail));
      await syncNow(
        force: true,
        pushOnly: false,
        prefetchedRemote: remote,
        remoteChecked: true,
      );
    } on _SyncHttpException catch (e) {
      _emit(
        _state.copyWith(
          status: BackupSyncStatus.error,
          message: e.message,
        ),
      );
    } catch (e) {
      debugPrint('Cloud connect failed: $e');
      _emit(
        _state.copyWith(
          status: BackupSyncStatus.error,
          message: 'Could not connect. Please try again.',
        ),
      );
    }
  }

  Future<void> disconnect() async {
    _debounce?.cancel();
    _code = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsEmailKey);
    await prefs.remove(_prefsCodeKey);
    _emit(
      _state.copyWith(
        clearEmail: true,
        status: BackupSyncStatus.idle,
        clearMessage: true,
      ),
    );
  }

  /// Sync with the server.
  ///
  /// [pushOnly] = upload local snapshot only (used after every edit/delete).
  /// Full sync pulls first: empty local → exact restore; else merge, then push.
  Future<void> syncNow({
    bool force = true,
    bool pushOnly = false,
    Map<String, dynamic>? prefetchedRemote,
    bool remoteChecked = false,
  }) async {
    final email = _state.email;
    final code = _code;
    if (email == null || code == null) {
      _emit(
        _state.copyWith(
          status: BackupSyncStatus.error,
          message: 'Set your email and passcode to sync history.',
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
      var dataChanged = false;
      Map<String, dynamic>? remoteJson = prefetchedRemote;

      if (!pushOnly && remoteJson == null && !remoteChecked) {
        remoteJson = await _restore(email, code);
      }

      if (!pushOnly && remoteJson != null) {
        if (!_storage.hasAnyTabs) {
          await _storage.replaceAllFromBackup(remoteJson);
          dataChanged = true;
        } else {
          final merged = await _storage.mergeFromBackup(remoteJson);
          dataChanged = merged > 0;
        }
      }

      await _push(email, code);

      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsLastSyncKey, now.toIso8601String());

      _emit(
        _state.copyWith(
          status: BackupSyncStatus.success,
          lastSyncedAt: now,
          message: dataChanged
              ? 'History restored from your account.'
              : 'Backup saved to your account.',
          dataRevision:
              dataChanged ? _state.dataRevision + 1 : _state.dataRevision,
        ),
      );
    } on _SyncHttpException catch (e) {
      _emit(
        _state.copyWith(
          status: BackupSyncStatus.error,
          message: e.message,
        ),
      );
    } catch (e) {
      debugPrint('Cloud sync failed: $e');
      _emit(
        _state.copyWith(
          status: BackupSyncStatus.error,
          message: 'Sync failed. Please try again.',
        ),
      );
    } finally {
      _syncInFlight = false;
    }
  }

  /// Debounced upload after every local change (notes / delete).
  void scheduleUploadAfterEdit() {
    if (!_state.isConnected || _code == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      unawaited(syncNow(force: true, pushOnly: true));
    });
  }

  /// App-start restore when credentials are already saved.
  Future<void> maybeAutoSync() async {
    if (!_state.isConnected || _code == null) return;
    if (!await _hasNetwork()) return;
    await syncNow(force: true, pushOnly: false);
  }

  Future<void> _persistCredentials(String email, String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsEmailKey, email);
    await prefs.setString(_prefsCodeKey, code);
  }

  Uri _uri(String path) {
    final base = ApiConfig.syncServerUrl.trim().replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path');
  }

  Future<Map<String, dynamic>?> _restore(String email, String code) async {
    final res = await http
        .post(
          _uri('/api/restore'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'code': code}),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw _SyncHttpException(_errorFrom(res));
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<void> _push(String email, String code) async {
    final res = await http
        .post(
          _uri('/api/sync'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'code': code,
            'data': _storage.exportBackup(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw _SyncHttpException(_errorFrom(res));
    }
  }

  String _errorFrom(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is String) {
        return body['error'] as String;
      }
    } catch (_) {}
    return 'Request failed (${res.statusCode}).';
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await _stateController.close();
  }
}

class _SyncHttpException implements Exception {
  _SyncHttpException(this.message);
  final String message;

  @override
  String toString() => message;
}
