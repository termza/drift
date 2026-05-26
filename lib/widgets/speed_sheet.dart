import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

Future<void> showSpeedSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    builder: (_) => const _SpeedSheet(),
  );
}

class _SpeedSheet extends ConsumerWidget {
  const _SpeedSheet();

  static const _presets = <double>[0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final player = ref.watch(audioPlayerProvider);
    final speed = ref.watch(playbackSnapshotProvider).maybeWhen(
          data: (s) => s.speed,
          orElse: () => player.speed,
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.gutter,
          Insets.sm,
          Insets.gutter,
          Insets.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            Text('Playback Speed', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 4),
            Center(
              child: Text(
                _label(speed),
                style: theme.textTheme.displayLarge?.copyWith(
                  color: AppColors.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.accent,
                thumbColor: AppColors.accent,
                inactiveTrackColor: AppColors.fillTertiary,
                overlayColor: AppColors.accentSoft,
                trackHeight: 4,
              ),
              child: Slider(
                value: speed.clamp(0.5, 3.0),
                min: 0.5,
                max: 3.0,
                divisions: 50,
                onChanged: (v) =>
                    player.setSpeed(double.parse(v.toStringAsFixed(2))),
              ),
            ),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              alignment: WrapAlignment.center,
              children: [
                for (final s in _presets)
                  _Preset(
                    value: s,
                    selected: (s - speed).abs() < 0.01,
                    onTap: () => player.setSpeed(s),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _label(double v) =>
      '${v.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}×';
}

class _Preset extends StatelessWidget {
  const _Preset({
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final double value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label =
        '${value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}×';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.fillTertiary,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected ? AppColors.accent : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
