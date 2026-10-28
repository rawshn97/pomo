part of 'notion_tasks_cubit.dart';

enum NotionTasksStatus {
  initial,
  loading,
  success,
  failure,
}

class NotionTasksState extends Equatable {
  const NotionTasksState({
    this.status = NotionTasksStatus.initial,
    this.tasks = const [],
    this.activeTab = 'tasks',
    this.searchQuery = '',
    this.errorMessage,
  });

  final NotionTasksStatus status;
  final List<NotionTask> tasks;
  final String activeTab;
  final String searchQuery;
  final String? errorMessage;

  NotionTasksState copyWith({
    NotionTasksStatus Function()? status,
    List<NotionTask> Function()? tasks,
    String Function()? activeTab,
    String Function()? searchQuery,
    String? Function()? errorMessage,
  }) {
    return NotionTasksState(
      status: status != null ? status() : this.status,
      tasks: tasks != null ? tasks() : this.tasks,
      activeTab: activeTab != null ? activeTab() : this.activeTab,
      searchQuery: searchQuery != null ? searchQuery() : this.searchQuery,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tasks,
        activeTab,
        searchQuery,
        errorMessage,
      ];
}
