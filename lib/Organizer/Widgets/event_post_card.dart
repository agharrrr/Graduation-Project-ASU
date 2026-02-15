import 'package:flutter/material.dart';
import '../Models/event_post.dart';

import '../../shared/ui/app_spacing.dart';

class EventPostCard extends StatelessWidget {
  final EventPost event;
  final VoidCallback? onTap;

  // ✅ NEW: shown only when organizer needs to request edit access
  final VoidCallback? onRequestEdit;

  const EventPostCard({
    super.key,
    required this.event,
    this.onTap,
    this.onRequestEdit,
  });

  String get _statusLabel {
    switch (event.status) {
      case EventStatus.published:
        return 'PUBLISHED';
      case EventStatus.draft:
        return 'DRAFT';
      case EventStatus.archived:
        return 'ARCHIVED';
    }
  }

  IconData get _statusIcon {
    switch (event.status) {
      case EventStatus.published:
        return Icons.public;
      case EventStatus.draft:
        return Icons.edit_note_outlined;
      case EventStatus.archived:
        return Icons.inventory_2_outlined;
    }
  }

  // Calm tones (no neon). Uses theme colors.
  Color _statusAccent(ColorScheme cs) {
    switch (event.status) {
      case EventStatus.published:
        return cs.primary;
      case EventStatus.draft:
        return cs.tertiary;
      case EventStatus.archived:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final accent = _statusAccent(cs);

    final bool isPublished = event.status == EventStatus.published;
    final bool canEditPublished = event.allowEditPublished == true;
    final bool showRequest =
        isPublished && !canEditPublished && onRequestEdit != null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- Cover ----------
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (event.coverImageUrl != null && event.coverImageUrl!.isNotEmpty)
                    Image.network(
                      event.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  else
                    _imagePlaceholder(),

                  // Subtle gradient for readability
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.05),
                            Colors.black.withOpacity(0.45),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Status badge
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withOpacity(0.20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            _statusLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ✅ NEW: Request edit icon (only when published + read-only)
                  if (showRequest)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Tooltip(
                        message: 'Request edit access',
                        child: InkWell(
                          onTap: onRequestEdit,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.28),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withOpacity(0.18)),
                            ),
                            child: const Icon(
                              Icons.outgoing_mail,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ---------- Content ----------
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    event.title.isEmpty ? 'Untitled event' : event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Secondary line: location + date
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _MetaChip(
                        icon: Icons.place_outlined,
                        text: event.location.isEmpty ? 'No location' : event.location,
                      ),
                      _MetaChip(
                        icon: Icons.event_outlined,
                        text: _formatDate(event.startDateTime),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Stats row
                  Row(
                    children: [
                      _StatPill(
                        icon: Icons.people_outline,
                        text: '${event.bookingsCount}/${event.capacity}',
                        accent: accent,
                      ),
                      const SizedBox(width: 10),
                      _StatPill(
                        icon: Icons.remove_red_eye_outlined,
                        text: event.viewsCount.toString(),
                        accent: accent,
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

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.black.withAlpha(8),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 54,
          color: Colors.black38,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}  ${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;

  const _StatPill({
    required this.icon,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.black.withOpacity(0.82),
            ),
          ),
        ],
      ),
    );
  }
}
