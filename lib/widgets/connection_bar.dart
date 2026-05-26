import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_colors.dart';

/// Thin strip at the very top of the library showing the cloud connection
/// state. Green dot + "CONNECTED: <host>" when signed in; gray dot +
/// "OFFLINE" otherwise. Matches the phone mockup header.
class ConnectionBar extends ConsumerWidget {
  const ConnectionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authRepositoryProvider);
    final connected = auth.isSignedIn;
    final host = _hostFromUrl(auth.serverUrl);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: connected
                  ? const Color(0xFF34D399) // emerald-400
                  : AppColors.textTertiary,
              shape: BoxShape.circle,
              boxShadow: connected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF34D399).withValues(alpha: 0.55),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            connected ? 'CONNECTED: $host' : 'OFFLINE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: connected
                  ? AppColors.textSecondary
                  : AppColors.textTertiary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _hostFromUrl(String url) {
    try {
      final u = Uri.parse(url);
      final port = u.hasPort && u.port != 80 && u.port != 443 ? ':${u.port}' : '';
      return '${u.host}$port'.isEmpty ? url : '${u.host}$port';
    } catch (_) {
      return url;
    }
  }
}
