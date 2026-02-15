import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple in-memory cache to resolve organizer/user IDs -> display name.
class AdminNameCache {
  AdminNameCache._();

  static final Map<String, String> _cache = {};

  static Future<String> organizerName(String organizerId) async {
    final id = organizerId.trim();
    if (id.isEmpty) return 'Unknown';

    final cached = _cache[id];
    if (cached != null && cached.isNotEmpty) return cached;

    // 1) Try /organizers/{id}
    final orgSnap =
    await FirebaseFirestore.instance.collection('organizers').doc(id).get();
    if (orgSnap.exists) {
      final data = orgSnap.data() as Map<String, dynamic>;
      final name = (data['name'] ?? data['displayName'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        _cache[id] = name;
        return name;
      }
    }

    // 2) Fallback: /users/{id}
    final userSnap =
    await FirebaseFirestore.instance.collection('users').doc(id).get();
    if (userSnap.exists) {
      final data = userSnap.data() as Map<String, dynamic>;
      final name = (data['fullName'] ?? data['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        _cache[id] = name;
        return name;
      }
    }

    // 3) Final fallback: shorten id
    final short = id.length > 10 ? '${id.substring(0, 10)}…' : id;
    _cache[id] = short;
    return short;
  }

  static Future<String> eventTitle(String eventId) async {
    final id = eventId.trim();
    if (id.isEmpty) return 'Event';

    final key = 'event:$id';
    final cached = _cache[key];
    if (cached != null && cached.isNotEmpty) return cached;

    final snap =
    await FirebaseFirestore.instance.collection('events').doc(id).get();
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().trim();
      if (title.isNotEmpty) {
        _cache[key] = title;
        return title;
      }
    }

    final short = id.length > 10 ? '${id.substring(0, 10)}…' : id;
    _cache[key] = short;
    return short;
  }
}
