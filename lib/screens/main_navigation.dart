import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';
import '../providers/event_list_provider.dart';
import '../theme/dashly_theme.dart';
import 'home/home_screen.dart';
import 'events/explore_screen.dart';
import 'events/history_screen.dart';
import 'profile/profile_screen.dart';
import '../services/location_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    LocationService.requestPermissionsInitially();
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const HistoryScreen(), // Replaced MyEventsScreen with HistoryScreen
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 0 || index == 2) {
      context.read<EventProvider>().loadMyEvents(isSilent: true);
    } else if (index == 1) {
      context.read<EventListProvider>().loadExploreEvents(isSilent: true);
      context.read<EventListProvider>().loadMyEventsForMerge();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomAppBar(
        color: context.dashlyColors.surface,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, "Home", 0),
              _buildNavItem(Icons.explore_rounded, "Explore", 1),
              _buildNavItem(Icons.event_note_rounded, "My Event", 2),
              _buildNavItem(Icons.person_rounded, "Profile", 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? context.dashlyColors.accent : context.dashlyColors.textHint,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? context.dashlyColors.accent : context.dashlyColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
