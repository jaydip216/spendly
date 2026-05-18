import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/providers.dart';
import '../../services/backup/google_drive_service.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _exportToFile() async {
    await _run(() async {
      final backupService = ref.read(backupServiceProvider);
      final json = await backupService.exportToJson();
      await Share.share(json, subject: 'Spendly Backup');
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setInt(lastBackupTimestampKey, DateTime.now().millisecondsSinceEpoch);
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
        content = String.fromCharCodes(file.bytes!);
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
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.setInt(lastBackupTimestampKey, DateTime.now().millisecondsSinceEpoch);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader(title: 'Local Backup'),
              const SizedBox(height: 8),
              _BackupActionCard(
                key: const Key('export_to_file_button'),
                icon: Icons.upload_file_rounded,
                title: 'Export to File',
                subtitle: 'Save a JSON backup to share or store locally.',
                onTap: _loading ? null : _exportToFile,
              ),
              const SizedBox(height: 12),
              _BackupActionCard(
                key: const Key('import_from_file_button'),
                icon: Icons.download_rounded,
                title: 'Import from File',
                subtitle: 'Restore expenses from a previously exported JSON file.',
                onTap: _loading ? null : _importFromFile,
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Google Drive'),
              const SizedBox(height: 8),
              _BackupActionCard(
                key: const Key('backup_to_drive_button'),
                icon: Icons.cloud_upload_rounded,
                title: 'Backup to Google Drive',
                subtitle: 'Upload your expenses to Google Drive.',
                onTap: _loading ? null : _backupToDrive,
              ),
              const SizedBox(height: 12),
              _BackupActionCard(
                key: const Key('restore_from_drive_button'),
                icon: Icons.cloud_download_rounded,
                title: 'Restore from Google Drive',
                subtitle: 'Download and restore expenses from Google Drive.',
                onTap: _loading ? null : _restoreFromDrive,
              ),
            ],
          ),
          if (_loading)
            const ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

class _BackupActionCard extends StatelessWidget {
  const _BackupActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        onTap: onTap,
        enabled: onTap != null,
      ),
    );
  }
}
