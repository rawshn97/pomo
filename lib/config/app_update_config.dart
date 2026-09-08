/// Android OTA update manifest URL and production package gate.
abstract final class AppUpdateConfig {
  /// OTA update manifest URL, configurable at build time via --dart-define.
  /// Hosted on Vercel next to the PWA (free tier). APK binary lives on GitHub
  /// Releases; this file only points at the download URL.
  static const manifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: 'https://pomo-focus-sand.vercel.app/android/version.json',
  );

  /// Production application id (no flavor suffix).
  static const productionPackageName = 'com.recoskyler.pomo';
}
