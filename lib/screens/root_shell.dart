import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../widgets/mini_player.dart';
import '../widgets/sidebar.dart';
import 'favorites_screen.dart';
import 'library_screen.dart';

/// App root: persistent sidebar (Spotify-style) + main content + mini player.
/// Sidebar is icon-only below a threshold and full-width above it.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _bootSync() {
    final sync = ref.read(syncServiceProvider);
    unawaited(sync.reconcile());
    sync.startPeriodic();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(syncServiceProvider).reconcile());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authRepositoryProvider, (_, __) => _bootSync());
    final section = ref.watch(currentSectionProvider);

    return LayoutBuilder(
      builder: (context, c) {
        final showSidebar = c.maxWidth >= 560;
        final compactSidebar = c.maxWidth < 820;

        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (showSidebar) Sidebar(compact: compactSidebar),
                    Expanded(child: _SectionBody(section: section)),
                  ],
                ),
              ),
              const MiniPlayer(),
            ],
          ),
          bottomNavigationBar: showSidebar
              ? null
              : _MobileNavBar(section: section),
        );
      },
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section});
  final AppSection section;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: child,
      ),
      child: switch (section) {
        AppSection.library => const LibraryScreen(
            key: ValueKey('library'),
          ),
        AppSection.favorites => const FavoritesScreen(
            key: ValueKey('favorites'),
          ),
      },
    );
  }
}

class _MobileNavBar extends ConsumerWidget {
  const _MobileNavBar({required this.section});
  final AppSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationBarTheme(
      data: const NavigationBarThemeData(
        backgroundColor: Color(0xFF1C1C1E),
        indicatorColor: Color(0x22E5A06B),
        elevation: 0,
      ),
      child: NavigationBar(
        selectedIndex: section == AppSection.library ? 0 : 1,
        onDestinationSelected: (i) {
          ref.read(currentSectionProvider.notifier).state =
              i == 0 ? AppSection.library : AppSection.favorites;
        },
        height: 60,
        labelBehavior:
            NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }
}
