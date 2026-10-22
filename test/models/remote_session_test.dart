import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/models/remote_session.dart';

void main() {
  group('RemoteSession', () {
    test('serializes and deserializes correctly', () {
      final session = RemoteSession(
        deviceId: 'dev_123',
        deviceName: 'Mobile',
        status: 'running',
        lap: 'work',
        lapNumber: 2,
        remainingSeconds: 1445,
        totalSeconds: 1500,
        tagName: 'Coding & Dev',
        tagIcon: '💻',
        taskTitle: 'Feature Implementation',
        updatedAt: DateTime(2026, 10, 21, 10, 30),
      );

      final json = session.toJson();
      expect(json['deviceId'], equals('dev_123'));
      expect(json['deviceName'], equals('Mobile'));
      expect(json['remainingSeconds'], equals(1445));
      expect(json['tagName'], equals('Coding & Dev'));
      expect(json['tagIcon'], equals('💻'));

      final fromJson = RemoteSession.fromJson(json);
      expect(fromJson.deviceId, equals(session.deviceId));
      expect(fromJson.deviceName, equals(session.deviceName));
      expect(fromJson.status, equals(session.status));
      expect(fromJson.lap, equals(session.lap));
      expect(fromJson.lapNumber, equals(session.lapNumber));
      expect(fromJson.remainingSeconds, equals(session.remainingSeconds));
      expect(fromJson.tagName, equals(session.tagName));
      expect(fromJson.tagIcon, equals(session.tagIcon));
      expect(fromJson.taskTitle, equals(session.taskTitle));
      expect(fromJson.isRunning, isTrue);
      expect(fromJson.formattedRemaining, equals('24:05'));
    });

    test('handles null tags and tasks gracefully', () {
      final json = {
        'deviceId': 'dev_456',
        'deviceName': 'macOS',
        'status': 'paused',
        'lap': 'shortBreak',
        'lapNumber': 1,
        'remainingSeconds': 300,
        'totalSeconds': 300,
      };

      final session = RemoteSession.fromJson(json);
      expect(session.deviceId, equals('dev_456'));
      expect(session.deviceName, equals('macOS'));
      expect(session.isRunning, isFalse);
      expect(session.tagName, isNull);
      expect(session.taskTitle, isNull);
      expect(session.formattedRemaining, equals('05:00'));
    });
    test('handles ISO-8601 updatedAt string and liveRemaining precedence', () {
      final json = {
        'deviceId': 'dev_cf_1',
        'deviceName': 'macOS',
        'status': 'running',
        'lap': 'work',
        'lapNumber': 3,
        'remainingSeconds': 1500,
        'liveRemaining': 1234,
        'totalSeconds': 1500,
        'tagName': 'System Building',
        'tagIcon': '⏰',
        'updatedAt': '2026-10-21T11:21:03.416Z',
      };

      final session = RemoteSession.fromJson(json);
      expect(session.deviceId, equals('dev_cf_1'));
      expect(session.remainingSeconds, equals(1234));
      expect(session.formattedRemaining, equals('20:34'));
      expect(session.updatedAt.isUtc, isTrue);

      final decremented = session.copyWith(
        remainingSeconds: session.remainingSeconds - 1,
      );
      expect(decremented.remainingSeconds, equals(1233));
      expect(decremented.formattedRemaining, equals('20:33'));
    });

    test('reconstructs NotionTask and multiple tags from payload', () {
      final json = {
        'deviceId': 'dev_test_task',
        'deviceName': 'macOS',
        'status': 'running',
        'lap': 'work',
        'lapNumber': 1,
        'remainingSeconds': 1200,
        'totalSeconds': 1500,
        'taskId': 'task_notion_99',
        'taskTitle': 'Fix Takeover Bug',
        'taskJson': '{"id":"task_notion_99","title":"Fix Takeover Bug",'
            '"status":"In Progress","projectTitle":"Pomo"}',
        'tags': [
          {
            'id': 'tag_1',
            'name': 'System Building',
            'icon': '⏰',
            'colorHex': '#00F0FF',
          },
          {
            'id': 'tag_2',
            'name': 'Deep Focus',
            'icon': '🧠',
            'colorHex': '#A855F7',
          },
        ],
        'updatedAt': '2026-10-22T14:40:00.000Z',
      };

      final session = RemoteSession.fromJson(json);
      expect(session.task, isNotNull);
      expect(session.task!.id, equals('task_notion_99'));
      expect(session.task!.title, equals('Fix Takeover Bug'));
      expect(session.task!.status, equals('In Progress'));
      expect(session.task!.projectTitle, equals('Pomo'));
      expect(session.tags.length, equals(2));
      expect(session.tags[0].name, equals('System Building'));
      expect(session.tags[1].name, equals('Deep Focus'));
    });
  });
}
