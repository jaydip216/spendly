import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/format.dart';
import '../../app/theme/spendly_theme.dart';
import '../../app/widgets/classical.dart';
import '../../core/providers/providers.dart';

/// Where the data lives, how it is read, and what happens if you lose it —
/// stated plainly, because Spendly has no server to fall back on.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool _rescanning = false;
  bool? _smsGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAccess();
  }

  Future<void> _refreshAccess() async {
    try {
      final granted = await Permission.sms.isGranted;
      if (mounted) setState(() => _smsGranted = granted);
    } catch (_) {
      if (mounted) setState(() => _smsGranted = null);
    }
  }

  Future<void> _rescan() async {
    setState(() => _rescanning = true);
    try {
      final ingestion = ref.read(smsIngestionServiceProvider);
      if (!await ingestion.requestSmsPermissions()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'SMS access is off. Allow it in Android Settings to scan messages.',
            ),
          ),
        );
        return;
      }
      await ingestion.start();
      final added = await ingestion.ingestHistoricalInbox();
      await ref
          .read(sharedPreferencesProvider)
          .setBool(initialSmsSyncDoneKey, true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'Inbox re-read — nothing new to add.'
                : 'Inbox re-read — $added new spend${added == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read message history. Check SMS access and try again.',
            ),
          ),
        );
      }
    } finally {
      await _refreshAccess();
      if (mounted) setState(() => _rescanning = false);
    }
  }

  Future<void> _manageSmsAccess() async {
    if (_smsGranted != true) {
      await _rescan();
      return;
    }

    final opened = await openAppSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Android Settings.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final lastBackup = ref.watch(lastBackupProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final expenses = ref.watch(allExpensesProvider).valueOrNull ?? const [];

    return TabPage(
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Settings',
                  style: tokens.heading(21, weight: FontWeight.w600),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              children: [
                const Rule(),
                const _GroupLabel('Your data'),
                ListRow(
                  title: 'Backup',
                  subtitle: lastBackup == null
                      ? 'Never backed up — everything lives only on this phone'
                      : 'Last backup ${dayMonthYear.format(lastBackup)}',
                  leadingIcon: Icons.file_download_outlined,
                  showChevron: true,
                  onTap: () => context.push('/backup'),
                ),
                ListRow(
                  title: 'Categories',
                  subtitle:
                      '${categories.length} categories · rename, recolour, '
                      'or add your own',
                  leadingIcon: Icons.sell_outlined,
                  showChevron: true,
                  onTap: () => context.push('/categories'),
                ),
                ListRow(
                  title: 'Add a spend by hand',
                  subtitle:
                      'For cash, or anything your bank did not text about',
                  leadingIcon: Icons.add,
                  showChevron: true,
                  bottomRule: true,
                  onTap: () => context.push('/manual-entry'),
                ),

                const _GroupLabel('Appearance'),
                const _ThemeRow(),

                const _GroupLabel('Reading messages'),
                ListRow(
                  title: 'SMS access',
                  subtitle: _smsGranted == null
                      ? 'Permission status unavailable'
                      : _smsGranted!
                      ? 'Granted · ${expenses.length} entries · tap to manage'
                      : 'Access is off — tap to enable and scan messages',
                  onTap: _rescanning ? null : _manageSmsAccess,
                  trailing: StatusTag(
                    _smsGranted == null
                        ? 'Unknown'
                        : _smsGranted!
                        ? 'On'
                        : 'Off',
                    outlined: _smsGranted != true,
                  ),
                ),
                ListRow(
                  title: 'Re-scan message history',
                  subtitle:
                      'Reads the inbox again. Existing entries are matched, '
                      'not duplicated.',
                  bottomRule: true,
                  trailing: _rescanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 1.6),
                        )
                      : null,
                  onTap: _rescanning ? null : _rescan,
                  showChevron: !_rescanning,
                ),

                ListRow(
                  title: 'Review SMS entries',
                  subtitle:
                      'Check saved OTPs, credits and other non-spending alerts.',
                  showChevron: true,
                  onTap: () => context.push('/sms-review'),
                ),
                const _GroupLabel('About'),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: tokens.divider),
                      bottom: BorderSide(color: tokens.divider),
                    ),
                  ),
                  child: Text(
                    'Spendly keeps every spend, note and edit in a database on '
                    'this phone. There is no account, no sync and no '
                    'analytics. Uninstalling the app or clearing its storage '
                    'deletes the lot — keep a backup.',
                    style: tokens.body(12.5, color: tokens.muted(0.62)),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Version 1.0 · Debits only in this release',
                    style: tokens.body(11, color: tokens.muted(0.4)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: SectionLabel(label),
    );
  }
}

class _ThemeRow extends ConsumerWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: SpendlyTokens.of(context).divider),
          bottom: BorderSide(color: SpendlyTokens.of(context).divider),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Theme',
              style: SpendlyTokens.of(context).body(14.5, height: 1.3),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final option in ThemeMode.values)
                PillChip(
                  label: switch (option) {
                    ThemeMode.system => 'Auto',
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                  },
                  selected: mode == option,
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).setThemeMode(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
