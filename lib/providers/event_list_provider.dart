import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

class EventListProvider extends ChangeNotifier {
  List<Event> _exploreEvents = [];
  List<Event> _myEvents = [];

  List<Event> get exploreEvents => _exploreEvents;
  List<Event> get myEvents => _myEvents;
  
  bool _isLoadingExplore = false;
  bool get isLoadingExplore => _isLoadingExplore;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  int _page = 1;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  final EventService _eventService = EventService();

  void _sortEventsDescending(List<Event> events) {
    events.sort((a, b) => b.dateEvent.compareTo(a.dateEvent));
  }

  Future<void> loadExploreEvents() async {
    _page = 1;
    _hasMore = true;
    _isLoadingExplore = true;
    notifyListeners();
    
    final events = await _eventService.getExploreEvents();
    if (events != null) {
      _sortEventsDescending(events);
      _exploreEvents = events;
      _mergeParticipantData();
    }
    
    _isLoadingExplore = false;
    notifyListeners();
  }

  Future<void> loadMoreExploreEvents() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    _page++;
    final moreEvents = await _eventService.getExploreEvents();
    if (moreEvents != null && moreEvents.isNotEmpty) {
      _sortEventsDescending(moreEvents);
      // Filter out duplicates
      for (final event in moreEvents) {
        if (!_exploreEvents.any((e) => e.id == event.id)) {
          _exploreEvents.add(event);
        }
      }
      _mergeParticipantData();
    } else {
      _hasMore = false;
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Also loads my events to have participant data (bibNumber, participantState)
  Future<void> loadMyEventsForMerge() async {
    final events = await _eventService.getMyEvents();
    if (events != null) {
      _myEvents = events;
      _mergeParticipantData();
      notifyListeners();
    }
  }

  /// Merges participant-specific data from myEvents into exploreEvents
  /// so that isJoined() and bibNumber work from the Explore screen too.
  void _mergeParticipantData() {
    if (_myEvents.isEmpty) return;
    
    for (int i = 0; i < _exploreEvents.length; i++) {
      final myEvent = _myEvents.where((e) => e.id == _exploreEvents[i].id).firstOrNull;
      if (myEvent != null) {
        _exploreEvents[i] = _exploreEvents[i].copyWith(
          participantState: myEvent.participantState ?? ParticipantState.registered,
          bibNumber: myEvent.bibNumber,
        );
      }
    }
  }

  bool isJoined(int eventId) {
    // Check explore events first
    final exploreEvent = _exploreEvents.where((e) => e.id == eventId).firstOrNull;
    if (exploreEvent != null && exploreEvent.participantState != null) {
      return true;
    }
    // Also check myEvents as fallback
    final myEvent = _myEvents.where((e) => e.id == eventId).firstOrNull;
    if (myEvent != null) {
      return true;
    }
    return false;
  }

  /// Gets the event with full participant data (prefers myEvents data)
  Event? getEventWithParticipantData(int eventId) {
    final myEvent = _myEvents.where((e) => e.id == eventId).firstOrNull;
    if (myEvent != null) return myEvent;
    return _exploreEvents.where((e) => e.id == eventId).firstOrNull;
  }

  Future<Map<String, dynamic>> joinEvent(int eventId) async {
    final result = await _eventService.joinEvent(eventId);
    
    if (result['success'] == true) {
      final eventIndex = _exploreEvents.indexWhere((e) => e.id == eventId);
      if (eventIndex != -1) {
        _exploreEvents[eventIndex] = _exploreEvents[eventIndex].copyWith(
          currentCount: _exploreEvents[eventIndex].currentCount + 1,
          participantState: ParticipantState.registered,
          bibNumber: result['bibNumber']?.toString(),
        );
      }
      
      notifyListeners();
    }
    
    return result;
  }

  Future<Map<String, dynamic>> verifyBib(int eventId, String bibNumber) async {
    final result = await _eventService.verifyBib(eventId, bibNumber);
    
    if (result['success'] == true) {
      final eventIndex = _exploreEvents.indexWhere((e) => e.id == eventId);
      if (eventIndex != -1) {
        _exploreEvents[eventIndex] = _exploreEvents[eventIndex].copyWith(
          participantState: ParticipantState.confirmed,
        );
      }
      notifyListeners();
    }
    
    return result;
  }
}
