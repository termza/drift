import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/appearance_prefs_service.dart';
import '../services/playback_prefs_service.dart';
import '../state/providers.dart';
import '../theme/accent_palette.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_panel.dart';
import 'sign_in_screen.dart';

/// iOS-style grouped settings list. White cards on the neutral background,
/// rows with leading icon · title/subtitle · trailing element.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authRepositoryProvider);
    final prefsService = ref.watch(playbackPrefsServiceProvider);
    final prefs = prefsService.current;
    final appearanceService = ref.watch(appearancePrefsServiceProvider);
    final appearance = appearanceService.current;
    final accentPreset = accentPresetByKey(appearance.accentKey);

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
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.xs),
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
                      trailing: Icon(
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
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
            const SliverToBoxAdapter(
              child: _GroupHeader(text: 'APPEARANCE'),
            ),
            SliverToBoxAdapter(
              child: _Group(
                children: [
                  _Row(
                    icon: Icons.brightness_6_outlined,
                    iconColor: AppColors.textPrimary,
                    title: 'Theme',
                    trailing: _ValueText(_themeLabel(appearance.themeMode)),
                    onTap: () => _showThemeModeSheet(context, appearanceService),
                  ),
                  _Row(
                    icon: Icons.palette_outlined,
                    iconColor: AppColors.textPrimary,
                    title: 'Accent color',
                    trailing: _AccentSwatch(color: accentPreset.color),
                    onTap: () => _showAccentSheet(context, appearanceService),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(
              child: _GroupHeader(text: 'PLAYBACK'),
            ),
            SliverToBoxAdapter(
              child: _Group(
                children: [
                  _Row(
                    icon: Icons.replay_10_rounded,
                    iconColor: AppColors.textPrimary,
                    title: 'Skip back',
                    trailing: _ValueText('${prefs.skipBackSeconds} sec'),
                    onTap: () => _pickSeconds(
                      context,
                      title: 'Skip back',
                      current: prefs.skipBackSeconds,
                      options: const [5, 10, 15, 20, 30, 45, 60],
                      onPick: prefsService.setSkipBack,
                    ),
                  ),
                  _Row(
                    icon: Icons.forward_30_rounded,
                    iconColor: AppColors.textPrimary,
                    title: 'Skip forward',
                    trailing: _ValueText('${prefs.skipForwardSeconds} sec'),
                    onTap: () => _pickSeconds(
                      context,
                      title: 'Skip forward',
                      current: prefs.skipForwardSeconds,
                      options: const [10, 15, 30, 45, 60, 90, 120],
                      onPick: prefsService.setSkipForward,
                    ),
                  ),
                  _Row(
                    icon: Icons.history_rounded,
                    iconColor: AppColors.textPrimary,
                    title: 'Auto-rewind on resume',
                    subtitle: prefs.autoRewindThresholdMinutes == 0
                        ? 'Off'
                        : 'After ${prefs.autoRewindThresholdMinutes} min · '
                            '${prefs.autoRewindSeconds} sec back',
                    onTap: () => _showAutoRewindSheet(context, prefsService),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(
              child: _GroupHeader(text: 'ABOUT'),
            ),
            SliverToBoxAdapter(
              child: _Group(
                children: [
                  _Row(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppColors.textPrimary,
                    title: 'Drift',
                    trailing: const _ValueText('0.1.0'),
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

String _themeLabel(ThemeMode m) => switch (m) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };

Future<void> _showThemeModeSheet(
  BuildContext context,
  AppearancePrefsService service,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    builder: (ctx) => AnimatedBuilder(
      animation: service,
      builder: (_, __) {
        final current = service.current.themeMode;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              Insets.md,
              Insets.gutter,
              Insets.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Theme', style: Theme.of(ctx).textTheme.headlineLarge),
                const SizedBox(height: Insets.md),
                for (final m in ThemeMode.values)
                  InkWell(
                    onTap: () async {
                      await service.setThemeMode(m);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Icon(
                            switch (m) {
                              ThemeMode.system => Icons.brightness_auto_outlined,
                              ThemeMode.light => Icons.light_mode_outlined,
                              ThemeMode.dark => Icons.dark_mode_outlined,
                            },
                            size: 22,
                            color: m == current
                                ? AppColors.accent
                                : AppColors.textPrimary,
                          ),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: Text(
                              _themeLabel(m),
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: m == current
                                        ? AppColors.accent
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (m == current)
                            Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: AppColors.accent,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _showAccentSheet(
  BuildContext context,
  AppearancePrefsService service,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    isScrollControlled: true,
    builder: (ctx) => AnimatedBuilder(
      animation: service,
      builder: (_, __) {
        final currentKey = service.current.accentKey;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.gutter,
              Insets.md,
              Insets.gutter,
              Insets.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accent color',
                  style: Theme.of(ctx).textTheme.headlineLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Used throughout Drift for highlights, buttons, and active states.',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: Insets.lg),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final p in kAccentPresets)
                      _AccentChoice(
                        preset: p,
                        selected: p.key == currentKey,
                        onTap: () => service.setAccentKey(p.key),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _pickSeconds(
  BuildContext context, {
  required String title,
  required int current,
  required List<int> options,
  required Future<void> Function(int) onPick,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.gutter,
          Insets.md,
          Insets.gutter,
          Insets.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(ctx).textTheme.headlineLarge),
            const SizedBox(height: Insets.md),
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: [
                for (final s in options)
                  _PickChip(
                    label: '$s sec',
                    selected: s == current,
                    onTap: () async {
                      await onPick(s);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showAutoRewindSheet(
  BuildContext context,
  PlaybackPrefsService service,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    isScrollControlled: true,
    builder: (ctx) {
      // Listen so chips update live as we tap.
      return AnimatedBuilder(
        animation: service,
        builder: (_, __) {
          final p = service.current;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.gutter,
                Insets.md,
                Insets.gutter,
                Insets.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-rewind on resume',
                    style: Theme.of(ctx).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Skip back a few seconds when you come back after a break.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Insets.lg),
                  Text(
                    'PAUSE THRESHOLD',
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Wrap(
                    spacing: Insets.xs,
                    runSpacing: Insets.xs,
                    children: [
                      for (final m in const [0, 1, 5, 15, 30])
                        _PickChip(
                          label: m == 0 ? 'Off' : '$m min',
                          selected: m == p.autoRewindThresholdMinutes,
                          onTap: () => service.setAutoRewindThreshold(m),
                        ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  Text(
                    'REWIND AMOUNT',
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Opacity(
                    opacity: p.autoRewindThresholdMinutes == 0 ? 0.5 : 1.0,
                    child: Wrap(
                      spacing: Insets.xs,
                      runSpacing: Insets.xs,
                      children: [
                        for (final s in const [5, 10, 15, 20, 30])
                          _PickChip(
                            label: '$s sec',
                            selected: s == p.autoRewindSeconds,
                            onTap: p.autoRewindThresholdMinutes == 0
                                ? null
                                : () => service.setAutoRewindSeconds(s),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _PickChip extends StatelessWidget {
  const _PickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm + 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.sm + 2),
          color: selected ? AppColors.accentSoft : AppColors.fillTertiary,
        ),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: selected ? AppColors.accent : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
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
      child: GlassPanel(
        borderRadius: BorderRadius.circular(Radii.md),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Divider(
                    height: 0.5,
                    color: Colors.white.withValues(alpha: 0.04),
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

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
    );
  }
}

class _AccentChoice extends StatelessWidget {
  const _AccentChoice({
    required this.preset,
    required this.selected,
    required this.onTap,
  });
  final AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: preset.name,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: preset.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.textPrimary : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: preset.color.withValues(alpha: 0.35),
                blurRadius: selected ? 14 : 0,
                spreadRadius: selected ? -2 : 0,
              ),
            ],
          ),
          child: selected
              ? Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: AppColors.accentInk,
                )
              : null,
        ),
      ),
    );
  }
}
