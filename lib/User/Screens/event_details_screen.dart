import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shoo_fi/Organizer/Models/event_post.dart';
import 'package:shoo_fi/User/Payments/payment_screen.dart';
import 'package:shoo_fi/User/Services/event_actions.dart';
import 'user_report.dart';
import '../../shared/app_dialog.dart';
import '../../shared/ui/app_spacing.dart';
import '../../shared/ui/empty_state.dart';
import '../../main.dart'; // LocaleController


class EventDetailsScreen extends StatefulWidget {
  final EventPost event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _loadingBookingState = true;
  bool _hasBooked = false;
  bool _processing = false;

  String _t(String en, String ar) {
    final isAr = context.watch<LocaleController>().isArabic;
    return isAr ? ar : en;
  }

  @override
  void initState() {
    super.initState();
    _loadBookingState();
  }

  Future<void> _loadBookingState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _hasBooked = false;
        _loadingBookingState = false;
      });
      return;
    }

    try {
      final hasBooking = await EventActions.instance.hasBooking(widget.event.id);
      if (!mounted) return;
      setState(() {
        _hasBooked = hasBooking;
        _loadingBookingState = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasBooked = false;
        _loadingBookingState = false;
      });
    }
  }

  String _friendlyActionError(Object e) {
    final raw = e.toString().toLowerCase();

    if (raw.contains('network') || raw.contains('socket')) {
      return _t('No internet connection. Please try again.', 'لا يوجد اتصال بالإنترنت. حاول مرة أخرى.');
    }
    if (raw.contains('permission-denied')) {
      return _t('You do not have permission to do this action.', 'ليس لديك صلاحية لتنفيذ هذا الإجراء.');
    }
    if (raw.contains('unauth') || raw.contains('not-authenticated') || raw.contains('requires-recent-login')) {
      return _t('Please log in again to continue.', 'يرجى تسجيل الدخول مرة أخرى للمتابعة.');
    }
    if (raw.contains('capacity') || raw.contains('full') || raw.contains('event-full')) {
      return _t('This event is fully booked right now.', 'هذه الفعالية ممتلئة حالياً.');
    }
    if (raw.contains('payment-required')) {
      return _t('Payment is required for this event.', 'الدفع مطلوب لهذه الفعالية.');
    }
    if (raw.contains('event-ended')) {
      return _t('This event has already ended.', 'هذه الفعالية انتهت بالفعل.');
    }
    if (raw.contains('booking-not-found')) {
      return _t('Booking was not found for this event.', 'تعذر العثور على الحجز لهذه الفعالية.');
    }

    return _t('Something went wrong. Please try again.', 'حدث خطأ. حاول مرة أخرى.');
  }

  Future<void> _handleBook() async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      Map<String, dynamic>? payment;

      if (widget.event.isPaid) {
        final subtotal = (widget.event.price ?? 0);

        final res = await Navigator.of(context).push<CardPaymentResult?>(
          MaterialPageRoute(
            builder: (_) => CardPaymentScreen(subtotalJod: subtotal),
          ),
        );

        if (res == null) {
          if (mounted) setState(() => _processing = false);
          return;
        }

        payment = res.toMap();
      }

      await EventActions.instance.bookEvent(
        widget.event.id,
        payment: payment,
      );

      if (!mounted) return;

      await AppDialogs.showInfo(
        context,
        title: _t('Booking confirmed', 'تم تأكيد الحجز'),
        message: _t('Your seat has been reserved successfully.', 'تم حجز مقعدك بنجاح.'),
      );

      await _loadBookingState();
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        title: _t('Booking failed', 'فشل الحجز'),
        message: _friendlyActionError(e),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _handleCancel() async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      await EventActions.instance.cancelBooking(widget.event.id);
      if (!mounted) return;

      await AppDialogs.showInfo(
        context,
        title: _t('Booking cancelled', 'تم إلغاء الحجز'),
        message: _t('Your booking has been cancelled.', 'تم إلغاء حجزك.'),
      );

      await _loadBookingState();
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        title: _t('Cancellation failed', 'فشل الإلغاء'),
        message: _friendlyActionError(e),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _openReport(EventPost event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportScreen(
          eventId: event.id,
          eventTitle: event.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final onSurfaceStrong = cs.onSurface;
    final onSurfaceSoft = cs.onSurface.withAlpha(170);

    final eventsRef = FirebaseFirestore.instance.collection('events').doc(widget.event.id);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: eventsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: EmptyState(
              icon: Icons.cloud_off_outlined,
              title: _t('Unable to load event', 'تعذر تحميل الفعالية'),
              message: _t('Please check your connection and try again.', 'تحقق من الاتصال وحاول مرة أخرى.'),
            ),
          );
        }

        var event = widget.event;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() ?? <String, dynamic>{};
          event = EventPost.fromMap(data, snapshot.data!.id);
        }

        final df = DateFormat('EEE, dd MMM yyyy • HH:mm');
        final dateText = df.format(event.startDateTime);
        final endText = df.format(event.endDateTime);
        final isEnded = event.endDateTime.isBefore(DateTime.now());


        final isCapacityKnown = event.capacity > 0;
        final isFull = isCapacityKnown && event.bookingsCount >= event.capacity;

        final bookingsText = isCapacityKnown
            ? '${event.bookingsCount}/${event.capacity} ${_t('seats booked', 'مقاعد محجوزة')}'
            : '${event.bookingsCount} ${_t('booked', 'حجز')}';

        final progress = (isCapacityKnown && event.capacity > 0)
            ? (event.bookingsCount / event.capacity).clamp(0.0, 1.0)
            : null;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 320,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    tooltip: _t('Report', 'إبلاغ'),
                    icon: const Icon(Icons.flag_outlined),
                    onPressed: () => _openReport(event),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsetsDirectional.only(
                    start: 16,
                    end: 16,
                    bottom: 12,
                  ),
                  title: Text(
                    event.title.isEmpty ? _t('Event details', 'تفاصيل الفعالية') : event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  background: _HeaderImage(
                    imageUrl: event.coverImageUrl,
                    showBookedBadge: _hasBooked,
                    showFullBadge: isFull,
                    bookedText: _t('Booked', 'محجوز'),
                    fullText: _t('Full', 'ممتلئ'),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _Pill(
                            icon: Icons.event_outlined,
                            text: dateText,
                            background: cs.primary.withAlpha(22),
                            foreground: onSurfaceStrong,
                            iconColor: cs.primary,
                          ),
                          _Pill(
                            icon: Icons.place_outlined,
                            text: event.location.isEmpty ? _t('No location', 'لا يوجد موقع') : event.location,
                            background: cs.primary.withAlpha(22),
                            foreground: onSurfaceStrong,
                            iconColor: cs.primary,
                          ),
                          _Pill(
                            icon: event.isPaid ? Icons.payments_outlined : Icons.local_offer_outlined,
                            text: event.isPaid ? '${event.price ?? 0} JD' : _t('Free', 'مجاني'),
                            background: event.isPaid ? cs.primary.withAlpha(230) : cs.surfaceContainerHighest.withAlpha(80),
                            foreground: event.isPaid ? cs.onPrimary : onSurfaceStrong,
                            iconColor: event.isPaid ? cs.onPrimary : cs.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('Details', 'التفاصيل'),
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _InfoRow(
                                icon: Icons.schedule_outlined,
                                title: _t('Time', 'الوقت'),
                                subtitle: '$dateText\n– $endText',
                              ),
                              const Divider(height: AppSpacing.lg),
                              _InfoRow(
                                icon: Icons.people_outline,
                                title: _t('Attendance', 'الحضور'),
                                subtitle: bookingsText,
                              ),
                              if (progress != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8,
                                    backgroundColor: cs.onSurface.withAlpha(18),
                                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('About this event', 'عن الفعالية'),
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                event.description.isEmpty ? _t('No description provided.', 'لا يوجد وصف.') : event.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: onSurfaceSoft,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_loadingBookingState)
                        const Center(child: CircularProgressIndicator())
                      else
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _processing
                                    ? null
                                    : (_hasBooked ? _handleCancel : (isFull || isEnded ? null : _handleBook)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: _processing
                                      ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                                    ),
                                  )
                                      : Text(
                                    _hasBooked
                                        ? _t('Cancel booking', 'إلغاء الحجز')
                                        : (isEnded
                                        ? _t('Event ended', 'انتهت الفعالية')
                                        : (isFull ? _t('Fully booked', 'ممتلئ') : _t('Book now', 'احجز الآن'))),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),

                                ),
                              ),
                            ),
                            if (!_hasBooked && isFull) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                _t('This event is currently fully booked.', 'هذه الفعالية ممتلئة حالياً.'),
                                style: theme.textTheme.bodySmall?.copyWith(color: onSurfaceSoft),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// The rest of your widgets (_HeaderImage, _Badge, _InfoRow, _Pill) remain unchanged.

class _HeaderImage extends StatelessWidget {
  final String? imageUrl;
  final bool showBookedBadge;
  final bool showFullBadge;

  final String bookedText;
  final String fullText;

  const _HeaderImage({
    required this.imageUrl,
    required this.showBookedBadge,
    required this.showFullBadge,
    required this.bookedText,
    required this.fullText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null && imageUrl!.isNotEmpty)
          Image.network(
            imageUrl!,
            key: ValueKey(imageUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(context),
          )
        else
          _fallback(context),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.10),
                  Colors.black.withOpacity(0.65),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 40,
          child: Row(
            children: [
              if (showBookedBadge)
                _Badge(
                  text: bookedText,
                  background: cs.primary.withAlpha(220),
                ),
              if (showBookedBadge && showFullBadge) const SizedBox(width: 8),
              if (showFullBadge)
                const _Badge(
                  text: 'Full',
                  background: Color(0xFFB91C1C),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 64, color: Colors.white38),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color background;

  const _Badge({
    required this.text,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final titleColor = cs.onSurface;
    final subtitleColor = cs.onSurface.withAlpha(170);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: cs.primary.withAlpha(22),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: cs.primary, size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: titleColor),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: t.bodyMedium?.copyWith(color: subtitleColor, height: 1.25),
              ),
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
  final Color background;
  final Color foreground;
  final Color iconColor;

  const _Pill({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
