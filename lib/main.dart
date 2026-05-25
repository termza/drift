import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/auth_repository.dart';
import 'services/database.dart';
import 'state/providers.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop window — hide the native title bar and we'll paint our own.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1100, 760),
      minimumSize: Size(420, 600),
      center: true,
      backgroundColor: AppColors.bg,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    JustAudioMediaKit.ensureInitialized();
  }

  // Background audio + lock-screen controls on iOS/Android.
  if (Platform.isIOS || Platform.isAndroid) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.audiolisten.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );
  }

  final db = await AppDatabase.open();
  final auth = await AuthRepository.init();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWith((_) => auth),
      ],
      child: const AudioListenApp(),
    ),
  );
}
