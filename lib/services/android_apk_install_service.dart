import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';

/// Native APK install bridge (`MainActivity` channel `app_update`).
class AndroidApkInstallService {
  factory AndroidApkInstallService() => _instance;
  AndroidApkInstallService._internal();
  static final AndroidApkInstallService _instance =
      AndroidApkInstallService._internal();

  @visibleForTesting
  static const channelName = 'com.recoskyler.pomo/app_update';

  static const MethodChannel _channel = MethodChannel(channelName);

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<bool> canInstallPackages() async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('canInstallPackages');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestInstallPermission() async {
    if (!isSupported) return false;
    try {
      final result =
          await _channel.invokeMethod<bool>('requestInstallPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> installApk(String filePath) async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'installApk',
        <String, Object>{'path': filePath},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
