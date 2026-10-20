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
    return RemoteSession(
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? 'Device',
      status: json['status'] as String? ?? 'running',
      lap: json['lap'] as String? ?? 'work',
      lapNumber: (json['lapNumber'] as num?)?.toInt() ?? 1,
      remainingSeconds: (json['remainingSeconds'] as num?)?.toInt() ?? 0,
      totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 0,
      tagName: json['tagName'] as String?,
      tagIcon: json['tagIcon'] as String?,
      taskTitle: json['taskTitle'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['updatedAt'] as num).toInt(),
            )
          : DateTime.now(),
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
