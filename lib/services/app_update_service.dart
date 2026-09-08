import 'dart:io' show Directory, File, Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pomo/config/app_update_config.dart';
import 'package:pomo/models/app_update_manifest.dart';
import 'package:pomo/services/android_apk_install_service.dart';

enum AppUpdatePhase {
  idle,
  checking,
  downloading,
  installing,
}

class AppUpdateResult {
  const AppUpdateResult._({
    required this.phase,
    this.manifest,
    this.errorMessage,
    this.installed = false,
  });

  final AppUpdatePhase phase;
  final AppUpdateManifest? manifest;
  final String? errorMessage;
  final bool installed;

  bool get isUpdateAvailable =>
      manifest != null && errorMessage == null && phase == AppUpdatePhase.idle;

  static const idle = AppUpdateResult._(phase: AppUpdatePhase.idle);

  static AppUpdateResult updateAvailable(AppUpdateManifest manifest) {
    return AppUpdateResult._(
      phase: AppUpdatePhase.idle,
      manifest: manifest,
    );
  }

  static AppUpdateResult failure(String message) {
    return AppUpdateResult._(
      phase: AppUpdatePhase.idle,
      errorMessage: message,
    );
  }

  static AppUpdateResult busy(AppUpdatePhase phase) {
    return AppUpdateResult._(phase: phase);
  }

  static AppUpdateResult installStarted(AppUpdateManifest manifest) {
    return AppUpdateResult._(
      phase: AppUpdatePhase.idle,
      manifest: manifest,
      installed: true,
    );
  }
}

/// Fetches [AppUpdateConfig.manifestUrl], downloads APKs, and triggers install.
class AppUpdateService {
  AppUpdateService({
    Dio? dio,
    AndroidApkInstallService? installService,
    String? manifestUrl,
  })  : _dio = dio ?? Dio(),
        _installService = installService ?? AndroidApkInstallService(),
        _manifestUrl = manifestUrl ?? AppUpdateConfig.manifestUrl;

  final Dio _dio;
  final AndroidApkInstallService _installService;
  final String _manifestUrl;

  AppUpdatePhase _phase = AppUpdatePhase.idle;

  AppUpdatePhase get phase => _phase;

  /// True on Android production package only.
  @visibleForTesting
  static Future<bool> isEligibleForOta({
    required bool isAndroid,
    required String packageName,
  }) async {
    if (kIsWeb || !isAndroid) return false;
    return packageName == AppUpdateConfig.productionPackageName;
  }

  Future<bool> get isEligible async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final info = await PackageInfo.fromPlatform();
    return info.packageName == AppUpdateConfig.productionPackageName;
  }

  Future<AppUpdateResult> checkForUpdate() async {
    if (!await isEligible) {
      return AppUpdateResult.failure('Updates are Android production only.');
    }
    if (_phase != AppUpdatePhase.idle) {
      return AppUpdateResult.busy(_phase);
    }

    _phase = AppUpdatePhase.checking;
    try {
      final info = await PackageInfo.fromPlatform();
      final localCode = int.tryParse(info.buildNumber) ?? 0;
      final response = await _dio.get<dynamic>(
        _manifestUrl,
        options: Options(
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return AppUpdateResult.failure('Invalid update manifest.');
      }
      final manifest = AppUpdateManifest.fromJson(data);
      if (!manifest.isValid) {
        return AppUpdateResult.failure('Update manifest is incomplete.');
      }
      if (manifest.versionCode <= localCode) {
        return AppUpdateResult.idle;
      }
      return AppUpdateResult.updateAvailable(manifest);
    } on DioException catch (error) {
      return AppUpdateResult.failure(
        'Could not reach update server (${error.type.name}).',
      );
    } catch (error) {
      return AppUpdateResult.failure('Update check failed: $error');
    } finally {
      _phase = AppUpdatePhase.idle;
    }
  }

  Future<AppUpdateResult> downloadAndInstall(AppUpdateManifest manifest) async {
    if (!await isEligible) {
      return AppUpdateResult.failure('Updates are Android production only.');
    }
    if (_phase != AppUpdatePhase.idle) {
      return AppUpdateResult.busy(_phase);
    }

    if (!manifest.isValid) {
      return AppUpdateResult.failure('Update manifest is incomplete.');
    }

    _phase = AppUpdatePhase.downloading;
    File? apkFile;
    try {
      final dir = await _resolveDownloadDir();
      apkFile = File('${dir.path}/pomo-update.apk');
      if (apkFile.existsSync()) {
        await apkFile.delete();
      }

      await _dio.download(
        manifest.apkUrl,
        apkFile.path,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
        ),
      );

      if (!apkFile.existsSync() || apkFile.lengthSync() < 1024) {
        return AppUpdateResult.failure('Downloaded APK looks invalid.');
      }

      _phase = AppUpdatePhase.installing;

      var canInstall = await _installService.canInstallPackages();
      if (!canInstall) {
        canInstall = await _installService.requestInstallPermission();
      }
      if (!canInstall) {
        return AppUpdateResult.failure(
          'Allow installs from Pomo in Settings, then try again.',
        );
      }

      final launched = await _installService.installApk(apkFile.path);
      if (!launched) {
        return AppUpdateResult.failure('Could not open the package installer.');
      }
      return AppUpdateResult.installStarted(manifest);
    } on DioException catch (error) {
      return AppUpdateResult.failure(
        'Download failed (${error.type.name}).',
      );
    } catch (error) {
      return AppUpdateResult.failure('Install failed: $error');
    } finally {
      _phase = AppUpdatePhase.idle;
    }
  }

  @visibleForTesting
  static Future<Directory> resolveDownloadDir() => _resolveDownloadDir();

  static Future<Directory> _resolveDownloadDir() async {
    final cacheDir = await getTemporaryDirectory();
    final updatesDir = Directory('${cacheDir.path}/pomo_updates');
    if (!updatesDir.existsSync()) {
      await updatesDir.create(recursive: true);
    }
    return updatesDir;
  }
}
