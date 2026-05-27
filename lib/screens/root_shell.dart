import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../widgets/mini_player.dart';
import '../widgets/sidebar.dart';
import 'cloud_status_screen.dart';
import 'favorites_screen.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'playlists_screen.dart';
import 'settings_screen.dart';

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
    // Eagerly instantiate the embedded sync server so it actually starts on
    // app boot — without this watch, the provider stays lazy and the server
    // only spins up when the user happens to open Settings → Sync Server.
    ref.watch(embeddedServerServiceProvider);
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
        AppSection.library =>
          const LibraryScreen(key: ValueKey('library')),
        AppSection.favorites =>
          const FavoritesScreen(key: ValueKey('favorites')),
        AppSection.playlists =>
          const PlaylistsScreen(key: ValueKey('playlists')),
        AppSection.playing =>
          const PlayerScreen(key: ValueKey('playing')),
        AppSection.cloudStatus =>
          const CloudStatusScreen(key: ValueKey('cloud')),
        AppSection.settings =>
          const SettingsScreen(key: ValueKey('settings'), embedded: true),
      },
    );
  }
}

/// Mobile bottom nav — 4 tabs matching the phone mockup:
/// Library · Playing · Cloud Status · Settings. Favorites + Playlists live
/// behind in-screen affordances on mobile (or via the side drawer if we add
/// one later).
class _MobileNavBar extends ConsumerWidget {
  const _MobileNavBar({required this.section});
  final AppSection section;

  static const _tabs = <AppSection>[
    AppSection.library,
    AppSection.playing,
    AppSection.cloudStatus,
    AppSection.settings,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _tabs.indexOf(section).clamp(0, _tabs.length - 1);
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppColors.bg,
        indicatorColor: AppColors.accent.withValues(alpha: 0.18),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) {
            ref.read(currentSectionProvider.notifier).state = _tabs[i];
          },
          height: 62,
          labelBehavior:
              NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.library_music_outlined,
                color: AppColors.textSecondary,
              ),
              selectedIcon: Icon(
                Icons.library_music_rounded,
                color: AppColors.accent,
              ),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.graphic_eq_rounded,
                color: AppColors.textSecondary,
              ),
              selectedIcon: Icon(
                Icons.graphic_eq_rounded,
                color: AppColors.accent,
              ),
              label: 'Playing',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.cloud_outlined,
                color: AppColors.textSecondary,
              ),
              selectedIcon: Icon(
                Icons.cloud_rounded,
                color: AppColors.accent,
              ),
              label: 'Cloud Status',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.settings_outlined,
                color: AppColors.textSecondary,
              ),
              selectedIcon: Icon(
                Icons.settings_rounded,
                color: AppColors.accent,
              ),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
