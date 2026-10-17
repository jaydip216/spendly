import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/spendly_theme.dart';
import '../../core/providers/providers.dart';
import '../../services/sms/sms_ingestion_service.dart';
import '../onboarding/transparency_screen.dart';

/// Hosts the four tabs and gates the whole app behind onboarding. Ingestion is
/// started here once, so every tab can assume live SMS is already flowing.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _ready = false;
  final List<int> _tabHistory = [];

  @override
  void initState() {
    super.initState();
    _tabHistory.add(widget.navigationShell.currentIndex);
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recordTab(widget.navigationShell.currentIndex);
  }

  void _recordTab(int index) {
    if (_tabHistory.isNotEmpty && _tabHistory.last == index) return;
    _tabHistory.remove(index);
    _tabHistory.add(index);
  }

  void _selectTab(int index) {
    final current = widget.navigationShell.currentIndex;
    if (index != current) {
      setState(() => _recordTab(index));
    }
    widget.navigationShell.goBranch(index, initialLocation: index == current);
  }

  void _handleBack(bool didPop, Object? result) {
    if (didPop || _tabHistory.length < 2) return;
    setState(() => _tabHistory.removeLast());
    widget.navigationShell.goBranch(_tabHistory.last);
  }

  Future<void> _bootstrap() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(onboardingSeenKey) ?? false) {
      final SmsIngestionService ingestion = ref.read(
        smsIngestionServiceProvider,
      );
      try {
        await ingestion.start();
      } catch (_) {
        // Revoked SMS access must not prevent access to saved/manual expenses.
        // Settings offers a permission request and retry.
      }
    }

    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);

    if (!_ready) {
      return Scaffold(
        backgroundColor: tokens.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final prefs = ref.watch(sharedPreferencesProvider);
    if (!(prefs.getBool(onboardingSeenKey) ?? false)) {
      return TransparencyScreen(
        onCompleted: () async {
          if (mounted) setState(() {});
        },
      );
    }

    return PopScope<Object?>(
      canPop: _tabHistory.length < 2,
      onPopInvokedWithResult: _handleBack,
      child: Scaffold(
        backgroundColor: tokens.background,
        body: widget.navigationShell,
        bottomNavigationBar: _TabBar(
          currentIndex: widget.navigationShell.currentIndex,
          onSelected: _selectTab,
        ),
      ),
    );
  }
}

const _tabs = <({IconData icon, String label})>[
  (icon: Icons.home_outlined, label: 'Home'),
  (icon: Icons.format_list_bulleted_rounded, label: 'Spends'),
  (icon: Icons.pie_chart_outline_rounded, label: 'Insights'),
  (icon: Icons.settings_outlined, label: 'Settings'),
];

/// Flat 70px bar: a hairline across the top, and a 2px gold bar over the
/// active tab instead of a pill or a filled indicator.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.background,
        border: Border(top: BorderSide(color: tokens.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _Tab(
                    icon: _tabs[i].icon,
                    label: _tabs[i].label,
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final color = selected ? tokens.accent : tokens.muted(0.55);

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: selected ? tokens.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              style: tokens.body(10, color: color, letterSpacingEm: 0.05),
            ),
          ],
        ),
      ),
    );
  }
}
