import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/appearance_prefs_service.dart';
import 'services/auth_repository.dart';
import 'services/database.dart';
import 'services/playback_prefs_service.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop window — hide the native title bar and we'll paint our own.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    // Use a hardcoded black here — the WindowOptions is built at startup
    // before any theme is loaded, and AppColors values are runtime-mutable.
    const windowOptions = WindowOptions(
      size: Size(1100, 760),
      minimumSize: Size(420, 600),
      center: true,
      backgroundColor: Colors.black,
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
  final playbackPrefs = await PlaybackPrefsService.init();
  final appearancePrefs = await AppearancePrefsService.init();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWith((_) => auth),
        playbackPrefsServiceProvider.overrideWith((_) => playbackPrefs),
        appearancePrefsServiceProvider.overrideWith((_) => appearancePrefs),
      ],
      child: const AudioListenApp(),
    ),
  );
}
