import 'dart:async';
import 'dart:math';

import '../Models/event_post.dart';
import '../Models/organizer_model.dart';
import 'organizer_repository.dart';

class FakeOrganizerRepository implements OrganizerRepository {
  final List<EventPost> _storage = [];
  final _controller = StreamController<List<EventPost>>.broadcast();
  final _random = Random();

  FakeOrganizerRepository() {
    _seedFakeData();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_storage));
    }
  }

  void _seedFakeData() {
    final now = DateTime.now();

    // NOTE:
    // Your EventPost constructor currently requires more named params
    // (archived, allowEditPublished, createdAt, updatedAt, coverImageUrl, likesCount, commentsCount, etc.)
    // so we must provide safe defaults for ALL required fields.

    _storage.addAll([
      EventPost(
        id: '1',
        organizerId: 'demo-organizer',
        title: 'Tech Meetup Amman',
        description: 'Monthly meetup for developers in Amman.',
        category: 'Workshop',
        location: 'Amman',

        startDateTime: now.add(const Duration(days: 2)),
        endDateTime: now.add(const Duration(days: 2, hours: 2)),

        isPaid: false,
        price: 0,
        capacity: 100,

        // status + moderation flags
        status: EventStatus.published,
        archived: false,
        allowEditPublished: false,

        // media
        coverImageUrl: '',

        // counters
        bookingsCount: 25,
        viewsCount: 120,
        likesCount: 0,
        commentsCount: 0,

        // timestamps
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 5)),
      ),
      EventPost(
        id: '2',
        organizerId: 'demo-organizer',
        title: 'Summer Party',
        description: 'Outdoor party with music and food.',
        category: 'Party',
        location: 'Dead Sea',

        startDateTime: now.add(const Duration(days: 10)),
        endDateTime: now.add(const Duration(days: 10, hours: 4)),

        isPaid: true,
        price: 15,
        capacity: 200,

        status: EventStatus.draft,
        archived: false,
        allowEditPublished: false,

        coverImageUrl: '',

        bookingsCount: 0,
        viewsCount: 30,
        likesCount: 0,
        commentsCount: 0,

        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2, hours: 3)),
      ),
    ]);

    _emit();
  }

  // NEW: required by OrganizerRepository in the newer version
  @override
  Stream<OrganizerModel?> watchOrganizer(String organizerId) {
    // Minimal live organizer stream for offline/demo.
    // If you want it to “change”, you can later add a controller for organizer too.
    return Stream.value(
      OrganizerModel(
        id: organizerId,
        name: 'Demo Organizer',
        coverImageUrl: '',
        profileImageUrl: '',
        followersCount: 123,
      ),
    );
  }

  @override
  Stream<List<EventPost>> watchOrganizerEvents(String organizerId) {
    return _controller.stream.map((events) {
      final list = events
          .where((e) => e.organizerId == organizerId && e.archived != true)
          .toList();

      // createdAt might be nullable in your model => safe sort
      list.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate); // newest first
      });

      return list;
    });
  }

  @override
  Future<List<EventPost>> fetchOrganizerEvents(String organizerId) async {
    final list = _storage
        .where((e) => e.organizerId == organizerId && e.archived != true)
        .toList();

    list.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return list;
  }

  @override
  Future<void> saveEvent(EventPost event) async {
    final index = _storage.indexWhere((e) => e.id == event.id);

    if (index == -1) {
      final newId = (_random.nextInt(900000) + 100000).toString();

      // Ensure timestamps exist to avoid nullable sort issues
      final now = DateTime.now();

      _storage.add(
        event.copyWith(
          id: newId,
          createdAt: event.createdAt ?? now,
          updatedAt: now,
        ),
      );
    } else {
      _storage[index] = event.copyWith(
        updatedAt: DateTime.now(),
      );
    }

    _emit();
  }

  @override
  Future<OrganizerModel?> getOrganizer(String organizerId) async {
    return OrganizerModel(
      id: organizerId,
      name: 'Demo Organizer',
      coverImageUrl: '',
      profileImageUrl: '',
      followersCount: 123,
    );
  }

  void dispose() {
    _controller.close();
  }
}
