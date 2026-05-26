import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_colors.dart';

/// Custom title bar for desktop. Native chrome is hidden via window_manager
/// init in main(); this widget paints our own — brand wordmark on the left,
/// drag-to-move area in the middle, three caption buttons on the right.
///
/// On non-desktop platforms it returns SizedBox.shrink so the same widget
/// tree works everywhere.
class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({super.key});

  static bool get supported =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    if (WindowTitleBar.supported) {
      windowManager.addListener(this);
      _refresh();
    }
  }

  @override
  void dispose() {
    if (WindowTitleBar.supported) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    final m = await windowManager.isMaximized();
    if (mounted) setState(() => _maximized = m);
  }

  @override
  void onWindowMaximize() => _refresh();
  @override
  void onWindowUnmaximize() => _refresh();

  @override
  Widget build(BuildContext context) {
    if (!WindowTitleBar.supported) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ColoredBox(
        color: AppColors.bg,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: () async {
                  if (await windowManager.isMaximized()) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 0, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _BrandWord(),
                  ),
                ),
              ),
            ),
            _CaptionButton(
              icon: _MinIcon(),
              onTap: () => windowManager.minimize(),
            ),
            _CaptionButton(
              icon: _maximized
                  ? const _RestoreIcon()
                  : const _MaxIcon(),
              onTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _CaptionButton(
              icon: const _CloseIcon(),
              hoverColor: AppColors.danger,
              hoverIconColor: Colors.white,
              onTap: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandWord extends StatelessWidget {
  const _BrandWord();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 0,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'DRIFT',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 1,
          height: 11,
          color: AppColors.textTertiary.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 8),
        Text(
          'Your Cloud Library',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.onTap,
    this.hoverColor,
    this.hoverIconColor,
  });

  final Widget icon;
  final VoidCallback onTap;
  final Color? hoverColor;
  final Color? hoverIconColor;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hover
        ? (widget.hoverColor ?? AppColors.fillTertiary)
        : Colors.transparent;
    final iconColor = (_hover && widget.hoverIconColor != null)
        ? widget.hoverIconColor!
        : AppColors.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 36,
          color: bg,
          alignment: Alignment.center,
          child: IconTheme.merge(
            data: IconThemeData(color: iconColor, size: 11),
            child: widget.icon,
          ),
        ),
      ),
    );
  }
}

// Custom-drawn caption glyphs — Material has no minimize/restore icons that
// match Windows convention at small sizes.

class _MinIcon extends StatelessWidget {
  const _MinIcon();
  @override
  Widget build(BuildContext context) => Builder(builder: (ctx) {
        final color = IconTheme.of(ctx).color ?? Colors.white;
        return CustomPaint(
          size: const Size(11, 11),
          painter: _LinePainter(color: color, kind: _LineKind.minimize),
        );
      });
}

class _MaxIcon extends StatelessWidget {
  const _MaxIcon();
  @override
  Widget build(BuildContext context) => Builder(builder: (ctx) {
        final color = IconTheme.of(ctx).color ?? Colors.white;
        return CustomPaint(
          size: const Size(11, 11),
          painter: _LinePainter(color: color, kind: _LineKind.maximize),
        );
      });
}

class _RestoreIcon extends StatelessWidget {
  const _RestoreIcon();
  @override
  Widget build(BuildContext context) => Builder(builder: (ctx) {
        final color = IconTheme.of(ctx).color ?? Colors.white;
        return CustomPaint(
          size: const Size(11, 11),
          painter: _LinePainter(color: color, kind: _LineKind.restore),
        );
      });
}

class _CloseIcon extends StatelessWidget {
  const _CloseIcon();
  @override
  Widget build(BuildContext context) => Builder(builder: (ctx) {
        final color = IconTheme.of(ctx).color ?? Colors.white;
        return CustomPaint(
          size: const Size(11, 11),
          painter: _LinePainter(color: color, kind: _LineKind.close),
        );
      });
}

enum _LineKind { minimize, maximize, restore, close }

class _LinePainter extends CustomPainter {
  _LinePainter({required this.color, required this.kind});
  final Color color;
  final _LineKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final w = size.width;
    final h = size.height;

    switch (kind) {
      case _LineKind.minimize:
        canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), p);
      case _LineKind.maximize:
        canvas.drawRect(
          Rect.fromLTWH(0.5, 0.5, w - 1, h - 1),
          p,
        );
      case _LineKind.restore:
        // Two overlapping rects (offset back-top-right)
        canvas.drawRect(
          Rect.fromLTWH(2.5, 0.5, w - 3, h - 3),
          p,
        );
        canvas.drawRect(
          Rect.fromLTWH(0.5, 2.5, w - 3, h - 3),
          p..color = color,
        );
      case _LineKind.close:
        canvas.drawLine(const Offset(0, 0), Offset(w, h), p);
        canvas.drawLine(Offset(w, 0), Offset(0, h), p);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.color != color || old.kind != kind;
}
