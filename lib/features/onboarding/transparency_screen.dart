import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../services/sms/sms_ingestion_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Spendly')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transparency & Privacy',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const _BulletPoint(
              text:
                  'Spendly reads SMS on your phone to detect expense transactions.',
            ),
            const _BulletPoint(
              text:
                  'Data is stored only on your device. No cloud sync and no external server.',
            ),
            const _BulletPoint(
              text:
                  'Only transaction-relevant fields are extracted: amount, sender, merchant, UPI/card hints.',
            ),
            const _BulletPoint(
              text:
                  'You can stop using the app anytime by revoking SMS permission in Android settings.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _continue,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Allow SMS Access and Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
