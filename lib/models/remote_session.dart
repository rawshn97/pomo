import 'package:equatable/equatable.dart';

/// Represents a live focus session active on a linked remote device.
class RemoteSession extends Equatable {
  const RemoteSession({
    required this.deviceId,
    required this.deviceName,
    required this.status,
    required this.lap,
    required this.lapNumber,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.updatedAt,
    this.tagName,
    this.tagIcon,
    this.taskTitle,
  });

  factory RemoteSession.fromJson(Map<String, dynamic> json) {
    DateTime parsedUpdatedAt;
    final rawUpdated = json['updatedAt'];
    if (rawUpdated is num) {
      parsedUpdatedAt = DateTime.fromMillisecondsSinceEpoch(rawUpdated.toInt());
    } else if (rawUpdated is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdated) ?? DateTime.now();
    } else {
      parsedUpdatedAt = DateTime.now();
    }

    final remaining = (json['liveRemaining'] as num?)?.toInt() ??
        (json['remainingSeconds'] as num?)?.toInt() ??
        0;

    return RemoteSession(
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? 'Device',
      status: json['status'] as String? ?? 'running',
      lap: json['lap'] as String? ?? 'work',
      lapNumber: (json['lapNumber'] as num?)?.toInt() ?? 1,
      remainingSeconds: remaining,
      totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 0,
      tagName: json['tagName'] as String?,
      tagIcon: json['tagIcon'] as String?,
      taskTitle: json['taskTitle'] as String?,
      updatedAt: parsedUpdatedAt,
    );
  }

  RemoteSession copyWith({
    String? deviceId,
    String? deviceName,
    String? status,
    String? lap,
    int? lapNumber,
    int? remainingSeconds,
    int? totalSeconds,
    String? tagName,
    String? tagIcon,
    String? taskTitle,
    DateTime? updatedAt,
  }) {
    return RemoteSession(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      status: status ?? this.status,
      lap: lap ?? this.lap,
      lapNumber: lapNumber ?? this.lapNumber,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      tagName: tagName ?? this.tagName,
      tagIcon: tagIcon ?? this.tagIcon,
      taskTitle: taskTitle ?? this.taskTitle,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  final String deviceId;
  final String deviceName;
  final String status;
  final String lap;
  final int lapNumber;
  final int remainingSeconds;
  final int totalSeconds;
  final String? tagName;
  final String? tagIcon;
  final String? taskTitle;
  final DateTime updatedAt;

  bool get isRunning => status == 'running';

  String get formattedRemaining {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'status': status,
      'lap': lap,
      'lapNumber': lapNumber,
      'remainingSeconds': remainingSeconds,
      'totalSeconds': totalSeconds,
      'tagName': tagName,
      'tagIcon': tagIcon,
      'taskTitle': taskTitle,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  @override
  List<Object?> get props => [
        deviceId,
        deviceName,
        status,
        lap,
        lapNumber,
        remainingSeconds,
        totalSeconds,
        tagName,
        tagIcon,
        taskTitle,
        updatedAt,
      ];
}
