import 'package:equatable/equatable.dart';

/// Remote update metadata served from the Vercel OTA manifest URL.
class AppUpdateManifest extends Equatable {
  const AppUpdateManifest({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    this.changelog = '',
  });

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    final rawCode = json['versionCode'];
    final versionCode = switch (rawCode) {
      final int value => value,
      final String value => int.tryParse(value) ?? 0,
      final num value => value.toInt(),
      _ => 0,
    };
    return AppUpdateManifest(
      versionCode: versionCode,
      versionName: (json['versionName'] as String?)?.trim() ?? '',
      apkUrl: (json['apkUrl'] as String?)?.trim() ?? '',
      changelog: (json['changelog'] as String?)?.trim() ?? '',
    );
  }

  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String changelog;

  bool get isValid =>
      versionCode > 0 && versionName.isNotEmpty && apkUrl.isNotEmpty;

  @override
  List<Object?> get props => [versionCode, versionName, apkUrl, changelog];
}
