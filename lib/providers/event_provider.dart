import 'dart:async';
import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

class EventProvider extends ChangeNotifier {
  final EventService _eventService = EventService();

  bool _isRedeeming = false;
  String? _successMessage;
  String? _errorMessage;
  Event? _currentEvent;
  Timer? _pollTimer;

  List<Event> _myEvents = [];
  bool _isLoadingMyEvents = false;
  String? _myEventsError;

  bool get isRedeeming => _isRedeeming;
  String? get successMessage => _successMessage;
  String? get errorMessage => _errorMessage;
  Event? get currentEvent => _currentEvent;

  List<Event> get myEvents => _myEvents;
  bool get isLoadingMyEvents => _isLoadingMyEvents;
  String? get myEventsError => _myEventsError;

  void _setLoading(bool value) {
    _isRedeeming = value;
    notifyListeners();
  }

  void clearMessages() {
    _successMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadMyEvents({bool isSilent = false}) async {
    if (!isSilent && _myEvents.isEmpty) {
      _isLoadingMyEvents = true;
      _myEventsError = null;
      notifyListeners();
    }

    try {
      final events = await _eventService.getMyEvents();
      if (events != null) {
        _myEvents = events;
        _myEventsError = null;
      } else if (_myEvents.isEmpty) {
        _myEventsError = 'Failed to load your events.';
        _myEvents = [];
      }
    } catch (e) {
      if (_myEvents.isEmpty) {
        _myEventsError = e.toString();
        _myEvents = [];
      }
    } finally {
      _isLoadingMyEvents = false;
      notifyListeners();
    }
  }

  /// Joins an event directly.
  /// Returns join data including eventId for navigation to interlock screen.
  Future<Map<String, dynamic>?> joinEvent(int eventId) async {
    _setLoading(true);
    _errorMessage = null;
    _successMessage = null;

    try {
      final data = await _eventService.joinEvent(eventId);
      if (data['success'] == true) {
        _successMessage = data['message'];
        await loadMyEvents(); // Auto refresh myEvents
        _setLoading(false);
        return data; // Return full data for navigation
      } else {
        _errorMessage = data['message'] ?? 'Failed to join event';
        _setLoading(false);
        return null;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return null;
    }
  }

  /// Joins an event via a 6-character token.
  /// Returns join data including eventId for navigation to interlock screen.
  Future<Map<String, dynamic>?> joinEventViaToken(String token) async {
    _setLoading(true);
    _errorMessage = null;
    _successMessage = null;

    try {
      final data = await _eventService.joinEventViaToken(token);
      if (data['success'] == true) {
        _successMessage = data['message'];
        await loadMyEvents(); // Auto refresh myEvents
        _setLoading(false);
        return data; // Return full data for navigation
      } else {
        _errorMessage = data['message'] ?? 'Failed to join event';
        _setLoading(false);
        return null;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return null;
    }
  }

  /// Fetches full event details and stores as currentEvent.
  Future<Event?> fetchEvent(int eventId) async {
    final event = await _eventService.fetchEventDetails(eventId);
    if (event != null) {
      _currentEvent = event;
      notifyListeners();
    }
    return event;
  }

  /// Starts polling event status every N seconds for the interlock screen.
  void startPolling(int eventId) {
    stopPolling(); // Cancel any existing timer
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        final statusData = await _eventService.pollEventStatus(eventId);
        if (statusData != null && _currentEvent != null) {
          // Rebuild event with updated status
          final updatedJson = _currentEvent!.toJson();
          updatedJson['status'] = statusData['status'];
          updatedJson['monitoringWindow'] = statusData['monitoringWindow'];
          if (statusData['category'] != null) {
            updatedJson['category'] = statusData['category'];
          }
          _currentEvent = Event.fromJson(updatedJson);
          notifyListeners();
        }
      },
    );
  }

  /// Fetches the participant's ticket (contains bibNumber, etc.)
  Future<Map<String, dynamic>?> fetchParticipantTicket(int eventId) async {
    return await _eventService.getParticipantTicket(eventId);
  }

  /// Stops polling event status.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
