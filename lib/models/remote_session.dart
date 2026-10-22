import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/models/tracker_tag.dart';

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
    this.tagColorHex,
    this.tagId,
    this.taskTitle,
    this.taskId,
    this.taskJson,
    this.tags = const [],
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

    final rawTags = json['tags'];
    final parsedTags = <TrackerTag>[];
    if (rawTags is List) {
      for (final item in rawTags) {
        if (item is Map<String, dynamic>) {
          parsedTags.add(TrackerTag.fromJson(item));
        } else if (item is Map) {
          parsedTags.add(TrackerTag.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    } else if (json['tagName'] != null &&
        (json['tagName'] as String).trim().isNotEmpty) {
      parsedTags.add(
        TrackerTag(
          id: json['tagId'] as String? ?? 'tag_${json['tagName']}',
          name: json['tagName'] as String,
          icon: json['tagIcon'] as String? ?? '⏱️',
          colorHex: json['tagColorHex'] as String? ?? '#00F0FF',
        ),
      );
    }

    String? parsedTaskJson;
    if (json['taskJson'] is String && (json['taskJson'] as String).isNotEmpty) {
      parsedTaskJson = json['taskJson'] as String;
    } else if (json['task'] is Map) {
      parsedTaskJson = jsonEncode(json['task']);
    }

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
      tagColorHex: json['tagColorHex'] as String?,
      tagId: json['tagId'] as String?,
      taskTitle: json['taskTitle'] as String?,
      taskId: json['taskId'] as String?,
      taskJson: parsedTaskJson,
      tags: parsedTags,
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
    String? tagColorHex,
    String? tagId,
    String? taskTitle,
    String? taskId,
    String? taskJson,
    List<TrackerTag>? tags,
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
      tagColorHex: tagColorHex ?? this.tagColorHex,
      tagId: tagId ?? this.tagId,
      taskTitle: taskTitle ?? this.taskTitle,
      taskId: taskId ?? this.taskId,
      taskJson: taskJson ?? this.taskJson,
      tags: tags ?? this.tags,
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
  final String? tagColorHex;
  final String? tagId;
  final String? taskTitle;
  final String? taskId;
  final String? taskJson;
  final List<TrackerTag> tags;
  final DateTime updatedAt;

  bool get isRunning => status == 'running';

  /// Reconstructs the active [NotionTask] from the remote payload.
  NotionTask? get task {
    if (taskJson != null && taskJson!.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(taskJson!) as Map<String, dynamic>;
        return NotionTask.fromJson(decoded);
      } catch (_) {}
    }
    if (taskTitle != null && taskTitle!.trim().isNotEmpty) {
      return NotionTask(
        id: taskId ?? 'remote_${taskTitle.hashCode}',
        title: taskTitle!.trim(),
      );
    }
    return null;
  }

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
      'tagColorHex': tagColorHex,
      'tagId': tagId,
      'taskTitle': taskTitle,
      'taskId': taskId,
      'taskJson': taskJson,
      'tags': tags.map((t) => t.toJson()).toList(),
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
        tagColorHex,
        tagId,
        taskTitle,
        taskId,
        taskJson,
        tags,
        updatedAt,
      ];
}
