/// Android OTA update manifest URL and production package gate.
abstract final class AppUpdateConfig {
  /// Hosted on Vercel next to the PWA (free tier). APK binary lives on GitHub
  /// Releases; this file only points at the download URL.
  static const manifestUrl =
      'https://pomo-focus-sand.vercel.app/android/version.json';

  /// Production application id (no flavor suffix).
  static const productionPackageName = 'com.recoskyler.pomo';
}
