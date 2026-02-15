import 'package:cloud_firestore/cloud_firestore.dart';

import '../Models/event_post.dart';
import '../Models/organizer_model.dart';
import 'organizer_repository.dart';

class FirestoreOrganizerRepository implements OrganizerRepository {
  final FirebaseFirestore _db;

  FirestoreOrganizerRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _eventsRef => _db.collection('events');
  CollectionReference<Map<String, dynamic>> get _organizersRef => _db.collection('organizers');


  @override
  Stream<OrganizerModel?> watchOrganizer(String organizerId) {
    final docRef = _organizersRef.doc(organizerId);
    return docRef.snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data() ?? <String, dynamic>{};
      return OrganizerModel.fromMap(data, snap.id);
    });
  }

  @override
  Stream<List<EventPost>> watchOrganizerEvents(String organizerId) {
    return _eventsRef
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => EventPost.fromMap(d.data(), d.id))
        .toList());
  }

  @override
  Future<OrganizerModel?> getOrganizer(String organizerId) async {
    final doc = await _organizersRef.doc(organizerId).get();
    if (!doc.exists) return null;
    final data = doc.data() ?? <String, dynamic>{};
    return OrganizerModel.fromMap(data, doc.id);
  }

  @override
  Future<List<EventPost>> fetchOrganizerEvents(String organizerId) async {
    final snap = await _eventsRef
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) => EventPost.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<void> saveEvent(EventPost event) async {
    final ref = _eventsRef.doc(event.id);
    await ref.set(event.toMap(), SetOptions(merge: true));
  }
}
