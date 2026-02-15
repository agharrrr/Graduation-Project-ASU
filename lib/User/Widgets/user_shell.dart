import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shoo_fi/User/Screens/search_screen.dart';
import 'package:shoo_fi/User/Screens/user_bookings.dart';
import 'package:shoo_fi/User/Screens/user_home.dart';
import 'package:shoo_fi/User/Screens/user_profile.dart';

// IMPORTANT: import the actual onboarding widget you want to push
import 'package:shoo_fi/User/Services/user_onboarding_categories.dart';

import '../../main.dart'; // LocaleController

class UserShellScreen extends StatefulWidget {
  const UserShellScreen({super.key});

  @override
  State<UserShellScreen> createState() => _UserShellScreenState();
}

class _UserShellScreenState extends State<UserShellScreen> {
  int _currentIndex = 0;

  bool _onboardingPushed = false;

  final List<Widget> _pages = const [
    UserHomeScreen(),
    SearchScreen(),
    UserBookingsScreen(),
    UserProfileScreen(),
  ];

  String _t(String en, String ar) {
    // Safe read of LocaleController. If provider is missing, default to English.
    try {
      final isAr = context.watch<LocaleController>().isArabic;
      return isAr ? ar : en;
    } catch (_) {
      return en;
    }
  }

  @override
  void initState() {
    super.initState();

    // Run after first frame so navigation is safe (prevents blank screen / loops on web).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureUserPrefs();
    });
  }

  bool _needsOnboardingFrom(Map<String, dynamic> data) {
    final onboardingCompleted = (data['onboardingCompleted'] == true);

    final catsRaw = data['preferredCategories'];
    final cats = (catsRaw is List)
        ? catsRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    final city = (data['city'] ?? '').toString().trim();

    // ✅ The agreed fix: route to onboarding unless completed + has prefs + has city
    if (!onboardingCompleted) return true;
    if (cats.isEmpty) return true;
    if (city.isEmpty) return true;

    return false;
  }

  Future<void> _ensureUserPrefs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_onboardingPushed) return;

    try {
      final snap =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = snap.data() ?? <String, dynamic>{};

      final needsOnboarding = _needsOnboardingFrom(data);

      if (needsOnboarding) {
        _onboardingPushed = true;

        if (!mounted) return;
        final done = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const UserOnboardingCategories()),
        );

        // If they saved, force Home tab
        if (done == true && mounted) {
          setState(() => _currentIndex = 0);
        }

        // Allow future checks if user backed out without completing
        _onboardingPushed = false;
      }
    } catch (_) {
      // don't block user
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: _t('Home', 'الرئيسية'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.search),
            label: _t('Search', 'بحث'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.confirmation_num_outlined),
            selectedIcon: const Icon(Icons.confirmation_num),
            label: _t('Bookings', 'الحجوزات'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: _t('Profile', 'الملف'),
          ),
        ],
      ),
    );
  }
}
