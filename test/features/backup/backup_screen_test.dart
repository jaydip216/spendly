import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendly/core/providers/providers.dart';
import 'package:spendly/features/backup/backup_screen.dart';
import 'package:spendly/services/backup/backup_service.dart';
import 'package:spendly/services/backup/google_drive_service.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeBackupService implements BackupService {
  String? imported;
  @override
  Future<String> exportToJson() async => '{}';

  @override
  Future<void> importFromJson(String json) async {
    imported = json;
  }

  // ignore: unused_element
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoogleDriveService implements GoogleDriveService {
  @override
  Future<GoogleDriveResult> backup() async => const GoogleDriveSuccess();

  @override
  Future<GoogleDriveResult> restore() async => const GoogleDriveSuccess();

  @override
  Future<GoogleDriveResult> signIn() async => const GoogleDriveSuccess();

  @override
  Future<void> signOut() async {}

  // ignore: unused_element
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _buildSubject(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      backupServiceProvider.overrideWithValue(_FakeBackupService()),
      googleDriveServiceProvider.overrideWithValue(_FakeGoogleDriveService()),
    ],
    child: const MaterialApp(home: BackupScreen()),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('file import preserves UTF-8 merchant names', (tester) async {
    FilePicker.platform = _FilePicker();
    final service = _FakeBackupService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          backupServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: BackupScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import_from_file_button')));
    await tester.pumpAndSettle();
    expect(jsonDecode(service.imported!)['merchant'], 'चाय ☕');
  });

  testWidgets('BackupScreen renders 4 action buttons', (tester) async {
    await tester.pumpWidget(_buildSubject(prefs));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('export_to_file_button')), findsOneWidget);
    expect(find.byKey(const Key('import_from_file_button')), findsOneWidget);
    expect(find.byKey(const Key('backup_to_drive_button')), findsOneWidget);
    expect(find.byKey(const Key('restore_from_drive_button')), findsOneWidget);
  });

  testWidgets('Export button has correct label', (tester) async {
    await tester.pumpWidget(_buildSubject(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Export to File'), findsOneWidget);
  });

  testWidgets('Import button has correct label', (tester) async {
    await tester.pumpWidget(_buildSubject(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Import from File'), findsOneWidget);
  });

  testWidgets('Backup to Drive button has correct label', (tester) async {
    await tester.pumpWidget(_buildSubject(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Backup to Google Drive'), findsOneWidget);
  });

  testWidgets('Restore from Drive button has correct label', (tester) async {
    await tester.pumpWidget(_buildSubject(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Restore from Google Drive'), findsOneWidget);
  });
}

class _FilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(
      name: 'backup.json',
      size: 0,
      bytes: Uint8List.fromList(utf8.encode('{"merchant":"चाय ☕"}')),
    ),
  ]);
}
