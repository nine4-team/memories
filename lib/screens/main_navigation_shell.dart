import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/providers/capture_state_provider.dart';
import 'package:memories/screens/capture/capture_screen.dart';
import 'package:memories/screens/timeline/unified_timeline_screen.dart';
import 'package:memories/screens/settings/settings_screen.dart';
import 'package:memories/providers/main_navigation_provider.dart';

/// Main navigation shell that provides bottom navigation between main app screens
/// 
/// Provides navigation between:
/// - Capture screen (default)
/// - Timeline screen
/// - Settings screen
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  final List<Widget> _screens = const [
    CaptureScreen(),
    UnifiedTimelineScreen(),
    SettingsScreen(),
  ];
  MainNavigationTab? _lastSelectedTab;

  int _getTabIndex(MainNavigationTab tab) {
    switch (tab) {
      case MainNavigationTab.capture:
        return 0;
      case MainNavigationTab.timeline:
        return 1;
      case MainNavigationTab.settings:
        return 2;
    }
  }

  MainNavigationTab _getTabFromIndex(int index) {
    switch (index) {
      case 0:
        return MainNavigationTab.capture;
      case 1:
        return MainNavigationTab.timeline;
      case 2:
        return MainNavigationTab.settings;
      default:
        return MainNavigationTab.capture;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(mainNavigationTabNotifierProvider);
    final currentIndex = _getTabIndex(selectedTab);

    if (_lastSelectedTab != selectedTab) {
      if (selectedTab == MainNavigationTab.capture) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(captureStateNotifierProvider.notifier)
              .captureLocation()
              .catchError((e) {
            debugPrint(
                '[MainNavigationShell] Failed to refresh capture location: $e');
          });
        });
      }
      _lastSelectedTab = selectedTab;
    }

    return Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: _screens,
        ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Stack(
          children: [
            NavigationBar(
              backgroundColor: const Color(0xFFF5F5F5), // Match scaffold background
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                final tab = _getTabFromIndex(index);
                ref.read(mainNavigationTabNotifierProvider.notifier).setTab(tab);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.camera_alt_outlined),
                  selectedIcon: Icon(Icons.camera_alt),
                  label: 'Capture',
                ),
                NavigationDestination(
                  icon: Icon(Icons.timeline_outlined),
                  selectedIcon: Icon(Icons.timeline),
                  label: 'Timeline',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          // Custom top border indicator for selected item
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / 3;
                  final indicatorWidth = itemWidth * 0.5; // 50% of item width
                  final indicatorLeft = (currentIndex * itemWidth) + (itemWidth * 0.25); // Center it
                  
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        left: indicatorLeft,
                        top: 0,
                        width: indicatorWidth,
                        height: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B2B2B),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

