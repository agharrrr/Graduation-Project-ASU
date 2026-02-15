import 'package:flutter/material.dart';

import '../Screens/event_analytics.dart';
import '../Screens/organizer_home.dart';
import '../Screens/organizer_settings.dart';

class OrganizerShellScreen extends StatefulWidget {
  const OrganizerShellScreen({super.key});

  @override
  State<OrganizerShellScreen> createState() => _OrganizerShellScreenState();
}

class _OrganizerShellScreenState extends State<OrganizerShellScreen> {
  int _index = 0;

  final _pages = const [
    OrganizerHomeScreen(embed: true),
    EventAnalyticsScreen(embed: true),
    OrganizerSettingsScreen(embed: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Analytics',
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
