import 'dart:async';
import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../services/location_service.dart';
import '../services/mqtt_service.dart';
import '../services/event_service.dart';
import '../core/utils/geo_utils.dart';

class TrackingProvider extends ChangeNotifier {
  final MqttService _mqttService;
  late final LocationService _locationService;
  
  bool _isTracking = false;
  double _currentSpeed = 0.0;
  double _totalDistance = 0.0;
  int _currentRank = 12;
  DashlyLatLng? _currentPosition;
  EventCategory _category = EventCategory.running;

  bool get isTracking => _isTracking;
  double get currentSpeed => _currentSpeed;
  double get totalDistance => _totalDistance;
  int get currentRank => _currentRank;
  DashlyLatLng? get currentPosition => _currentPosition;
  bool get isMqttConnected => _mqttService.isConnected;
  EventCategory get category => _category;

  TrackingProvider({MqttService? mqttService, LocationService? locationService})
      : _mqttService = mqttService ?? MqttService() {
    _locationService = locationService ?? LocationService(_mqttService);
  }

  bool _isSosTriggered = false;
  bool get isSosTriggered => _isSosTriggered;
  
  double _progressPercentage = 0.0;
  int _checkpointsCompleted = 0;
  Timer? _statsTimer;
  
  double get progressPercentage => _progressPercentage;
  int get checkpointsCompleted => _checkpointsCompleted;

  Future<void> startTracking(int eventId, int userId, {EventCategory category = EventCategory.running}) async {
    print('PROV: 🏁 [DEBUG] startTracking triggered for event: $eventId, user: $userId');
    
    try {
      _isTracking = true;
      _isSosTriggered = false;
      _totalDistance = 0.0;
      _currentRank = 0;
      _progressPercentage = 0.0;
      _checkpointsCompleted = 0;
      _category = category;
      notifyListeners();

      print('PROV: 📡 [DEBUG] Step 1: Connecting MQTT...');
      bool mqttSuccess = await _mqttService.connect(eventId, userId);
      if (!mqttSuccess) {
        print('PROV: ⚠️ [DEBUG] MQTT failed to connect (continuing with offline buffering)');
      } else {
        print('PROV: 🚦 Tracking explicitly activated. Emitting ONLINE status.');
        _mqttService.setTrackingActive(true);
        _mqttService.publishStatus('ONLINE');
      }
      
      print('PROV: 📍 [DEBUG] Step 2: Initializing Location Service...');
      await _locationService.startTracking(
        eventId: eventId, 
        userId: userId,
        category: category,
        onPositionUpdate: (pos) {
          final newPos = DashlyLatLng(pos.latitude, pos.longitude);
          _currentPosition = newPos;
          _currentSpeed = pos.speed * 3.6; // m/s to km/h
          notifyListeners();
        },
      );
      
      // Start polling live stats every 5 seconds
      _statsTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        if (!_isTracking) {
          timer.cancel();
          return;
        }
        final stats = await EventService().getLiveStats(eventId);
        if (stats != null) {
          _currentRank = stats['rank'] ?? 0;
          _progressPercentage = (stats['progressPercentage'] ?? 0.0).toDouble();
          _totalDistance = (stats['distanceCovered'] ?? 0.0).toDouble() / 1000.0; // from m to km
          _checkpointsCompleted = stats['checkpointsCompleted'] ?? 0;
          notifyListeners();
        }
      });
      
      // Let the LocationService drive the actual GPS tracking loop without UI listeners
      notifyListeners();
    } catch (e, stack) {
      print('PROV: 💥 [DEBUG] CRITICAL FAILURE in startTracking: $e');
      print(stack);
      stopTracking();
      rethrow;
    }
  }

  Future<void> stopTracking() async {
    print('PROV: 🛑 [DEBUG] stopTracking triggered');
    _statsTimer?.cancel();
    _isTracking = false;
    _isSosTriggered = false;
    _mqttService.setTrackingActive(false);
    _locationService.stopTracking();
    _mqttService.publishStatus('OFFLINE');
    // Wait briefly to allow the TCP buffer to flush the OFFLINE message before disconnecting
    await Future.delayed(const Duration(milliseconds: 500));
    _mqttService.disconnect();
    notifyListeners();
  }

  Future<bool> triggerSos() async {
    if (!_isTracking || _currentPosition == null) {
      print('PROV: ⚠️ Cannot trigger SOS: not tracking or no GPS fix.');
      return false;
    }
    print('PROV: 🚨 [DEBUG] SOS TRIGGERED!');
    _isSosTriggered = true;
    _mqttService.publishSos(_currentPosition!.latitude, _currentPosition!.longitude);
    notifyListeners();
    return true;
  }
}
