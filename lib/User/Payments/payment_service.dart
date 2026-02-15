import 'package:cloud_functions/cloud_functions.dart';

class PaymentService {
  PaymentService._();
  static final instance = PaymentService._();

  final _functions = FirebaseFunctions.instance;

  /// amount in smallest currency unit:
  /// For JOD, Stripe uses 2 decimals in most cases (e.g., 10.00 JOD => 1000).
  /// If you want "JD integer" only, multiply by 100 to represent 2 decimals.
  Future<Map<String, dynamic>> createPaymentIntent({
    required int amountMinor,
    required String currency,
    required String eventId,
  }) async {
    final callable = _functions.httpsCallable('createPaymentIntent');
    final res = await callable.call({
      'amount': amountMinor,
      'currency': currency,
      'eventId': eventId,
    });

    final data = Map<String, dynamic>.from(res.data as Map);
    // expected: {clientSecret, paymentIntentId}
    return data;
  }
}
