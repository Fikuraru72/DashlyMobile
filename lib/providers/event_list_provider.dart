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

  final EventService _eventService = EventService();

  Future<void> loadExploreEvents() async {
    _isLoadingExplore = true;
    notifyListeners();
    
    final events = await _eventService.getExploreEvents();
    if (events != null) {
      _exploreEvents = events;
      // Merge participant data from myEvents if available
      _mergeParticipantData();
    }
    
    _isLoadingExplore = false;
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
