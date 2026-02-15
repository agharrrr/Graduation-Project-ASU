import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventActions {
  EventActions._();
  static final EventActions instance = EventActions._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const double serviceFeeRate = 0.03;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('not-authenticated');
    return user.uid;
  }

  String _bookingDocId(String eventId, String uid) => '${eventId}_$uid';

  CollectionReference<Map<String, dynamic>> get _userBookingsCol =>
      _db.collection('users').doc(_uid).collection('bookings');

  DocumentReference<Map<String, dynamic>> _bookingRefExpected(String eventId) {
    final uid = _uid;
    return _userBookingsCol.doc(_bookingDocId(eventId, uid));
  }

  /// If the "expected" booking doc doesn't exist, fall back to query by eventId.
  Future<DocumentReference<Map<String, dynamic>>?> _resolveBookingRef(String eventId) async {
    final expected = _bookingRefExpected(eventId);
    final expectedSnap = await expected.get();
    if (expectedSnap.exists) return expected;

    final q = await _userBookingsCol.where('eventId', isEqualTo: eventId).limit(1).get();
    if (q.docs.isEmpty) return null;

    return q.docs.first.reference;
  }

  Future<bool> hasBooking(String eventId) async {
    final ref = await _resolveBookingRef(eventId);
    if (ref == null) return false;

    final snap = await ref.get();
    if (!snap.exists) return false;

    final data = snap.data() ?? <String, dynamic>{};
    final status = (data['status'] ?? '').toString().toLowerCase();

    if (status.contains('cancel') || status.contains('reject')) return false;
    return true;
  }

  Future<void> bookEvent(
      String eventId, {
        Map<String, dynamic>? payment,
      }) async {
    await _bookInternal(eventId: eventId, payment: payment);
  }

  double _round2(double v) => (v * 100).roundToDouble() / 100.0;

  Future<void> _bookInternal({
    required String eventId,
    Map<String, dynamic>? payment,
  }) async {
    final uid = _uid;

    final eventRef = _db.collection('events').doc(eventId);
    final bookingRef = _bookingRefExpected(eventId);

    await _db.runTransaction((tx) async {
      final eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) throw Exception('event-not-found');

      final data = eventSnap.data() as Map<String, dynamic>;

      final int capacity = (data['capacity'] is num) ? (data['capacity'] as num).toInt() : 0;
      final int currentBookings = (data['bookingsCount'] is num) ? (data['bookingsCount'] as num).toInt() : 0;

      final bool isCapacityLimited = capacity > 0;
      final bool isFull = isCapacityLimited && currentBookings >= capacity;
      if (isFull) throw Exception('event-full');

      final Timestamp? startTs = data['startDateTime'] as Timestamp?;
      final Timestamp? endTs = data['endDateTime'] as Timestamp?;
      final DateTime startDt = startTs?.toDate() ?? DateTime.now();
      final DateTime endDt = endTs?.toDate() ?? startDt;

      // ✅ NEW: block booking after event ends (backend enforcement)
      if (endDt.isBefore(DateTime.now())) throw Exception('event-ended');

      // prevent double-booking
      final bookingSnap = await tx.get(bookingRef);
      if (bookingSnap.exists) {
        final b = bookingSnap.data() ?? <String, dynamic>{};
        final status = (b['status'] ?? '').toString().toLowerCase();
        final canRebook = status.contains('cancel') || status.contains('reject');
        if (!canRebook) throw Exception('already-booked');
      }

      final organizerId = (data['organizerId'] ?? '').toString();
      final eventTitle = (data['title'] ?? '').toString();

      final String location = (data['location'] ?? '').toString();
      final String category = (data['category'] ?? '').toString();
      final String coverImageUrl = (data['coverImageUrl'] ?? '').toString();
      final String city = (data['city'] ?? '').toString().trim();

      final bool isPaidEvent = (data['isPaid'] == true);
      final int price = (data['price'] is num) ? (data['price'] as num).toInt() : 0;

      if (isPaidEvent) {
        final txId = (payment?['transactionId'] ?? '').toString().trim();
        if (txId.isEmpty) throw Exception('payment-required');
      }

      final double subtotal = isPaidEvent ? price.toDouble() : 0.0;
      final double fee = isPaidEvent ? _round2(subtotal * serviceFeeRate) : 0.0;
      final double total = isPaidEvent ? _round2(subtotal + fee) : 0.0;

      final Map<String, dynamic> paymentFields = {};
      if (isPaidEvent) {
        paymentFields.addAll({
          'isPaid': true,
          'subtotalPrice': subtotal,
          'serviceFee': fee,
          'totalPrice': total,
          'paymentMethod': 'card',
          'paymentStatus': 'paid',
          'brand': (payment?['brand'] ?? '').toString(),
          'last4': (payment?['last4'] ?? '').toString(),
          'transactionId': (payment?['transactionId'] ?? '').toString(),
          if ((payment?['paymentIntentId'] ?? '').toString().isNotEmpty)
            'paymentIntentId': (payment?['paymentIntentId'] ?? '').toString(),
        });
      } else {
        paymentFields.addAll({
          'isPaid': false,
          'subtotalPrice': 0.0,
          'serviceFee': 0.0,
          'totalPrice': 0.0,
          'paymentMethod': 'none',
          'paymentStatus': 'free',
        });
      }

      tx.set(
        bookingRef,
        {
          'bookingId': bookingRef.id,
          'eventId': eventId,
          'eventTitle': eventTitle,
          'organizerId': organizerId,
          'userId': uid,
          'startDateTime': Timestamp.fromDate(startDt),
          'endDateTime': Timestamp.fromDate(endDt),
          'location': location,
          'category': category,
          'coverImageUrl': coverImageUrl,
          if (city.isNotEmpty) 'city': city,
          'status': 'confirmed',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          ...paymentFields,
        },
        SetOptions(merge: true),
      );

      tx.set(
        eventRef,
        {
          'bookingsCount': currentBookings + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> cancelBooking(String eventId) async {
    final bookingRef = await _resolveBookingRef(eventId);
    if (bookingRef == null) {
      throw Exception('booking-not-found');
    }

    final eventRef = _db.collection('events').doc(eventId);

    final snap = await bookingRef.get();
    if (!snap.exists) throw Exception('booking-not-found');

    final data = snap.data() ?? <String, dynamic>{};
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status.contains('cancel')) return;

    final bool isPaid = (data['isPaid'] == true);

    // Cancel booking doc FIRST
    await bookingRef.set(
      {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
        if (isPaid) 'refundRequested': true,
        if (isPaid) 'refundStatus': 'requested',
        if (isPaid) 'refundRequestedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Best-effort decrement
    try {
      await eventRef.set(
        {
          'bookingsCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}
