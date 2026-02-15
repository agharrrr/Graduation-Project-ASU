import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_role.dart';

class AuthService {
  User? get currentUser => FirebaseAuth.instance.currentUser;
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ✅ Non-breaking: allows controllers/shells to re-init on account switch
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<AppRole> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();

    if (!doc.exists) {
      // Default to user if missing, but you can change this.
      return AppRole.user;
    }

    final data = doc.data();
    final roleStr = (data?['role'] ?? 'user').toString().toLowerCase();

    switch (roleStr) {
      case 'admin':
        return AppRole.admin;
      case 'organizer':
        return AppRole.organizer;
      default:
        return AppRole.user;
    }
  }

  Future<AppRole> signup({
    required String email,
    required String password,
    required AppRole role,
    String? name,
  }) async {
    // Admin accounts should be provisioned outside the public app.
    if (role == AppRole.admin) {
      throw Exception('Admin accounts are not created from the app.');
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = cred.user!.uid;
    final trimmedEmail = email.trim();
    final displayName = (name ?? '').trim();

    // Always create/merge the base user doc (role lives here in your app)
    await _db.collection('users').doc(uid).set({
      'email': trimmedEmail,
      'displayName': displayName,
      'role': role.name, // 'user' or 'organizer'
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ✅ Targeted: make sure each role has its own isolated profile doc/fields
    if (role == AppRole.organizer) {
      // Ensure organizers/{uid} exists so organizer settings are NOT shared.
      await _db.collection('organizers').doc(uid).set(
        {
          'id': uid,
          'name': displayName,
          'profileImageUrl': '',
          'coverImageUrl': '',
          'followersCount': 0,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } else {
      // role == user
      // Ensure onboarding-related fields exist for routing & personalization.
      await _db.collection('users').doc(uid).set(
        {
          'photoUrl': '',
          'notificationsEnabled': true,
          'language': 'en',
          'onboardingCompleted': false,
          'preferredCategories': <String>[],
          'favoriteOrganizerIds': <String>[],
          'city': '',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    return role;
  }
}
