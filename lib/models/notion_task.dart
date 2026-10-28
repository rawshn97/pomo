import 'package:equatable/equatable.dart';

class NotionTask extends Equatable {
  const NotionTask({
    required this.id,
    required this.title,
    this.status = 'To Do',
    this.priority = '',
    this.due,
    this.projectId,
    this.projectTitle,
    this.timeHours = 0,
    this.timeMinutes = 0,
    this.isArchived = false,
  });

  factory NotionTask.fromJson(Map<String, dynamic> json) {
    return NotionTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'To Do',
      priority: json['priority'] as String? ?? '',
      due: json['due'] != null && (json['due'] as String).isNotEmpty
          ? DateTime.tryParse(json['due'] as String)
          : null,
      projectId: json['projectId'] as String?,
      projectTitle: json['projectTitle'] as String?,
      timeHours: json['timeHours'] as int? ?? 0,
      timeMinutes: json['timeMinutes'] as int? ?? 0,
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }

  /// Parses a raw Notion API page object into a [NotionTask].
  factory NotionTask.fromNotionApi(Map<String, dynamic> page) {
    final id = page['id'] as String? ?? '';
    final props = page['properties'] as Map<String, dynamic>? ?? {};

    // Name / title
    var title = 'Untitled Task';
    final nameProp = props['Name'] as Map<String, dynamic>?;
    if (nameProp != null && nameProp['title'] is List) {
      final titleList = nameProp['title'] as List;
      if (titleList.isNotEmpty && titleList.first is Map) {
        final textMap = (titleList.first as Map)['text'] as Map?;
        if (textMap != null && textMap['content'] is String) {
          title = textMap['content'] as String;
        }
      }
    }

    // Done status or Status property
    var status = 'To Do';
    final doneProp = props['Done'] as Map<String, dynamic>?;
    if (doneProp != null && doneProp['status'] is Map) {
      status = (doneProp['status'] as Map)['name'] as String? ?? 'To Do';
    }
    final statusProp = props['Status'] as Map<String, dynamic>?;
    if (statusProp != null && statusProp['status'] is Map) {
      status = (statusProp['status'] as Map)['name'] as String? ?? status;
    }

    // Priority or Project marker
    var priority = '';
    final prioProp = props['Priority'] as Map<String, dynamic>?;
    if (prioProp != null && prioProp['select'] is Map) {
      priority = (prioProp['select'] as Map)['name'] as String? ?? '';
    }
    if (priority.isEmpty && statusProp != null) {
      priority = 'Project';
    }

    // Due date
    DateTime? due;
    final dueProp = props['Due'] as Map<String, dynamic>?;
    if (dueProp != null && dueProp['date'] is Map) {
      final startStr = (dueProp['date'] as Map)['start'] as String?;
      if (startStr != null && startStr.isNotEmpty) {
        due = DateTime.tryParse(startStr);
      }
    }

    // Project relation & inline title extraction (from rollups/formulas/rich_text)
    String? projectId;
    final projProp = props['Project'] as Map<String, dynamic>?;
    if (projProp != null && projProp['relation'] is List) {
      final relList = projProp['relation'] as List;
      if (relList.isNotEmpty && relList.first is Map) {
        projectId = (relList.first as Map)['id'] as String?;
      }
    }

    String? projectTitle;
    for (final entry in props.entries) {
      final key = entry.key.toLowerCase();
      if ((key.contains('project') ||
              key.contains('parent') ||
              key.contains('rollup')) &&
          key != 'project') {
        final prop = entry.value;
        if (prop is! Map) continue;
        final type = prop['type'] as String?;
        if (type == 'rollup' && prop['rollup'] is Map) {
          final array = (prop['rollup'] as Map)['array'] as List?;
          if (array != null && array.isNotEmpty && array.first is Map) {
            final first = array.first as Map;
            if (first['type'] == 'title' &&
                first['title'] is List &&
                (first['title'] as List).isNotEmpty) {
              final item = (first['title'] as List).first as Map?;
              projectTitle = item?['plain_text'] as String? ??
                  (item?['text'] as Map?)?['content'] as String?;
            } else if (first['type'] == 'rich_text' &&
                first['rich_text'] is List &&
                (first['rich_text'] as List).isNotEmpty) {
              final item = (first['rich_text'] as List).first as Map?;
              projectTitle = item?['plain_text'] as String? ??
                  (item?['text'] as Map?)?['content'] as String?;
            }
          }
        } else if (type == 'formula' && prop['formula'] is Map) {
          if ((prop['formula'] as Map)['type'] == 'string') {
            projectTitle = (prop['formula'] as Map)['string'] as String?;
          }
        } else if (type == 'rich_text' &&
            prop['rich_text'] is List &&
            (prop['rich_text'] as List).isNotEmpty) {
          final item = (prop['rich_text'] as List).first as Map?;
          projectTitle = item?['plain_text'] as String? ??
              (item?['text'] as Map?)?['content'] as String?;
        }
      }
      if (projectTitle != null &&
          projectTitle.isNotEmpty &&
          !projectTitle.startsWith('Project ')) {
        break;
      }
    }

    // Time (hours) & Time (minutes)
    var timeHours = 0;
    final hoursProp = props['Time (hours)'] as Map<String, dynamic>?;
    if (hoursProp != null && hoursProp['number'] is num) {
      timeHours = (hoursProp['number'] as num).toInt();
    }

    var timeMinutes = 0;
    final minsProp = props['Time (minutes)'] as Map<String, dynamic>?;
    if (minsProp != null && minsProp['number'] is num) {
      timeMinutes = (minsProp['number'] as num).toInt();
    }

    var isArchived = false;
    final archProp = props['Archive'] as Map<String, dynamic>?;
    if (archProp != null && archProp['checkbox'] == true) {
      isArchived = true;
    }
    if (status.toLowerCase() == 'done' || status.toLowerCase() == 'archived') {
      isArchived = true;
    }

    return NotionTask(
      id: id,
      title: title,
      status: status,
      priority: priority,
      due: due,
      projectId: projectId,
      projectTitle: projectTitle,
      timeHours: timeHours,
      timeMinutes: timeMinutes,
      isArchived: isArchived,
    );
  }

  final String id;
  final String title;
  final String status;
  final String priority;
  final DateTime? due;
  final String? projectId;
  final String? projectTitle;
  final int timeHours;
  final int timeMinutes;
  final bool isArchived;

  int get timeTotalMin => timeHours * 60 + timeMinutes;

  String get timeLoggedFormatted {
    if (timeHours == 0 && timeMinutes == 0) {
      return '0m';
    }
    if (timeHours == 0) {
      return '${timeMinutes}m';
    }
    if (timeMinutes == 0) {
      return '${timeHours}h';
    }
    return '${timeHours}h ${timeMinutes}m';
  }

  NotionTask copyWith({
    String Function()? id,
    String Function()? title,
    String Function()? status,
    String Function()? priority,
    DateTime? Function()? due,
    String? Function()? projectId,
    String? Function()? projectTitle,
    int Function()? timeHours,
    int Function()? timeMinutes,
    bool Function()? isArchived,
  }) {
    return NotionTask(
      id: id != null ? id() : this.id,
      title: title != null ? title() : this.title,
      status: status != null ? status() : this.status,
      priority: priority != null ? priority() : this.priority,
      due: due != null ? due() : this.due,
      projectId: projectId != null ? projectId() : this.projectId,
      projectTitle: projectTitle != null ? projectTitle() : this.projectTitle,
      timeHours: timeHours != null ? timeHours() : this.timeHours,
      timeMinutes: timeMinutes != null ? timeMinutes() : this.timeMinutes,
      isArchived: isArchived != null ? isArchived() : this.isArchived,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status,
      'priority': priority,
      'due': due?.toIso8601String(),
      'projectId': projectId,
      'projectTitle': projectTitle,
      'timeHours': timeHours,
      'timeMinutes': timeMinutes,
      'isArchived': isArchived,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        status,
        priority,
        due,
        projectId,
        projectTitle,
        timeHours,
        timeMinutes,
        isArchived,
      ];
}
