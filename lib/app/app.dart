import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/focus_page.dart';
import '../ui/history_page.dart';
import '../ui/settings_page.dart';
import '../ui/wellness_notice.dart';
import 'services.dart';

class FocusedMindApp extends StatelessWidget {
  const FocusedMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E7D74);
    return MaterialApp(
      title: 'Focused Mind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNoticeOnce());
  }

  Future<void> _showNoticeOnce() async {
    final repo = ref.read(servicesProvider).settingsRepository;
    if (repo.wellnessNoticeSeen || !mounted) return;
    await showWellnessNotice(context);
    await repo.markWellnessNoticeSeen();
  }

  @override
  Widget build(BuildContext context) {
    const pages = [FocusPage(), HistoryPage(), SettingsPage()];
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Icon(Icons.self_improvement, size: 32),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.center_focus_weak),
                selectedIcon: Icon(Icons.center_focus_strong),
                label: Text('Focus'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history),
                label: Text('History'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
    );
  }
}
