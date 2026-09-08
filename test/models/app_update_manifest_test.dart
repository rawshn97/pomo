import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/models/app_update_manifest.dart';

void main() {
  test('parses version manifest json', () {
    final manifest = AppUpdateManifest.fromJson(const {
      'versionCode': 12,
      'versionName': '1.4.0',
      'apkUrl': 'https://example.com/app.apk',
      'changelog': 'Fixes',
    });

    expect(manifest.versionCode, 12);
    expect(manifest.versionName, '1.4.0');
    expect(manifest.apkUrl, 'https://example.com/app.apk');
    expect(manifest.changelog, 'Fixes');
    expect(manifest.isValid, isTrue);
  });

  test('rejects incomplete manifest', () {
    final manifest = AppUpdateManifest.fromJson(const {
      'versionCode': 0,
      'versionName': '',
      'apkUrl': '',
    });
    expect(manifest.isValid, isFalse);
  });
}
