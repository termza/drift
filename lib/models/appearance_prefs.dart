import 'package:flutter/material.dart';

/// How the library shows tracks.
enum LibraryViewMode { list, grid, compact }

/// User-tunable appearance preferences. Persisted via shared_preferences.
class AppearancePrefs {
  final ThemeMode themeMode;
  final String accentKey;
  final LibraryViewMode libraryViewMode;

  const AppearancePrefs({
    this.themeMode = ThemeMode.dark,
    // Kinetic Amber — Drift's signature look. Existing installs keep
    // whatever they had stored.
    this.accentKey = 'kinetic',
    this.libraryViewMode = LibraryViewMode.list,
  });

  AppearancePrefs copyWith({
    ThemeMode? themeMode,
    String? accentKey,
    LibraryViewMode? libraryViewMode,
  }) =>
      AppearancePrefs(
        themeMode: themeMode ?? this.themeMode,
        accentKey: accentKey ?? this.accentKey,
        libraryViewMode: libraryViewMode ?? this.libraryViewMode,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'accentKey': accentKey,
        'libraryViewMode': libraryViewMode.name,
      };

  factory AppearancePrefs.fromJson(Map<String, dynamic> j) => AppearancePrefs(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == j['themeMode'],
          orElse: () => ThemeMode.dark,
        ),
        accentKey: j['accentKey'] as String? ?? 'kinetic',
        libraryViewMode: LibraryViewMode.values.firstWhere(
          (m) => m.name == j['libraryViewMode'],
          orElse: () => LibraryViewMode.list,
        ),
      );
}
