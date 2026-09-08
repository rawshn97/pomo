import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/config/app_update_config.dart';
import 'package:pomo/services/android_apk_install_service.dart';
import 'package:pomo/services/app_update_service.dart';

void main() {
  late String mainActivity;

  setUpAll(() {
    mainActivity = File(
      'android/app/src/main/kotlin/com/recoskyler/MainActivity.kt',
    ).readAsStringSync();
  });

  test('production package gate matches application id', () {
    expect(AppUpdateConfig.productionPackageName, 'com.recoskyler.pomo');
  });

  test('Dart and native share the app_update MethodChannel name', () {
    expect(
      File('lib/services/android_apk_install_service.dart').readAsStringSync(),
      contains("'${AndroidApkInstallService.channelName}'"),
    );
    expect(mainActivity, contains('"${AndroidApkInstallService.channelName}"'));
  });

  test('MainActivity handles every Dart-invoked app_update method', () {
    const methods = <String>[
      'canInstallPackages',
      'requestInstallPermission',
      'installApk',
    ];
    final handlerStart = mainActivity.indexOf('APP_UPDATE_CHANNEL');
    expect(handlerStart, greaterThan(0));
    final handler = mainActivity.substring(handlerStart);
    final handled = RegExp(r'"([A-Za-z]+)"\s*->')
        .allMatches(handler)
        .map((match) => match.group(1)!)
        .toSet();
    expect(handled, containsAll(methods));
  });

  test('isEligibleForOta requires production package on Android', () async {
    expect(
      await AppUpdateService.isEligibleForOta(
        isAndroid: false,
        packageName: AppUpdateConfig.productionPackageName,
      ),
      isFalse,
    );
    expect(
      await AppUpdateService.isEligibleForOta(
        isAndroid: true,
        packageName: 'com.recoskyler.pomo.dev',
      ),
      isFalse,
    );
    expect(
      await AppUpdateService.isEligibleForOta(
        isAndroid: true,
        packageName: AppUpdateConfig.productionPackageName,
      ),
      isTrue,
    );
  });
}
