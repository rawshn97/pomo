import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/pages/settings/settings.dart';
import 'package:pomo/pages/timer/timer.dart';
import 'package:pomo/pages/tracker/tracker.dart';
import 'package:pomo/services/app_navigation_controller.dart';
import 'package:pomo/theme/rawshn_brand.dart';
import 'package:pomo/widgets/brand/status_strip.dart';

/// Top-level application shell with tab switcher encapsulating Pomodoro,
/// Time Log history, and Settings without losing state.
class HomeShell extends StatefulWidget {
  const HomeShell({this.initialIndex = 0, super.key});

  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _selectedIndex;

  final List<Widget> _pages = const [
    TimerPage(),
    TrackerShellPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    AppNavigationController.instance.currentTabIndex.value = _selectedIndex;
    AppNavigationController.instance.tabIndex.addListener(_onNavRequest);
  }

  @override
  void dispose() {
    AppNavigationController.instance.tabIndex.removeListener(_onNavRequest);
    super.dispose();
  }

  void _setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
    AppNavigationController.instance.currentTabIndex.value = index;
  }

  void _onNavRequest() {
    final index = AppNavigationController.instance.tabIndex.value;
    if (index == null || !mounted) {
      return;
    }
    if (index != _selectedIndex) {
      _setSelectedIndex(index);
    }
    // Clear so the same tab can be requested again later.
    AppNavigationController.instance.tabIndex.value = null;
  }

  void _onDestinationSelected(int index) {
    _setSelectedIndex(index);
  }

  Widget _shellBody() {
    return Column(
      children: [
        BlocBuilder<TimerCubit, TimerState>(
          buildWhen: (previous, current) => previous.lap != current.lap,
          builder: (context, timerState) {
            return StatusStrip(
              path: RawshnBrand.statusPath(
                tabIndex: _selectedIndex,
                lap: timerState.lap,
              ),
            );
          },
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWideScreen = width >= 800;

    if (isWideScreen) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.timer_outlined),
                  selectedIcon: Icon(Icons.timer),
                  label: Text('Focus'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: Text('Tracker'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _shellBody()),
          ],
        ),
      );
    }

    return Scaffold(
      body: _shellBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Focus',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Tracker',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
