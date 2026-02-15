import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shoo_fi/Organizer/organizer_controller.dart';
import '../Models/event_post.dart';

import '../../shared/ui/app_spacing.dart';
import '../../shared/ui/empty_state.dart';

class EventAnalyticsScreen extends StatelessWidget {
  final bool embed;
  const EventAnalyticsScreen({super.key, this.embed = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final controller = context.watch<OrganizerController>();
    final events = controller.events;

    final total = events.length;
    final published = events.where((e) => e.status == EventStatus.published).length;
    final draft = events.where((e) => e.status == EventStatus.draft).length;
    final archived = events.where((e) => e.archived == true).length;

    final topByBookings = [...events]..sort((a, b) => b.bookingsCount.compareTo(a.bookingsCount));
    final top3 = topByBookings.take(3).toList();

    final content = SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Text(
                'Analytics',
                style: t.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Icon(Icons.insights_outlined, color: cs.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A quick overview of your event activity.',
            style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(170)),
          ),
          const SizedBox(height: AppSpacing.md),

          LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth >= 520;
              final crossAxisCount = isWide ? 4 : 2;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: isWide ? 1.25 : 1.45,
                children: [
                  _KpiCard(title: 'Total', value: total.toString(), icon: Icons.event_note_outlined),
                  _KpiCard(title: 'Published', value: published.toString(), icon: Icons.public_outlined, tone: _Tone.good),
                  _KpiCard(title: 'Draft', value: draft.toString(), icon: Icons.edit_note_outlined, tone: _Tone.warn),
                  _KpiCard(title: 'Archived', value: archived.toString(), icon: Icons.inventory_2_outlined, tone: _Tone.neutral),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            'Top events (by bookings)',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),

          if (events.isEmpty)
            const EmptyState(
              icon: Icons.query_stats_outlined,
              title: 'No data yet',
              message: 'Create events to start seeing analytics here.',
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    for (int i = 0; i < top3.length; i++) ...[
                      _TopEventRow(
                        index: i + 1,
                        title: top3[i].title,
                        bookings: top3[i].bookingsCount,
                        capacity: top3[i].capacity,
                        status: top3[i].status,
                      ),
                      if (i != top3.length - 1) const Divider(height: 18),
                    ],
                    if (events.length > 3) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Showing top 3. Total events: $total',
                          style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(170)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    if (embed) return content;

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: content,
    );
  }
}

enum _Tone { good, warn, neutral }

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final _Tone tone;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    this.tone = _Tone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    Color accent;
    switch (tone) {
      case _Tone.good:
        accent = cs.primary;
        break;
      case _Tone.warn:
        accent = cs.tertiary;
        break;
      case _Tone.neutral:
        accent = cs.primary;
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withAlpha(22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const Spacer(),
            Text(
              title,
              style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(170), fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: t.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopEventRow extends StatelessWidget {
  final int index;
  final String title;
  final int bookings;
  final int capacity;
  final EventStatus status;

  const _TopEventRow({
    required this.index,
    required this.title,
    required this.bookings,
    required this.capacity,
    required this.status,
  });

  String get _statusText {
    switch (status) {
      case EventStatus.published:
        return 'Published';
      case EventStatus.draft:
        return 'Draft';
      case EventStatus.archived:
        return 'Archived';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final cap = capacity <= 0 ? null : capacity;
    final ratio = (cap == null) ? null : (bookings / cap).clamp(0.0, 1.0);

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary.withAlpha(18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$index',
            style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? 'Untitled event' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _Pill(icon: Icons.people_outline, text: cap == null ? '$bookings booked' : '$bookings/$cap booked'),
                  _Pill(icon: Icons.circle, text: _statusText),
                ],
              ),
              if (ratio != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 7,
                    backgroundColor: cs.onSurface.withAlpha(14),
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withAlpha(14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: t.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w900, color: cs.onSurface.withAlpha(210)),
          ),
        ],
      ),
    );
  }
}
