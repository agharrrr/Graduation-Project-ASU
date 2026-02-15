import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRepo {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  UserRepo({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? _userDocRef() {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  Stream<Map<String, dynamic>?> watchUser() {
    final ref = _userDocRef();
    if (ref == null) return const Stream.empty();

    return ref.snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() ?? <String, dynamic>{};
      data['id'] = doc.id;
      return data;
    });
  }

  Future<Map<String, dynamic>?> getUserOnce() async {
    final ref = _userDocRef();
    if (ref == null) return null;
    final snap = await ref.get();
    if (!snap.exists) return null;
    final data = snap.data() ?? <String, dynamic>{};
    data['id'] = snap.id;
    return data;
  }

  Future<void> ensureUserDoc({
    required String displayName,
    String? photoUrl,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');

    final ref = _db.collection('users').doc(uid);

    await ref.set(
      {
        'displayName': displayName.trim(),
        'photoUrl': (photoUrl ?? '').trim(),
        'notificationsEnabled': true,
        'language': 'en',
        'onboardingCompleted': false,
        'preferredCategories': <String>[],
        'favoriteOrganizerIds': <String>[],
        'city': '', // ✅ Added: onboarding routing uses it
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateProfile({
    required String displayName,
    required String photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final name = displayName.trim();
    final photo = photoUrl.trim();

    if (name.isNotEmpty) await user.updateDisplayName(name);
    await user.updatePhotoURL(photo.isEmpty ? null : photo);
    await user.reload();

    await _db.collection('users').doc(user.uid).set(
      {
        'displayName': name,
        'photoUrl': photo,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final ref = _userDocRef();
    if (ref == null) throw Exception('Not logged in');

    await ref.set(
      {
        'notificationsEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setPreferredCategories(List<String> categories) async {
    final ref = _userDocRef();
    if (ref == null) throw Exception('Not logged in');

    await ref.set(
      {
        'preferredCategories': categories,
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setLanguage(String code) async {
    final ref = _userDocRef();
    if (ref == null) throw Exception('Not logged in');

    final lang = (code == 'ar') ? 'ar' : 'en';
    await ref.set(
      {
        'language': lang,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ---------------------------
  // Rating (1..5)
  // ratings/{uid} -> { userId, rating, updatedAt }
  // ---------------------------
  Future<int?> getMyRating() async {
    final uid = _uid;
    if (uid == null) return null;

    final doc = await _db.collection('ratings').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data() ?? {};
    final r = data['rating'];
    if (r is num) return r.toInt();
    return null;
  }

  Future<void> submitRating(int rating) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');

    final safe = rating.clamp(1, 5);

    await _db.collection('ratings').doc(uid).set(
      {
        'userId': uid,
        'rating': safe,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> toggleFavoriteOrganizer(String organizerId, bool follow) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final orgId = organizerId.trim();
    if (orgId.isEmpty) return;

    final userRef = _db.collection('users').doc(uid);
    final orgRef = _db.collection('organizers').doc(orgId);
    final followerRef = orgRef.collection('followers').doc(uid);

    await _db.runTransaction((tx) async {
      final orgSnap = await tx.get(orgRef);
      if (!orgSnap.exists) throw Exception('Organizer not found');

      final followerSnap = await tx.get(followerRef);

      if (follow) {
        if (!followerSnap.exists) {
          tx.set(followerRef, {
            'userId': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });

          tx.set(
            userRef,
            {
              'favoriteOrganizerIds': FieldValue.arrayUnion([orgId]),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      } else {
        if (followerSnap.exists) {
          tx.delete(followerRef);

          tx.set(
            userRef,
            {
              'favoriteOrganizerIds': FieldValue.arrayRemove([orgId]),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }
    });
  }

  CollectionReference<Map<String, dynamic>> _bookingsRef(String uid) {
    return _db.collection('users').doc(uid).collection('bookings');
  }

  // ✅ UPDATED: store endDateTime inside the booking for easy split (upcoming vs past).
  Future<void> createBooking({
    required String eventId,
    required String organizerId,
    required String eventTitle,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required int quantity,
    required num totalPrice,
    required String status,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    if (eventId.trim().isEmpty) throw Exception('Missing eventId');

    final bookingRef = _bookingsRef(uid).doc();

    await bookingRef.set({
      'bookingId': bookingRef.id,
      'eventId': eventId.trim(),
      'organizerId': organizerId.trim(),
      'eventTitle': eventTitle.trim(),
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime), // ✅ NEW
      'quantity': quantity,
      'totalPrice': totalPrice,
      'status': status.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBookings() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _bookingsRef(uid).orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> logout() async => _auth.signOut();

  Future<void> cancelBooking({
    required String bookingId,
    required String eventId,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');

    final bId = bookingId.trim();
    final eId = eventId.trim();
    if (bId.isEmpty) throw Exception('Missing bookingId');
    if (eId.isEmpty) throw Exception('Missing eventId');

    final bookingRef = _bookingsRef(uid).doc(bId);
    final eventRef = _db.collection('events').doc(eId);

    await _db.runTransaction((tx) async {
      final bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) throw Exception('Booking not found');

      final bookingData = bookingSnap.data() ?? <String, dynamic>{};
      final currentStatus =
      (bookingData['status'] ?? 'pending').toString().toLowerCase();

      if (currentStatus.contains('cancel')) return;

      final eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) {
        tx.set(
          bookingRef,
          {
            'status': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return;
      }

      final eventData = eventSnap.data() ?? <String, dynamic>{};
      final currentCount = (eventData['bookingsCount'] is num)
          ? (eventData['bookingsCount'] as num).toInt()
          : 0;

      final nextCount = (currentCount - 1);
      final safeNext = nextCount < 0 ? 0 : nextCount;

      tx.set(
        bookingRef,
        {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        eventRef,
        {
          'bookingsCount': safeNext,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }
}
