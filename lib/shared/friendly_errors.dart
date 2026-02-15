import 'package:firebase_auth/firebase_auth.dart';

class FriendlyErrors {
  FriendlyErrors._();

  static String generic() => 'Something went wrong. Please try again.';

  static String fromAuth(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'user-not-found':
        case 'wrong-password':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'This email is already registered. Please log in instead.';
        case 'weak-password':
          return 'Your password is too weak. Use at least 6 characters.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again in a few minutes.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled.';
        default:
          return e.message ?? generic();
      }
    }
    return generic();
  }

  static String fromUnknown(Object e) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('network') || msg.contains('socket')) {
      return 'No internet connection. Please check your connection and try again.';
    }

    if (msg.contains('permission-denied') || msg.contains('permission denied')) {
      return 'You do not have permission to do this action.';
    }

    if (msg.contains('not-found')) {
      return 'The requested data was not found. Please refresh and try again.';
    }

    return generic();
  }
}
