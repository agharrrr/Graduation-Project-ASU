// lib/Organizer/organizer_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../Auth/auth_service.dart';
import 'Models/event_post.dart';
import 'Models/organizer_model.dart';
import 'Widgets/organizer_repository.dart';

class OrganizerController extends ChangeNotifier {
  final OrganizerRepository _repository;
  final AuthService _auth;

  OrganizerController(this._repository, this._auth) {
    _init();
  }

  OrganizerModel? organizer;
  List<EventPost> events = [];

  bool isLoading = true;
  String? errorMessage;

  StreamSubscription<OrganizerModel?>? _organizerSub;
  StreamSubscription<List<EventPost>>? _eventsSub;

  // ---------- Getters ----------
  String get organizerId => _auth.currentUser?.uid ?? '';

  String get organizerName {
    final fromModel = organizer?.name?.trim() ?? '';
    final fromAuth = _auth.currentUser?.displayName?.trim() ?? '';

    final name = fromModel.isNotEmpty ? fromModel : fromAuth;
    return name.isNotEmpty ? name : 'Organizer';
  }

  String? get coverImageUrl => organizer?.coverImageUrl;
  String? get profileImageUrl => organizer?.profileImageUrl;

  // ---------- Init & subscriptions ----------
  Future<void> _init() async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      if (organizerId.isEmpty) {
        errorMessage = 'Not signed in.';
        return;
      }

      // Keep organizer profile in sync (cover/profile/name updates should reflect immediately)
      await _organizerSub?.cancel();
      _organizerSub = _repository.watchOrganizer(organizerId).listen((m) {
        organizer = m;
        notifyListeners();
      });

      // Initial fetch (useful if stream is slow on first load)
      organizer = await _repository.getOrganizer(organizerId);

      // Events live stream
      await _eventsSub?.cancel();
      _eventsSub = _repository.watchOrganizerEvents(organizerId).listen((list) {
        events = list;
        notifyListeners();
      });
    } catch (e, st) {
      debugPrint('OrganizerController _init error: $e\n$st');
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Used by RefreshIndicator.
  Future<void> refreshEvents() async {
    try {
      errorMessage = null;

      if (organizerId.isEmpty) {
        errorMessage = 'Not signed in.';
        return;
      }

      final fresh = await _repository.fetchOrganizerEvents(organizerId);
      events = fresh;
    } catch (e, st) {
      debugPrint('OrganizerController.refreshEvents error: $e\n$st');
      errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  /// Used after saving settings (optional now, because stream will update anyway).
  Future<void> refreshOrganizerProfile() async {
    try {
      errorMessage = null;

      if (organizerId.isEmpty) {
        errorMessage = 'Not signed in.';
        return;
      }

      organizer = await _repository.getOrganizer(organizerId);
    } catch (e, st) {
      debugPrint('OrganizerController.refreshOrganizerProfile error: $e\n$st');
      errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> saveEvent(EventPost event) => _repository.saveEvent(event);

  @override
  void dispose() {
    _organizerSub?.cancel();
    _eventsSub?.cancel();
    super.dispose();
  }
}
