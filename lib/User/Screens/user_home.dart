import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Organizer/Models/event_post.dart';
import '../Widgets/public_events_card.dart';
import '../../shared/ui/empty_state.dart';
import '../../shared/ui/app_spacing.dart';
import '../../main.dart'; // LocaleController

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  bool _loadingPrefs = true;

  List<String> _preferredCategories = [];
  List<String> _favoriteOrganizerIds = [];

  String? _city;
  String? _selectedCategory;

  // Master list (used everywhere: onboarding + filters + events)
  static const List<String> _allCategories = [
    'Concert',
    'Workshop',
    'Conference',
    'Sports',
    'Party',
    'Course',
    'Entertainment',
    'Musical',
    'Technology',
    'Art',
    'Other',
  ];

  String _t(String en, String ar) {
    final isAr = context.watch<LocaleController>().isArabic;
    return isAr ? ar : en;
  }

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _loadingPrefs = false);
        return;
      }

      final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = snap.data();

      if (data != null) {
        final cats = data['preferredCategories'];
        final favs = data['favoriteOrganizerIds'];
        final city = data['city'];

        final cityStr = (city ?? '').toString().trim();
        _city = cityStr.isEmpty ? null : cityStr;

        _preferredCategories = cats is List
            ? cats
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
            : <String>[];

        _favoriteOrganizerIds = favs is List
            ? favs
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
            : <String>[];
      }
    } catch (_) {
      // do not block UX
    } finally {
      if (mounted) setState(() => _loadingPrefs = false);
    }
  }

  List<String> get _chipCategories {
    // Merge: all categories + preferred (so if you add new categories later, it still shows)
    final merged = <String>{};
    for (final c in _allCategories) {
      final v = c.trim();
      if (v.isNotEmpty) merged.add(v);
    }
    for (final c in _preferredCategories) {
      final v = c.trim();
      if (v.isNotEmpty) merged.add(v);
    }

    // Stable order: keep master order, then any extra (if exists)
    final ordered = <String>[];
    for (final c in _allCategories) {
      if (merged.contains(c)) ordered.add(c);
    }
    final extras = merged.difference(_allCategories.toSet()).toList()..sort();
    ordered.addAll(extras);

    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primary.withAlpha(26),
              child: Icon(Icons.question_mark_rounded, size: 16, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Text(
              'ShooFi?',
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.2),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('For you', 'مقترحات لك'), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                if (_city != null)
                  Text(
                    _t('Based on your city: $_city', 'حسب مدينتك: $_city'),
                    style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(170)),
                  ),
              ],
            ),
          ),
          _buildCategoryChips(),
          const SizedBox(height: AppSpacing.xs),
          Expanded(child: _buildEventsStream()),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = _chipCategories;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: Text(_t('All', 'الكل')),
              selected: _selectedCategory == null,
              onSelected: (_) => setState(() => _selectedCategory = null),
              selectedColor: cs.primary.withAlpha(26),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w900,
                color: _selectedCategory == null ? cs.primary : cs.onSurface.withAlpha(210),
              ),
              backgroundColor: cs.surfaceContainerHighest.withAlpha(80),
            ),
          ),
          ...categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
                selectedColor: cs.primary.withAlpha(26),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isSelected ? cs.primary : cs.onSurface.withAlpha(210),
                ),
                backgroundColor: cs.surfaceContainerHighest.withAlpha(80),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildEventsStream() {
    final now = DateTime.now();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'published')
          .where('archived', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _loadingPrefs) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: _t('Something went wrong', 'حدث خطأ'),
            message: _t(
              'We could not load events right now. Please try again.',
              'تعذر تحميل الفعاليات حالياً. حاول مرة أخرى.',
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return EmptyState(
            icon: Icons.event_busy_outlined,
            title: _t('No events yet', 'لا توجد فعاليات بعد'),
            message: _t(
              'Check back soon — new events are added all the time.',
              'عد لاحقاً — تتم إضافة فعاليات باستمرار.',
            ),
          );
        }

        var events = docs.map((doc) => EventPost.fromMap(doc.data(), doc.id)).toList();

        // 1) Hide past events from the FEED
        events = events.where((e) => e.endDateTime.isAfter(now)).toList();

        // 2) City-based filter
        if (_city != null && _city!.isNotEmpty) {
          final cityLower = _city!.trim().toLowerCase();
          events = events.where((e) {
            final eventCity = (e.city ?? '').toString().trim();
            if (eventCity.isNotEmpty) {
              return eventCity.toLowerCase() == cityLower;
            }
            return e.location.toLowerCase().contains(cityLower);
          }).toList();
        }

        // 3) Preference-based filtering (categories + favorites) ✅ FIXED
        // Keep event if it matches ANY of:
        // - preferred category (if user has categories)
        // - favorite organizer (if user has favorites)
        final hasCats = _preferredCategories.isNotEmpty;
        final hasFavs = _favoriteOrganizerIds.isNotEmpty;

        if (hasCats || hasFavs) {
          // Normalize categories for case-insensitive matching
          final preferredLower = _preferredCategories.map((c) => c.toLowerCase()).toSet();
          final favSet = _favoriteOrganizerIds.toSet();

          events = events.where((e) {
            final matchCat = hasCats && preferredLower.contains(e.category.trim().toLowerCase());
            final matchFav = hasFavs && favSet.contains(e.organizerId);
            return matchCat || matchFav;
          }).toList();
        }

        // 4) Chip selection
        if (_selectedCategory != null) {
          final selectedLower = _selectedCategory!.trim().toLowerCase();
          events = events.where((e) => e.category.trim().toLowerCase() == selectedLower).toList();
        }

        events.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

        if (events.isEmpty) {
          return EmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: _t('No matching events', 'لا توجد فعاليات مناسبة'),
            message: _t(
              'Try changing your category or preferences to discover more.',
              'جرّب تغيير الفئة أو التفضيلات لاكتشاف المزيد.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => PublicEventsCard(event: events[index]),
        );
      },
    );
  }
}
