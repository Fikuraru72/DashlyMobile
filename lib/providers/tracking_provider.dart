import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
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
  double _totalDistance = 0.0; // in km
  double _elevationGain = 0.0; // in meters
  double _lastAltitude = -9999.0;
  int _currentRank = 0;
  int _totalParticipants = 0;
  List<Map<String, dynamic>> _otherRunners = [];
  DashlyLatLng? _currentPosition;
  Position? _lastGpsPosition;
  EventCategory _category = EventCategory.running;

  bool get isTracking => _isTracking;
  double get currentSpeed => _currentSpeed;
  double get totalDistance => _totalDistance;
  double get elevationGain => _elevationGain;
  int get currentRank => _currentRank;
  int get totalParticipants => _totalParticipants;
  List<Map<String, dynamic>> get otherRunners => _otherRunners;
  DashlyLatLng? get currentPosition => _currentPosition;
  bool get isMqttConnected => _mqttService.isConnected;
  EventCategory get category => _category;

  TrackingProvider({MqttService? mqttService, LocationService? locationService})
      : _mqttService = mqttService ?? MqttService() {
    _locationService = locationService ?? LocationService(_mqttService);

    // Listen for broadcast payload from backend (sharded proximity runners + rank)
    _mqttService.onDistancesReceived = (data) {
      if (data.containsKey('rank')) {
        _currentRank = (data['rank'] as num).toInt();
      }
      if (data.containsKey('total')) {
        _totalParticipants = (data['total'] as num).toInt();
      }
      if (data.containsKey('runners') && data['runners'] is List) {
        _otherRunners = List<Map<String, dynamic>>.from(data['runners']);
      }
      notifyListeners();
    };
  }

  bool _isSosTriggered = false;
  bool get isSosTriggered => _isSosTriggered;

  Future<void> startTracking(int eventId, int userId, {EventCategory category = EventCategory.running}) async {
    print('PROV: 🏁 [DEBUG] startTracking triggered for event: $eventId, user: $userId');
    
    try {
      _isTracking = true;
      _isSosTriggered = false;
      _category = category;

      // Load persistent distance from SharedPreferences if available
      final prefs = await SharedPreferences.getInstance();
      final savedDistKey = 'event_${eventId}_accumulated_dist';
      final savedAltKey = 'event_${eventId}_elevation_gain';
      _totalDistance = prefs.getDouble(savedDistKey) ?? 0.0;
      _elevationGain = prefs.getDouble(savedAltKey) ?? 0.0;

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
        onPositionUpdate: (pos) async {
          final newPos = DashlyLatLng(pos.latitude, pos.longitude);
          
          // Calculate distance delta using Haversine
          if (_lastGpsPosition != null) {
            double distanceInMeters = Geolocator.distanceBetween(
              _lastGpsPosition!.latitude,
              _lastGpsPosition!.longitude,
              pos.latitude,
              pos.longitude,
            );
            // Filter noise < 1m
            if (distanceInMeters >= 1.0) {
              _totalDistance += (distanceInMeters / 1000.0);
              // Save to SharedPreferences for persistence across restarts
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble(savedDistKey, _totalDistance);
            }
          }
          _lastGpsPosition = pos;

          // Calculate elevation gain
          if (pos.altitude != 0) {
            if (_lastAltitude != -9999.0) {
              double altDiff = pos.altitude - _lastAltitude;
              if (altDiff > 1.0) { // threshold 1m
                _elevationGain += altDiff;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble(savedAltKey, _elevationGain);
              }
            }
            _lastAltitude = pos.altitude;
          }

          _currentPosition = newPos;
          _currentSpeed = pos.speed * 3.6; // m/s to km/h
          notifyListeners();
        },
      );
      
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
    _isTracking = false;
    _isSosTriggered = false;
    _locationService.isFrozen = false;
    _mqttService.setTrackingActive(false);
    _locationService.stopTracking();
    _mqttService.publishStatus('OFFLINE');
    _lastGpsPosition = null;
    _lastAltitude = -9999.0;
    
    // Clear persistent distance state when race is officially stopped
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('event_'));
    for (var key in keys) {
      await prefs.remove(key);
    }

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
    _locationService.isFrozen = true;
    _mqttService.publishSos(_currentPosition!.latitude, _currentPosition!.longitude);
    notifyListeners();
    return true;
  }
}
