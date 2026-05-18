// NOTE: For production use, you must add google-services.json to android/app/
// and configure OAuth 2.0 credentials in Google Cloud Console.
// See: https://developers.google.com/identity/sign-in/android/start-integrating

import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'backup_service.dart';

/// Result type for Google Drive operations.
sealed class GoogleDriveResult {
  const GoogleDriveResult();
}

/// Operation completed successfully.
class GoogleDriveSuccess extends GoogleDriveResult {
  const GoogleDriveSuccess();
}

/// User cancelled the sign-in flow.
class GoogleDriveAuthCancelled extends GoogleDriveResult {
  const GoogleDriveAuthCancelled();
}

/// No backup file found on Drive during restore.
class GoogleDriveNoBackupFound extends GoogleDriveResult {
  const GoogleDriveNoBackupFound();
}

/// Network error occurred.
class GoogleDriveNetworkError extends GoogleDriveResult {
  const GoogleDriveNetworkError();
}

/// An unexpected error occurred.
class GoogleDriveUnknownError extends GoogleDriveResult {
  const GoogleDriveUnknownError(this.message);
  final String message;
}

/// Thin HTTP client that attaches Google auth headers to every request.
class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers, this._inner);

  final Map<String, String> _headers;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Service that backs up / restores Spendly data via Google Drive.
///
/// Uses the Drive File scope so the app can only see files it created.
/// A single file named [_backupFileName] is kept in the app folder.
class GoogleDriveService {
  GoogleDriveService(
    this._backupService, {
    GoogleSignIn? googleSignIn,
    /// Optional factory used in tests to inject a fake [drive.DriveApi].
    Future<drive.DriveApi?> Function()? driveApiFactory,
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]),
        _driveApiFactory = driveApiFactory;

  static const String _backupFileName = 'spendly_backup.json';

  final BackupService _backupService;
  final GoogleSignIn _googleSignIn;
  final Future<drive.DriveApi?> Function()? _driveApiFactory;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Signs in with Google and requests Drive file scope.
  Future<GoogleDriveResult> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return const GoogleDriveAuthCancelled();
      return const GoogleDriveSuccess();
    } on SocketException {
      return const GoogleDriveNetworkError();
    } catch (e) {
      return GoogleDriveUnknownError(e.toString());
    }
  }

  /// Exports all expenses to JSON and uploads to Drive.
  ///
  /// If a backup file already exists it is updated in-place; otherwise a new
  /// file is created in the app-data folder.
  Future<GoogleDriveResult> backup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return const GoogleDriveAuthCancelled();

      final json = await _backupService.exportToJson();
      final bytes = utf8.encode(json);
      final media = drive.Media(Stream.value(bytes), bytes.length,
          contentType: 'application/json');

      final existingId = await _findBackupFileId(driveApi);
      if (existingId != null) {
        // Update existing file.
        await driveApi.files.update(drive.File(), existingId, uploadMedia: media);
      } else {
        // Create new file.
        final file = drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'];
        await driveApi.files.create(file, uploadMedia: media);
      }

      return const GoogleDriveSuccess();
    } on SocketException {
      return const GoogleDriveNetworkError();
    } catch (e) {
      return GoogleDriveUnknownError(e.toString());
    }
  }

  /// Downloads the backup file from Drive and imports it.
  Future<GoogleDriveResult> restore() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return const GoogleDriveAuthCancelled();

      final fileId = await _findBackupFileId(driveApi);
      if (fileId == null) return const GoogleDriveNoBackupFound();

      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final chunks = await media.stream.toList();
      final bytes = chunks.expand((b) => b).toList();
      final json = utf8.decode(bytes);

      await _backupService.importFromJson(json);
      return const GoogleDriveSuccess();
    } on SocketException {
      return const GoogleDriveNetworkError();
    } catch (e) {
      return GoogleDriveUnknownError(e.toString());
    }
  }

  /// Signs out the current Google account.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<drive.DriveApi?> _getDriveApi() async {
    if (_driveApiFactory != null) return _driveApiFactory();

    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    if (account == null) return null;

    final auth = await account.authentication;
    final headers = {'Authorization': 'Bearer ${auth.accessToken}'};
    final client = _GoogleAuthClient(headers, http.Client());
    return drive.DriveApi(client);
  }

  Future<String?> _findBackupFileId(drive.DriveApi driveApi) async {
    final result = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      $fields: 'files(id)',
    );
    final files = result.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }
}
