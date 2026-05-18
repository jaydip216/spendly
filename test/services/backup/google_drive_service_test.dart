import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:spendly/services/backup/backup_service.dart';
import 'package:spendly/services/backup/google_drive_service.dart';

// ── Fake GoogleSignIn platform ────────────────────────────────────────────────

/// Controls whether [signIn] returns a user or null (cancelled).
class _FakeGoogleSignInPlatform extends Fake
    implements GoogleSignInPlatform {
  bool cancelSignIn = false;
  bool wasSigned = false;

  @override
  bool get isMock => true;

  static final _fakeUser = GoogleSignInUserData(
    email: 'test@example.com',
    id: 'fake-id-123',
    idToken: 'fake-id-token',
  );

  @override
  Future<void> initWithParams(SignInInitParameters params) async {}

  @override
  Future<GoogleSignInUserData?> signIn() async {
    if (cancelSignIn) return null;
    wasSigned = true;
    return _fakeUser;
  }

  @override
  Future<GoogleSignInUserData?> signInSilently() async {
    if (!wasSigned) return null;
    return _fakeUser;
  }

  @override
  Future<void> signOut() async {
    wasSigned = false;
  }

  @override
  Future<GoogleSignInTokenData> getTokens({
    required String email,
    bool? shouldRecoverAuth,
  }) async {
    return GoogleSignInTokenData(accessToken: 'fake-access-token');
  }

  @override
  Future<bool> isSignedIn() async => wasSigned;

  @override
  Stream<GoogleSignInUserData?>? get userDataEvents => null;
}

// ── Fake BackupService ────────────────────────────────────────────────────────

class _FakeBackupService implements BackupService {
  String exportResult = '{"schemaVersion":1,"exportedAt":"2026-01-01","expenses":[]}';
  String? lastImported;
  bool exportCalled = false;

  @override
  Future<String> exportToJson() async {
    exportCalled = true;
    return exportResult;
  }

  @override
  Future<void> importFromJson(String json) async {
    lastImported = json;
  }

  // Unused BackupService internals — not needed by GoogleDriveService
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Drive HTTP mock helpers ───────────────────────────────────────────────────

/// Builds a [DriveApi] backed by [mockClient] so no real HTTP calls are made.
drive.DriveApi _driveApiWithClient(http.Client mockClient) {
  return drive.DriveApi(mockClient);
}

/// A [FileList] JSON payload with one file entry.
String _fileListJson({String fileId = 'file-abc'}) {
  return jsonEncode({
    'kind': 'drive#fileList',
    'files': [
      {'id': fileId},
    ],
  });
}

/// A [FileList] JSON payload with no files.
String _emptyFileListJson() {
  return jsonEncode({'kind': 'drive#fileList', 'files': []});
}

/// A [File] JSON payload (returned by create/update).
String _fileJson({String fileId = 'file-abc'}) {
  return jsonEncode({'kind': 'drive#file', 'id': fileId});
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _FakeGoogleSignInPlatform fakePlatform;
  late _FakeBackupService fakeBackup;

  setUp(() {
    fakePlatform = _FakeGoogleSignInPlatform();
    GoogleSignInPlatform.instance = fakePlatform;
    fakeBackup = _FakeBackupService();
  });

  // Helper: build service with a Drive HTTP mock.
  GoogleDriveService makeService(http.Client driveClient) {
    return GoogleDriveService(
      fakeBackup,
      googleSignIn: GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]),
      driveApiFactory: () async => _driveApiWithClient(driveClient),
    );
  }

  group('signIn', () {
    test('returns success when user completes sign-in', () async {
      final svc = makeService(http_testing.MockClient((_) async =>
          http.Response('', 200)));

      final result = await svc.signIn();
      expect(result, isA<GoogleDriveSuccess>());
    });

    test('returns authCancelled when user dismisses sign-in', () async {
      fakePlatform.cancelSignIn = true;
      final svc = makeService(http_testing.MockClient((_) async =>
          http.Response('', 200)));

      final result = await svc.signIn();
      expect(result, isA<GoogleDriveAuthCancelled>());
    });
  });

  group('backup', () {
    test('calls exportToJson and uploads file (create path)', () async {
      // First call: list returns empty (no existing file).
      // Second call: create returns a file object.
      var callCount = 0;
      final client = http_testing.MockClient((request) async {
        callCount++;
        if (request.method == 'GET') {
          // files.list
          return http.Response(
            _emptyFileListJson(),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        // files.create (multipart POST)
        return http.Response(
          _fileJson(),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = makeService(client);
      final result = await svc.backup();

      expect(result, isA<GoogleDriveSuccess>());
      expect(fakeBackup.exportCalled, isTrue);
      expect(callCount, greaterThanOrEqualTo(2));
    });

    test('updates existing file when backup already exists', () async {
      var patchCalled = false;
      final client = http_testing.MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            _fileListJson(fileId: 'existing-id'),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        // files.update (PATCH)
        if (request.method == 'PATCH') {
          patchCalled = true;
        }
        return http.Response(
          _fileJson(fileId: 'existing-id'),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = makeService(client);
      final result = await svc.backup();

      expect(result, isA<GoogleDriveSuccess>());
      expect(patchCalled, isTrue);
    });

    test('returns authCancelled when not signed in and factory returns null',
        () async {
      final svc = GoogleDriveService(
        fakeBackup,
        googleSignIn: GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]),
        driveApiFactory: () async => null,
      );

      final result = await svc.backup();
      expect(result, isA<GoogleDriveAuthCancelled>());
    });
  });

  group('restore', () {
    test('downloads file and calls importFromJson on success', () async {
      const backupContent = '{"schemaVersion":1,"exportedAt":"2026-01-01","expenses":[]}';
      final backupBytes = utf8.encode(backupContent);

      final client = http_testing.MockClient((request) async {
        // files.list → path ends with /files and has q= param
        if (request.url.queryParameters.containsKey('q')) {
          return http.Response(
            _fileListJson(),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        // files.get with alt=media → download the actual content
        if (request.url.queryParameters['alt'] == 'media') {
          return http.Response.bytes(
            backupBytes,
            200,
            headers: {'content-type': 'application/octet-stream'},
          );
        }
        // files.get metadata
        return http.Response(
          _fileJson(),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = makeService(client);
      final result = await svc.restore();

      expect(result, isA<GoogleDriveSuccess>());
      expect(fakeBackup.lastImported, backupContent);
    });

    test('returns noBackupFound when no file exists on Drive', () async {
      final client = http_testing.MockClient((request) async {
        return http.Response(
          _emptyFileListJson(),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = makeService(client);
      final result = await svc.restore();

      expect(result, isA<GoogleDriveNoBackupFound>());
    });

    test('returns authCancelled when factory returns null', () async {
      final svc = GoogleDriveService(
        fakeBackup,
        googleSignIn: GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]),
        driveApiFactory: () async => null,
      );

      final result = await svc.restore();
      expect(result, isA<GoogleDriveAuthCancelled>());
    });
  });

  group('signOut', () {
    test('delegates to GoogleSignIn.signOut without throwing', () async {
      fakePlatform.wasSigned = true;
      final svc = makeService(http_testing.MockClient((_) async =>
          http.Response('', 200)));

      await expectLater(svc.signOut(), completes);
      expect(fakePlatform.wasSigned, isFalse);
    });
  });
}
