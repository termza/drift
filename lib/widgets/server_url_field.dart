import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_repository.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/server_url.dart';

/// Text field for the PocketBase server URL with:
/// - smart normalization (IP, host:port, full URL, bare domain)
/// - a "Test" button that hits /api/health
/// - inline ✓ / ✗ status feedback
/// - recent-server chips for one-tap switching
///
/// The parent owns the [TextEditingController] so it can read the final
/// value at submit time.
class ServerUrlField extends ConsumerStatefulWidget {
  const ServerUrlField({
    super.key,
    required this.controller,
    this.onConnected,
  });

  final TextEditingController controller;

  /// Called when a Test passes — gives the parent the normalized URL so
  /// it can pre-fill / advance state.
  final void Function(String normalizedUrl)? onConnected;

  @override
  ConsumerState<ServerUrlField> createState() => _ServerUrlFieldState();
}

class _ServerUrlFieldState extends ConsumerState<ServerUrlField> {
  bool _testing = false;
  ConnectionTest? _result;

  Future<void> _runTest() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    final auth = ref.read(authRepositoryProvider);
    final result = await auth.testConnection(widget.controller.text);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _result = result;
    });
    if (result.ok && result.normalizedUrl != null) {
      widget.controller.text = result.normalizedUrl!;
      widget.onConnected?.call(result.normalizedUrl!);
    }
  }

  String? _previewNormalized() {
    final raw = widget.controller.text.trim();
    if (raw.isEmpty) return null;
    try {
      final n = normalizeServerUrl(raw);
      // Only show the preview if it changes the input meaningfully.
      return n.url == raw ? null : n.url;
    } on ServerUrlError {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authRepositoryProvider);
    final recents = auth.recentServers;
    final preview = _previewNormalized();
    final result = _result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Row(
            children: [
              Text(
                'Server URL',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'IP, host:port, or full URL',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: (_) {
                  // Clear stale test result as the user edits.
                  if (_result != null) setState(() => _result = null);
                },
                decoration: const InputDecoration(
                  hintText: '192.168.1.10  or  sync.example.com',
                ),
              ),
            ),
            const SizedBox(width: 8),
            _TestButton(
              testing: _testing,
              ok: result?.ok,
              onTap: _testing ? null : _runTest,
            ),
          ],
        ),
        if (preview != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Will save as $preview',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
        if (result != null) ...[
          const SizedBox(height: 8),
          _ResultLine(result: result),
        ],
        if (recents.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'RECENT',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final url in recents)
                _RecentChip(
                  url: url,
                  onTap: () {
                    widget.controller.text = url;
                    setState(() => _result = null);
                  },
                  onForget: () => auth.forgetServer(url),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({
    required this.testing,
    required this.ok,
    required this.onTap,
  });
  final bool testing;
  final bool? ok;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = ok == null
        ? AppColors.accent
        : ok!
            ? const Color(0xFF34D399)
            : AppColors.danger;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm + 2),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(Radii.sm + 2),
          border: Border.all(
            color: tint.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Center(
          child: testing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tint,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ok == null
                          ? Icons.wifi_find_rounded
                          : ok!
                              ? Icons.check_rounded
                              : Icons.close_rounded,
                      size: 16,
                      color: tint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Test',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tint,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.result});
  final ConnectionTest result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = result.ok ? const Color(0xFF34D399) : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            result.ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              result.message,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.url,
    required this.onTap,
    required this.onForget,
  });
  final String url;
  final VoidCallback onTap;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = _displayFor(url);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dns_outlined,
              size: 13,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              display,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            InkResponse(
              onTap: onForget,
              radius: 14,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayFor(String url) {
    try {
      final u = Uri.parse(url);
      final port = u.hasPort && u.port != 80 && u.port != 443 ? ':${u.port}' : '';
      return '${u.host}$port';
    } catch (_) {
      return url;
    }
  }
}
