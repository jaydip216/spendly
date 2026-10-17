import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/format.dart';
import '../../app/theme/spendly_theme.dart';
import '../../app/widgets/classical.dart';
import '../../core/providers/providers.dart';
import '../../services/backup/google_drive_service.dart';

/// The only insurance Spendly has: there is no server to restore from.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _loading = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _recordBackupTimestamp() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(
      lastBackupTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    // lastBackupProvider reads prefs once; force it to re-read.
    ref.invalidate(lastBackupProvider);
  }

  Future<void> _exportToFile() async {
    await _run(() async {
      final backupService = ref.read(backupServiceProvider);
      final json = await backupService.exportToJson();
      final result = await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(json)),
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: ['spendly-backup.json'],
        subject: 'Spendly Backup',
      );
      if (result.status == ShareResultStatus.success) {
        await _recordBackupTimestamp();
      }
    });
  }

  Future<void> _importFromFile() async {
    await _run(() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String? content;

      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      }

      if (content == null) {
        _showSnackBar('Failed to read file.');
        return;
      }

      final backupService = ref.read(backupServiceProvider);
      await backupService.importFromJson(content);
      _showSnackBar('Import successful!');
    });
  }

  Future<void> _backupToDrive() async {
    await _run(() async {
      final driveService = ref.read(googleDriveServiceProvider);
      final result = await driveService.backup();
      if (result is GoogleDriveSuccess) {
        await _recordBackupTimestamp();
      }
      _showSnackBar(_driveResultMessage(result, 'Backup successful!'));
    });
  }

  Future<void> _restoreFromDrive() async {
    await _run(() async {
      final driveService = ref.read(googleDriveServiceProvider);
      final result = await driveService.restore();
      _showSnackBar(_driveResultMessage(result, 'Restore successful!'));
    });
  }

  String _driveResultMessage(GoogleDriveResult result, String successMessage) {
    return switch (result) {
      GoogleDriveSuccess() => successMessage,
      GoogleDriveAuthCancelled() => 'Sign-in cancelled.',
      GoogleDriveNoBackupFound() => 'No backup found on Google Drive.',
      GoogleDriveNetworkError() => 'Network error. Check your connection.',
      GoogleDriveUnknownError(:final message) => 'Error: $message',
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final lastBackup = ref.watch(lastBackupProvider);
    final entryCount = ref.watch(allExpensesProvider).valueOrNull?.length;

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Backup')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lastBackup == null)
                  Callout(
                    title: 'Backup is off',
                    body:
                        'Your ${entryCount ?? 'saved'} spends live only in this '
                        "app's storage. Clearing app data, a factory reset or a "
                        'lost phone takes them with it.',
                  )
                else
                  Callout(
                    title: 'Last backed up ${dayMonthYear.format(lastBackup)}',
                    body:
                        'Anything recorded since then exists only on this phone. '
                        'Export again whenever it matters.',
                  ),
                const SizedBox(height: 24),

                const SectionLabel('File backup'),
                const SizedBox(height: 10),
                Text(
                  'Spendly writes a single JSON file with every spend, note and '
                  'category, and hands it to the Android share sheet. Put it '
                  'wherever you like — Files, Drive, a chat with yourself.',
                  style: tokens.body(12.5, color: tokens.muted(0.62)),
                ),
                const SizedBox(height: 16),
                _BackupAction(
                  key: const Key('export_to_file_button'),
                  icon: Icons.file_upload_outlined,
                  title: 'Export to File',
                  subtitle: 'Save a JSON backup to share or store locally.',
                  onTap: _loading ? null : _exportToFile,
                ),
                _BackupAction(
                  key: const Key('import_from_file_button'),
                  icon: Icons.file_download_outlined,
                  title: 'Import from File',
                  subtitle:
                      'Restore expenses from a previously exported JSON file.',
                  bottomRule: true,
                  onTap: _loading ? null : _importFromFile,
                ),
                const SizedBox(height: 24),

                const SectionLabel('Google Drive'),
                const SizedBox(height: 10),
                Text(
                  'The same file, uploaded to your own Drive. Spendly only ever '
                  'touches the one file it wrote.',
                  style: tokens.body(12.5, color: tokens.muted(0.62)),
                ),
                const SizedBox(height: 16),
                _BackupAction(
                  key: const Key('backup_to_drive_button'),
                  icon: Icons.cloud_upload_outlined,
                  title: 'Backup to Google Drive',
                  subtitle: 'Upload your expenses to Google Drive.',
                  onTap: _loading ? null : _backupToDrive,
                ),
                _BackupAction(
                  key: const Key('restore_from_drive_button'),
                  icon: Icons.cloud_download_outlined,
                  title: 'Restore from Google Drive',
                  subtitle: 'Download and restore expenses from Google Drive.',
                  bottomRule: true,
                  onTap: _loading ? null : _restoreFromDrive,
                ),
                const SizedBox(height: 18),
                Text(
                  'Importing replaces everything currently in the app — it does '
                  'not merge. Nothing is written unless the whole file reads '
                  'cleanly.',
                  style: tokens.body(11.5, color: tokens.muted(0.48)),
                ),
              ],
            ),
          ),
          if (_loading)
            ColoredBox(
              color: tokens.background.withValues(alpha: 0.7),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _BackupAction extends StatelessWidget {
  const _BackupAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.bottomRule = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool bottomRule;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: ListRow(
        title: title,
        subtitle: subtitle,
        leadingIcon: icon,
        showChevron: true,
        bottomRule: bottomRule,
        onTap: onTap,
      ),
    );
  }
}
