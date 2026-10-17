import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/spendly_theme.dart';
import '../../app/widgets/classical.dart';
import '../../core/providers/providers.dart';
import '../../services/sms/sms_ingestion_service.dart';

/// The one screen that has to earn trust: what Spendly reads, where it keeps
/// it, and what it costs you if the phone goes.
class TransparencyScreen extends ConsumerStatefulWidget {
  const TransparencyScreen({super.key, required this.onCompleted});

  final Future<void> Function() onCompleted;

  @override
  ConsumerState<TransparencyScreen> createState() => _TransparencyScreenState();
}

class _TransparencyScreenState extends ConsumerState<TransparencyScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _continue() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final SmsIngestionService ingestion = ref.read(
        smsIngestionServiceProvider,
      );
      final prefs = ref.read(sharedPreferencesProvider);
      final granted = await ingestion.requestSmsPermissions();

      if (!mounted) {
        return;
      }

      if (!granted) {
        setState(() {
          _error = 'SMS permission is required for Spendly to detect expenses.';
        });
        return;
      }

      await ingestion.start();

      if (!(prefs.getBool(initialSmsSyncDoneKey) ?? false)) {
        await ingestion.ingestHistoricalInbox();
        await prefs.setBool(initialSmsSyncDoneKey, true);
      }

      await prefs.setBool(onboardingSeenKey, true);
      await widget.onCompleted();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            'Setup failed due to a temporary issue. Please retry in a moment.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Skips the permission entirely — the app still works, entry by entry.
  Future<void> _continueWithoutSms() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(onboardingSeenKey, true);
    await widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
          children: [
            const SizedBox(height: 40),
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tokens.accent),
              ),
              child: Icon(
                Icons.shield_outlined,
                size: 22,
                color: tokens.accent,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Your spending,\nread on this phone\nand nowhere else.',
              style: tokens.heading(38, height: 1.06, letterSpacingEm: -0.02),
            ),
            const SizedBox(height: 24),
            const Rule(),
            const SizedBox(height: 22),
            const SectionLabel('Why Spendly needs SMS'),
            const SizedBox(height: 16),
            const _Point(
              index: '01',
              text:
                  'Banks text you after every UPI, credit and debit card '
                  'payment. Spendly reads those texts to build your spend log — '
                  'no receipts to type in.',
            ),
            const _Point(
              index: '02',
              text:
                  'Everything is parsed and stored on this device. Spendly has '
                  'no server and no account. Nothing about your money leaves '
                  'the phone.',
            ),
            const _Point(
              index: '03',
              text:
                  'Only messages that look like bank or payment alerts are '
                  'read. Personal messages are skipped, never stored, never '
                  'uploaded.',
            ),
            const _Point(
              index: '04',
              text:
                  'You can revoke the permission any time in Android Settings. '
                  'Spendly keeps the entries it already made until you delete '
                  'them.',
            ),
            const SizedBox(height: 6),
            const Rule(),
            const SizedBox(height: 18),
            Text(
              'Because the data lives only here, clearing app storage or losing '
              'the phone loses your history. Turn on a backup in Settings once '
              'you are set up.',
              style: tokens.body(12.5, color: tokens.muted(0.58)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: tokens.body(12.5, color: tokens.danger)),
            ],
            const SizedBox(height: 28),
            ClassicalButton(
              label: 'Allow SMS access',
              height: 48,
              fontSize: 14,
              expand: true,
              busy: _isLoading,
              onPressed: _isLoading ? null : _continue,
            ),
            const SizedBox(height: 9),
            ClassicalButton(
              label: 'Not now — add spends manually',
              variant: ClassicalButtonVariant.secondary,
              height: 44,
              expand: true,
              onPressed: _isLoading ? null : _continueWithoutSms,
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.index, required this.text});

  final String index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(index, style: tokens.figure(15, color: tokens.accent)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: tokens.body(14.5, height: 1.6))),
        ],
      ),
    );
  }
}
