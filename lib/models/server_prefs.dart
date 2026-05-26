/// Embedded sync-server preferences. When [enabled] is true, the desktop app
/// boots a PocketBase subprocess on 0.0.0.0:[port] so the iPhone app (or
/// any other device on the LAN) can connect using [syncEmail] + the
/// user-chosen [syncPassword].
///
/// [adminEmail] and [adminPassword] are generated on first enable and never
/// exposed in the UI — they're only used to provision the sync user inside
/// PocketBase.
class ServerPrefs {
  final bool enabled;
  final int port;
  final String syncEmail;
  final String syncPassword;
  final String adminEmail;
  final String adminPassword;

  const ServerPrefs({
    this.enabled = false,
    this.port = 8090,
    this.syncEmail = 'drift@local',
    this.syncPassword = '',
    this.adminEmail = '',
    this.adminPassword = '',
  });

  bool get hasCredentials =>
      syncPassword.isNotEmpty &&
      adminEmail.isNotEmpty &&
      adminPassword.isNotEmpty;

  ServerPrefs copyWith({
    bool? enabled,
    int? port,
    String? syncEmail,
    String? syncPassword,
    String? adminEmail,
    String? adminPassword,
  }) =>
      ServerPrefs(
        enabled: enabled ?? this.enabled,
        port: port ?? this.port,
        syncEmail: syncEmail ?? this.syncEmail,
        syncPassword: syncPassword ?? this.syncPassword,
        adminEmail: adminEmail ?? this.adminEmail,
        adminPassword: adminPassword ?? this.adminPassword,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'port': port,
        'syncEmail': syncEmail,
        'syncPassword': syncPassword,
        'adminEmail': adminEmail,
        'adminPassword': adminPassword,
      };

  factory ServerPrefs.fromJson(Map<String, dynamic> j) => ServerPrefs(
        enabled: (j['enabled'] as bool?) ?? false,
        port: (j['port'] as num?)?.toInt() ?? 8090,
        syncEmail: (j['syncEmail'] as String?) ?? 'drift@local',
        syncPassword: (j['syncPassword'] as String?) ?? '',
        adminEmail: (j['adminEmail'] as String?) ?? '',
        adminPassword: (j['adminPassword'] as String?) ?? '',
      );
}
