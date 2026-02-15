import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Screens/event_details_screen.dart';
import '../../Organizer/Models/event_post.dart';
import '../../shared/ui/app_spacing.dart';
import '../../main.dart'; // LocaleController

class PublicEventsCard extends StatelessWidget {
  final EventPost event;

  const PublicEventsCard({
    super.key,
    required this.event,
  });

  String _t(BuildContext context, String en, String ar) {
    final isAr = context.watch<LocaleController>().isArabic;
    return isAr ? ar : en;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailsScreen(event: event),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (event.coverImageUrl != null && event.coverImageUrl!.isNotEmpty)
                    Image.network(
                      event.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imageFallback(context),
                    )
                  else
                    _imageFallback(context),

                  // Darken the image slightly so text stays readable
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.10),
                            Colors.black.withOpacity(0.70),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 12,
                    top: 12,
                    child: _Pill(
                      text: event.category.isEmpty ? _t(context, 'Event', 'فعالية') : event.category,
                      background: Colors.black.withOpacity(0.25),
                      foreground: Colors.white.withOpacity(0.95),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _Pill(
                      text: event.isPaid ? '${event.price ?? 0} JD' : _t(context, 'Free', 'مجاني'),
                      background: event.isPaid ? cs.primary.withOpacity(0.92) : Colors.white.withOpacity(0.92),
                      foreground: event.isPaid ? cs.onPrimary : cs.onSurface,
                    ),
                  ),

                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        Expanded(
                          child: _GlassRow(
                            icon: Icons.place_outlined,
                            text: event.location.isEmpty ? _t(context, 'No location', 'لا يوجد موقع') : event.location,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _GlassRow(
                          icon: Icons.event_outlined,
                          text: _formatDate(event.startDateTime),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title.isEmpty ? _t(context, 'Untitled event', 'فعالية بدون عنوان') : event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.1,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(
                        _t(context, 'View details', 'عرض التفاصيل'),
                        style: t.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: cs.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 54,
          color: cs.onSurfaceVariant.withOpacity(0.55),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}  ${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _GlassRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GlassRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.95)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
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

class _Pill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const _Pill({
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
