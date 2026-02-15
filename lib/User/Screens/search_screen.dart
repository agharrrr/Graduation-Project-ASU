import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Organizer/Models/event_post.dart';
import '../Widgets/public_events_card.dart';
import '../../shared/ui/app_spacing.dart';
import '../../shared/ui/empty_state.dart';
import '../../main.dart'; // LocaleController

enum PriceFilter { all, free, paid }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _query = '';
  PriceFilter _priceFilter = PriceFilter.all;

  bool get _hasQuery => _query.trim().isNotEmpty;

  String _t(String en, String ar) {
    final isAr = context.watch<LocaleController>().isArabic;
    return isAr ? ar : en;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _eventsStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'published')
        .where('archived', isEqualTo: false)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(_t('Search', 'بحث')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(118),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Column(
              children: [
                _buildSearchField(),
                const SizedBox(height: AppSpacing.sm),
                _buildPriceFilters(t, cs),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
        child: !_hasQuery
            ? EmptyState(
          icon: Icons.search,
          title: _t('Search for events', 'ابحث عن فعاليات'),
          message: _t(
            'Type a keyword to find events by title, description, location, or category.',
            'اكتب كلمة للبحث عن الفعاليات حسب العنوان أو الوصف أو الموقع أو الفئة.',
          ),
        )
            : _buildResults(),
      ),
    );
  }

  Widget _buildSearchField() {
    final cs = Theme.of(context).colorScheme;

    return TextField(
      controller: _searchCtrl,
      onChanged: (value) => setState(() => _query = value.trim()),
      decoration: InputDecoration(
        hintText: _t('Search by title, location, category...', 'ابحث بالعنوان أو الموقع أو الفئة...'),
        prefixIcon: Icon(Icons.search, color: cs.onSurface.withAlpha(200)),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withAlpha(80),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.onSurface.withAlpha(40)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.onSurface.withAlpha(40)),
        ),
      ),
    );
  }

  Widget _buildPriceFilters(TextTheme t, ColorScheme cs) {
    Widget chip(String labelEn, String labelAr, PriceFilter value) {
      final selected = _priceFilter == value;
      return ChoiceChip(
        label: Text(_t(labelEn, labelAr)),
        selected: selected,
        onSelected: (_) => setState(() => _priceFilter = value),
        selectedColor: cs.primary.withAlpha(26),
        backgroundColor: cs.surfaceContainerHighest.withAlpha(80),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w900,
          color: selected ? cs.primary : cs.onSurface.withAlpha(210),
        ),
      );
    }

    return Row(
      children: [
        Text(
          _t('Filter:', 'فلتر:'),
          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface.withAlpha(210)),
        ),
        const SizedBox(width: 10),
        Wrap(
          spacing: 8,
          children: [
            chip('All', 'الكل', PriceFilter.all),
            chip('Free', 'مجاني', PriceFilter.free),
            chip('Paid', 'مدفوع', PriceFilter.paid),
          ],
        ),
      ],
    );
  }

  Widget _buildResults() {
    final q = _query.toLowerCase();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _eventsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: _t('Unable to search right now', 'تعذر البحث حالياً'),
            message: _t('Please check your connection and try again.', 'تحقق من الاتصال وحاول مرة أخرى.'),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return EmptyState(
            icon: Icons.event_busy_outlined,
            title: _t('No events available', 'لا توجد فعاليات'),
            message: _t('Try again later.', 'حاول لاحقاً.'),
          );
        }

        var events = docs.map((doc) => EventPost.fromMap(doc.data(), doc.id)).toList();

        if (_priceFilter != PriceFilter.all) {
          events = events.where((e) {
            if (_priceFilter == PriceFilter.free) return e.isPaid == false;
            if (_priceFilter == PriceFilter.paid) return e.isPaid == true;
            return true;
          }).toList();
        }

        events = events.where((e) {
          return e.title.toLowerCase().contains(q) ||
              e.location.toLowerCase().contains(q) ||
              e.description.toLowerCase().contains(q) ||
              e.category.toLowerCase().contains(q);
        }).toList();

        if (events.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_outlined,
            title: _t('No matches', 'لا توجد نتائج'),
            message: _t(
              'Try different keywords or change Paid/Free filter.',
              'جرّب كلمات مختلفة أو غيّر فلتر مجاني/مدفوع.',
            ),
          );
        }

        events.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

        return ListView.separated(
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => PublicEventsCard(event: events[index]),
        );
      },
    );
  }
}
