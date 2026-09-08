import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/pages/tasks/cubit/notion_tasks_cubit.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNotionService extends Mock implements NotionService {}

void main() {
  group('NotionTasksCubit', () {
    late MockNotionService mockNotionService;
    const testTask = NotionTask(
      id: 'task-1',
      title: 'Due Today Task',
      status: 'In Progress',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'pomo_notion_api_key': 'secret_123',
      });
      await Prefs().init();
      Prefs.notionApiKey = 'secret_123';
      mockNotionService = MockNotionService();
    });

    test('initial state is NotionTasksState()', () {
      final cubit = NotionTasksCubit(notionService: mockNotionService);
      expect(cubit.state, equals(const NotionTasksState()));
    });

    blocTest<NotionTasksCubit, NotionTasksState>(
      'fetchTasks emits failure when API key is missing',
      build: () {
        Prefs.notionApiKey = '';
        return NotionTasksCubit(notionService: mockNotionService);
      },
      act: (cubit) => cubit.fetchTasks(),
      expect: () => [
        const NotionTasksState(
          status: NotionTasksStatus.failure,
          errorMessage:
              'Please enter your Notion token or access code to browse tasks.',
        ),
      ],
    );

    blocTest<NotionTasksCubit, NotionTasksState>(
      'fetchTasks calls getTasksDueToday when activeTab is today',
      build: () {
        when(() => mockNotionService.getTasksDueToday())
            .thenAnswer((_) async => [testTask]);
        return NotionTasksCubit(notionService: mockNotionService);
      },
      act: (cubit) => cubit.fetchTasks(),
      expect: () => [
        const NotionTasksState(status: NotionTasksStatus.loading),
        const NotionTasksState(
          status: NotionTasksStatus.success,
          tasks: [testTask],
        ),
      ],
      verify: (_) {
        verify(() => mockNotionService.getTasksDueToday()).called(1);
      },
    );

    blocTest<NotionTasksCubit, NotionTasksState>(
      'setTab updates activeTab, clears query, and fetches tasks',
      build: () {
        when(() => mockNotionService.getTasksDueThisWeek())
            .thenAnswer((_) async => [testTask]);
        return NotionTasksCubit(notionService: mockNotionService);
      },
      act: (cubit) => cubit.setTab('week'),
      expect: () => [
        const NotionTasksState(activeTab: 'week'),
        const NotionTasksState(
          activeTab: 'week',
          status: NotionTasksStatus.loading,
        ),
        const NotionTasksState(
          activeTab: 'week',
          status: NotionTasksStatus.success,
          tasks: [testTask],
        ),
      ],
      verify: (_) {
        verify(() => mockNotionService.getTasksDueThisWeek()).called(1);
      },
    );

    blocTest<NotionTasksCubit, NotionTasksState>(
      'search updates searchQuery and calls searchTasks',
      build: () {
        when(() => mockNotionService.searchTasks(query: 'PARA'))
            .thenAnswer((_) async => [testTask]);
        return NotionTasksCubit(notionService: mockNotionService);
      },
      act: (cubit) => cubit.search('PARA'),
      expect: () => [
        const NotionTasksState(searchQuery: 'PARA'),
        const NotionTasksState(
          searchQuery: 'PARA',
          status: NotionTasksStatus.loading,
        ),
        const NotionTasksState(
          searchQuery: 'PARA',
          status: NotionTasksStatus.success,
          tasks: [testTask],
        ),
      ],
      verify: (_) {
        verify(() => mockNotionService.searchTasks(query: 'PARA')).called(1);
      },
    );
  });
}
