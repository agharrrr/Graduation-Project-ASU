import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

import 'package:shoo_fi/User/Widgets/user_repository.dart';
import '../../shared/ui/app_spacing.dart';
import '../../shared/ui/empty_state.dart';
import '../../shared/app_dialog.dart';

class UserBookingsScreen extends StatelessWidget {
  const UserBookingsScreen({super.key});

  String _statusLabel(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('confirmed')) return 'Confirmed';
    if (s.contains('cancel')) return 'Cancelled';
    if (s.contains('reject')) return 'Rejected';
    if (s.contains('pending')) return 'Pending';
    return raw.isEmpty ? 'Pending' : raw;
  }

  bool _canCancel(String statusLabel) {
    final s = statusLabel.toLowerCase();
    return s == 'pending' || s == 'confirmed';
  }

  bool _canAddToCalendar(String statusLabel) {
    final s = statusLabel.toLowerCase();
    if (s.contains('cancel') || s.contains('reject')) return false;
    return s.contains('confirmed');
  }

  DateTime? _readTs(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }

  bool _isPastBooking(Map<String, dynamic> data, DateTime now) {
    final end = _readTs(data['endDateTime']);
    if (end != null) return !end.isAfter(now);

    final start = _readTs(data['startDateTime']);
    if (start != null) {
      return start.isBefore(now.subtract(const Duration(hours: 12)));
    }

    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status.contains('cancel') || status.contains('reject')) return true;

    return false;
  }

  Future<Map<String, dynamic>> _fetchEventIfNeeded(String eventId) async {
    if (eventId.trim().isEmpty) return <String, dynamic>{};
    final snap = await FirebaseFirestore.instance.collection('events').doc(eventId.trim()).get();
    return snap.data() ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _fetchOrganizerIfNeeded(String organizerId) async {
    if (organizerId.trim().isEmpty) return <String, dynamic>{};
    final snap =
    await FirebaseFirestore.instance.collection('organizers').doc(organizerId.trim()).get();
    return snap.data() ?? <String, dynamic>{};
  }

  // -----------------------
  // Money helpers
  // -----------------------
  double? _readNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      // extract first number from a string like "12 JD" or "12.50"
      final m = RegExp(r'(\d+(\.\d+)?)').firstMatch(s);
      if (m == null) return null;
      return double.tryParse(m.group(1)!);
    }
    return null;
  }

  String _fmtJd(double v) => '${v.toStringAsFixed(2)} JD';

  Map<String, double>? _feeBreakdown(Map<String, dynamic> bookingData) {
    // preferred keys (new)
    final subtotal = _readNum(bookingData['subtotalPrice']);
    final fee = _readNum(bookingData['serviceFee']);
    final total = _readNum(bookingData['totalPrice']);

    // If at least subtotal exists, we can derive others (backward compatible)
    if (subtotal != null) {
      final computedFee = fee ?? (subtotal * 0.03);
      final computedTotal = total ?? (subtotal + computedFee);
      return {
        'subtotal': subtotal,
        'fee': computedFee,
        'total': computedTotal,
      };
    }

    // If total exists but no subtotal, we can’t reliably separate fee, so return null.
    return null;
  }

  String _buildCalendarDescription({
    required String bookingId,
    required String eventId,
    required String status,
    required Map<String, dynamic> bookingData,
    required Map<String, dynamic> eventData,
    required Map<String, dynamic> organizerData,
  }) {
    String s(dynamic v) => (v ?? '').toString().trim();

    final organizerName = s(organizerData['name']).isNotEmpty
        ? s(organizerData['name'])
        : (s(eventData['organizerName']).isNotEmpty ? s(eventData['organizerName']) : '');

    final category = s(bookingData['category']).isNotEmpty
        ? s(bookingData['category'])
        : s(eventData['category']);

    final location = s(bookingData['location']).isNotEmpty
        ? s(bookingData['location'])
        : s(eventData['location']);

    final city = s(bookingData['city']).isNotEmpty ? s(bookingData['city']) : s(eventData['city']);

    final cover = s(bookingData['coverImageUrl']).isNotEmpty
        ? s(bookingData['coverImageUrl'])
        : s(eventData['coverImageUrl']);

    final description =
    s(eventData['description']).isNotEmpty ? s(eventData['description']) : s(eventData['details']);

    final lines = <String>[];

    if (organizerName.isNotEmpty) lines.add('Organizer: $organizerName');
    if (category.isNotEmpty) lines.add('Category: $category');

    final locLine = [
      if (location.isNotEmpty) location,
      if (city.isNotEmpty &&
          (location.isEmpty || !location.toLowerCase().contains(city.toLowerCase())))
        city,
    ].where((e) => e.trim().isNotEmpty).join(' • ');
    if (locLine.isNotEmpty) lines.add('Location: $locLine');

    // Add fee breakdown if present (new requirement)
    final breakdown = _feeBreakdown(bookingData);
    if (breakdown != null) {
      final subtotal = breakdown['subtotal']!;
      final fee = breakdown['fee']!;
      final total = breakdown['total']!;
      lines.add('');
      lines.add('Payment:');
      lines.add('Subtotal: ${_fmtJd(subtotal)}');
      lines.add('Service fee (3%): +${_fmtJd(fee)}');
      lines.add('Total: ${_fmtJd(total)}');
    } else {
      final totalStr = s(bookingData['totalPrice']);
      if (totalStr.isNotEmpty) {
        lines.add('');
        lines.add('Total paid: $totalStr');
      }
    }

    if (description.isNotEmpty) {
      lines.add('');
      lines.add(description);
    }

    if (cover.isNotEmpty) {
      lines.add('');
      lines.add('Cover: $cover');
    }

    lines.add('');
    lines.add('Status: $status');
    lines.add('Booking ID: $bookingId');
    if (eventId.trim().isNotEmpty) lines.add('Event ID: $eventId');

    return lines.join('\n');
  }

  Future<void> _addToCalendarEnriched({
    required BuildContext context,
    required String bookingId,
    required String title,
    required DateTime start,
    DateTime? end,
    required String status,
    required String eventId,
    required String organizerId,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      Map<String, dynamic> eventData = <String, dynamic>{};
      Map<String, dynamic> organizerData = <String, dynamic>{};

      if (eventId.trim().isNotEmpty) {
        try {
          eventData = await _fetchEventIfNeeded(eventId);
        } catch (_) {
          eventData = <String, dynamic>{};
        }
      }

      final orgIdFromBooking = (bookingData['organizerId'] ?? '').toString().trim();
      final orgId = organizerId.trim().isNotEmpty ? organizerId.trim() : orgIdFromBooking;

      if (orgId.isNotEmpty) {
        try {
          organizerData = await _fetchOrganizerIfNeeded(orgId);
        } catch (_) {
          organizerData = <String, dynamic>{};
        }
      }

      final safeTitle = title.trim().isEmpty ? 'Event' : title.trim();
      final safeEnd = (end ?? start.add(const Duration(hours: 1)));
      final endFinal = safeEnd.isAfter(start) ? safeEnd : start.add(const Duration(hours: 1));

      final location = (() {
        final l1 = (bookingData['location'] ?? '').toString().trim();
        if (l1.isNotEmpty) return l1;
        final l2 = (eventData['location'] ?? '').toString().trim();
        return l2.isEmpty ? null : l2;
      })();

      final description = _buildCalendarDescription(
        bookingId: bookingId,
        eventId: eventId,
        status: status,
        bookingData: bookingData,
        eventData: eventData,
        organizerData: organizerData,
      );

      final event = Event(
        title: safeTitle,
        description: description.trim().isEmpty ? null : description,
        location: location,
        startDate: start,
        endDate: endFinal,
      );

      await Add2Calendar.addEvent2Cal(event);

      if (!context.mounted) return;
      await AppDialogs.showInfo(context, message: 'Added to your calendar.');
    } catch (_) {
      if (!context.mounted) return;
      await AppDialogs.showError(context, message: 'Unable to add to calendar. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = UserRepo();
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repo.watchBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load bookings',
              message: 'Please check your connection and try again.',
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.confirmation_num_outlined,
              title: 'No bookings yet',
              message: 'When you book an event, it will appear here.',
            );
          }

          final now = DateTime.now();
          final upcoming = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final past = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          for (final d in docs) {
            final data = d.data();
            if (_isPastBooking(data, now)) {
              past.add(d);
            } else {
              upcoming.add(d);
            }
          }

          upcoming.sort((a, b) {
            final aStart = _readTs(a.data()['startDateTime']) ?? DateTime(2100);
            final bStart = _readTs(b.data()['startDateTime']) ?? DateTime(2100);
            return aStart.compareTo(bStart);
          });

          past.sort((a, b) {
            final aStart = _readTs(a.data()['startDateTime']) ?? DateTime(1970);
            final bStart = _readTs(b.data()['startDateTime']) ?? DateTime(1970);
            return bStart.compareTo(aStart);
          });

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const _SectionHeader(
                title: 'Upcoming',
                subtitle: 'Your active and upcoming bookings.',
              ),
              const SizedBox(height: AppSpacing.sm),

              if (upcoming.isEmpty)
                const EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'No upcoming bookings',
                  message: 'Book an event and it will appear here.',
                )
              else
                ..._buildCards(
                  context: context,
                  docs: upcoming,
                  repo: repo,
                  t: t,
                  cs: cs,
                  isPast: false,
                ),

              const SizedBox(height: AppSpacing.lg),

              const _SectionHeader(
                title: 'Past',
                subtitle: 'Your previous bookings.',
              ),
              const SizedBox(height: AppSpacing.sm),

              if (past.isEmpty)
                const EmptyState(
                  icon: Icons.history_outlined,
                  title: 'No past bookings',
                  message: 'Past bookings will show here after events end.',
                )
              else
                ..._buildCards(
                  context: context,
                  docs: past,
                  repo: repo,
                  t: t,
                  cs: cs,
                  isPast: true,
                ),

              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildCards({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required UserRepo repo,
    required TextTheme t,
    required ColorScheme cs,
    required bool isPast,
  }) {
    final df = DateFormat('EEE, dd MMM • HH:mm');

    return List.generate(docs.length, (i) {
      final doc = docs[i];
      final data = doc.data();

      final title = (data['eventTitle'] ?? 'Event').toString();
      final statusRaw = (data['status'] ?? 'pending').toString();
      final status = _statusLabel(statusRaw);

      final eventId = (data['eventId'] ?? '').toString().trim();
      final organizerId = (data['organizerId'] ?? '').toString().trim();

      final start = _readTs(data['startDateTime']);
      final end = _readTs(data['endDateTime']);

      final dateLine = (start == null)
          ? null
          : (end == null ? df.format(start) : '${df.format(start)}  →  ${df.format(end)}');

      final canAddToCal = (!isPast) && start != null && _canAddToCalendar(status);

      // Fee breakdown (if available)
      final breakdown = _feeBreakdown(data);

      // Backward fallback: keep your old totalPrice string if breakdown missing
      final totalPriceText = (data['totalPrice'] ?? '').toString().trim();

      return Padding(
        padding: EdgeInsets.only(bottom: i == docs.length - 1 ? 0 : AppSpacing.sm),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: cs.primary.withAlpha(24),
                      ),
                      child: Icon(
                        isPast ? Icons.history_outlined : Icons.confirmation_num_outlined,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          if (dateLine != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              dateLine,
                              style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(170)),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _StatusPill(text: status),

                              // Price display
                              const SizedBox(width: 10),
                              if (breakdown != null)
                                Text(
                                  _fmtJd(breakdown['total']!),
                                  style: t.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: cs.onSurface.withAlpha(210),
                                  ),
                                )
                              else if (totalPriceText.isNotEmpty)
                                Text(
                                  totalPriceText,
                                  style: t.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: cs.onSurface.withAlpha(210),
                                  ),
                                ),
                            ],
                          ),

                          // NEW: show breakdown lines under the row (when available)
                          if (breakdown != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withAlpha(90),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Payment breakdown', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 6),
                                  _LineKV(label: 'Subtotal', value: _fmtJd(breakdown['subtotal']!)),
                                  _LineKV(label: 'Service fee (3%)', value: '+${_fmtJd(breakdown['fee']!)}'),
                                  const Divider(height: 14),
                                  _LineKV(
                                    label: 'Total',
                                    value: _fmtJd(breakdown['total']!),
                                    bold: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // ✅ Add to Calendar (Upcoming only)
                if (canAddToCal) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Add to calendar'),
                      onPressed: () async {
                        await _addToCalendarEnriched(
                          context: context,
                          bookingId: doc.id,
                          title: title,
                          start: start!,
                          end: end,
                          status: status,
                          eventId: eventId,
                          organizerId: organizerId,
                          bookingData: data,
                        );
                      },
                    ),
                  ),
                ],

                if (!isPast && _canCancel(status)) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel booking'),
                      onPressed: eventId.isEmpty
                          ? null
                          : () async {
                        final ok = await AppDialogs.confirm(
                          context,
                          title: 'Cancel booking',
                          message: 'Are you sure you want to cancel this booking?',
                          confirmText: 'Cancel booking',
                        );

                        if (ok != true) return;

                        try {
                          await repo.cancelBooking(
                            bookingId: doc.id,
                            eventId: eventId,
                          );
                          if (!context.mounted) return;
                          await AppDialogs.showInfo(
                            context,
                            message: 'Booking cancelled successfully.',
                          );
                        } catch (_) {
                          if (!context.mounted) return;
                          await AppDialogs.showError(
                            context,
                            message: 'Unable to cancel booking. Please try again.',
                          );
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: t.bodySmall?.copyWith(color: cs.onSurface.withAlpha(170))),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;

  const _StatusPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bg;
    Color fg;

    switch (text.toLowerCase()) {
      case 'confirmed':
        bg = cs.primary.withAlpha(26);
        fg = cs.primary;
        break;
      case 'cancelled':
      case 'canceled':
        bg = cs.onSurface.withAlpha(12);
        fg = cs.onSurface.withAlpha(210);
        break;
      case 'rejected':
        bg = const Color(0xFFB91C1C).withAlpha(22);
        fg = const Color(0xFFB91C1C);
        break;
      default:
        bg = cs.tertiary.withAlpha(18);
        fg = cs.tertiary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _LineKV extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _LineKV({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(190))),
          ),
          Text(
            value,
            style: (bold ? t.bodyMedium : t.bodySmall)?.copyWith(fontWeight: bold ? FontWeight.w900 : FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
