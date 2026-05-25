import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'sign_in_screen.dart';

/// iOS-style grouped settings list. White cards on the neutral background,
/// rows with leading icon · title/subtitle · trailing element.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.gutter,
                  Insets.md,
                  Insets.gutter,
                  Insets.lg,
                ),
                child: Row(
                  children: [
                    InkResponse(
                      radius: 22,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Padding(
                        padding: EdgeInsets.all(Insets.xs),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 26,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('Settings', style: theme.textTheme.displayLarge),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _Group(
                children: [
                  if (auth.isSignedIn) ...[
                    _Row(
                      icon: Icons.account_circle_outlined,
                      iconColor: AppColors.accent,
                      title: auth.userEmail ?? 'Signed in',
                      subtitle: auth.serverUrl,
                    ),
                    _Row(
                      icon: Icons.refresh_rounded,
                      iconColor: AppColors.accent,
                      title: 'Sync now',
                      subtitle: 'Pull latest from server',
                      onTap: () =>
                          ref.read(syncServiceProvider).reconcile(),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                        size: 22,
                      ),
                    ),
                    _Row(
                      icon: Icons.logout_rounded,
                      iconColor: AppColors.danger,
                      title: 'Sign out',
                      titleColor: AppColors.danger,
                      onTap: () async => auth.signOut(),
                    ),
                  ] else
                    _Row(
                      icon: Icons.account_circle_outlined,
                      iconColor: AppColors.accent,
                      title: 'Sign in',
                      subtitle: 'Sync progress across devices',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SignInScreen(),
                          fullscreenDialog: true,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
            const SliverToBoxAdapter(
              child: _GroupHeader(text: 'PLAYBACK'),
            ),
            const SliverToBoxAdapter(
              child: _Group(
                children: [
                  _Row(
                    icon: Icons.replay_10_rounded,
                    iconColor: AppColors.textPrimary,
                    title: 'Skip back',
                    trailing: _ValueText('15 sec'),
                  ),
                  _Row(
                    icon: Icons.forward_30_rounded,
                    iconColor: AppColors.textPrimary,
                    title: 'Skip forward',
                    trailing: _ValueText('30 sec'),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(
              child: _GroupHeader(text: 'ABOUT'),
            ),
            const SliverToBoxAdapter(
              child: _Group(
                children: [
                  _Row(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppColors.textPrimary,
                    title: 'Drift',
                    trailing: _ValueText('0.1.0'),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Insets.xxxl)),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.gutter + 4,
        Insets.xl,
        Insets.gutter,
        Insets.xs,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: 52),
                  child: Divider(
                    height: 0.5,
                    color: AppColors.borderSubtle,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          12,
          Insets.md,
          12,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
    );
  }
}
