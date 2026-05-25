import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/root_shell.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/window_title_bar.dart';

class AudioListenApp extends ConsumerWidget {
  const AudioListenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Drift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      // The window title bar is pinned above EVERY route so it persists
      // across pushes (library → settings → sign-in → player). Desktop only;
      // on mobile WindowTitleBar returns SizedBox.shrink().
      builder: (context, child) => ColoredBox(
        color: AppColors.bg,
        child: Column(
          children: [
            const WindowTitleBar(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        ),
      ),
      home: const RootShell(),
    );
  }
}
