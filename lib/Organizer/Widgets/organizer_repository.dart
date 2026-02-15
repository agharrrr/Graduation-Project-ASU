import '../Models/event_post.dart';
import '../Models/organizer_model.dart';

abstract class OrganizerRepository {
  /// Live stream of organizer profile data.
  /// This allows the UI to update immediately after changing cover/profile images.
  Stream<OrganizerModel?> watchOrganizer(String organizerId);

  /// Live stream of this organizer's events (for the home screen).
  Stream<List<EventPost>> watchOrganizerEvents(String organizerId);

  /// One-time read of organizer profile.
  Future<OrganizerModel?> getOrganizer(String organizerId);

  /// One-time fetch of organizer events.
  Future<List<EventPost>> fetchOrganizerEvents(String organizerId);

  /// Create/update event.
  Future<void> saveEvent(EventPost event);
}
