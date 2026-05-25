import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_spacing.dart';
import '../widgets/artwork.dart';
import 'sign_in_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                Insets.md,
              ),
              child: Text('Settings', style: theme.textTheme.displayMedium),
            ),
            _Section(
              title: 'Account',
              children: [
                _Row(
                  icon: auth.isSignedIn
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  iconAccent: auth.isSignedIn,
                  title: auth.isSignedIn
                      ? (auth.userEmail ?? 'Signed in')
                      : 'Offline',
                  subtitle: auth.isSignedIn
                      ? auth.serverUrl
                      : 'Sign in to sync progress across devices',
                  trailing: auth.isSignedIn
                      ? OutlinedButton(
                          onPressed: () async {
                            await auth.signOut();
                          },
                          child: const Text('Sign out'),
                        )
                      : FilledButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SignInScreen(),
                                fullscreenDialog: true,
                              ),
                            );
                          },
                          child: const Text('Sign in'),
                        ),
                ),
                if (auth.isSignedIn)
                  _Row(
                    icon: Icons.sync_rounded,
                    title: 'Sync now',
                    subtitle: 'Pull latest progress from the server',
                    trailing: IconButton(
                      onPressed: () =>
                          ref.read(syncServiceProvider).reconcile(),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ),
              ],
            ),
            _Section(
              title: 'Playback',
              children: const [
                _Row(
                  icon: Icons.fast_rewind_rounded,
                  title: 'Skip back',
                  subtitle: '15 seconds',
                ),
                _Row(
                  icon: Icons.fast_forward_rounded,
                  title: 'Skip forward',
                  subtitle: '30 seconds',
                ),
                _Row(
                  icon: Icons.equalizer_rounded,
                  title: 'Default speed',
                  subtitle: '1.0×',
                ),
              ],
            ),
            _Section(
              title: 'About',
              trailing: const Padding(
                padding: EdgeInsets.only(right: Insets.md),
                child: BrandMark(size: 28, glow: false),
              ),
              children: const [
                _Row(
                  icon: Icons.info_outline_rounded,
                  title: 'Audio Listen',
                  subtitle: 'Version 0.1.0',
                ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.trailing,
  });
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.sm,
        Insets.lg,
        Insets.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, Insets.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.6,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 54),
                      child: Divider(
                        color: theme.colorScheme.outlineVariant,
                        height: 0.5,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconAccent = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool iconAccent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.sm + 2,
        Insets.sm,
        Insets.sm + 2,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: iconAccent
                ? theme.colorScheme.primary
                : theme.textTheme.bodyMedium?.color,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
