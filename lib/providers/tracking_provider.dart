import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../models/event_model.dart';
import '../services/location_service.dart';
import '../services/mqtt_service.dart';
import '../core/utils/geo_utils.dart';

class TrackingProvider extends ChangeNotifier {
  final MqttService _mqttService;
  late final LocationService _locationService;
  
  bool _isTracking = false;
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _totalDistance = 0.0; // in km
  double _elevationGain = 0.0; // in meters
  double _lastAltitude = -9999.0;
  int _currentRank = 0;
  int _totalParticipants = 0;
  List<Map<String, dynamic>> _otherRunners = [];
  DashlyLatLng? _currentPosition;
  Position? _lastGpsPosition;
  EventCategory _category = EventCategory.running;

  int _movingSeconds = 0;
  double _avgSpeed = 0.0; // in km/h
  DateTime? _lastMovementTimestamp;

  bool get isTracking => _isTracking;
  double get currentSpeed => _currentSpeed;
  double get maxSpeed => _maxSpeed;
  double get totalDistance => _totalDistance;
  double get avgSpeed => _avgSpeed;
  double get elevationGain => _elevationGain;
  double get currentAltitude {
    if (_lastGpsPosition != null && _lastGpsPosition!.altitude >= 0) {
      return _lastGpsPosition!.altitude;
    }
    if (_lastAltitude != -9999.0 && _lastAltitude >= 0) {
      return _lastAltitude;
    }
    return 0.0;
  }
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

  int? _activeEventId;
  int? get activeEventId => _activeEventId;

  Future<void> startTracking(int eventId, int userId, {EventCategory category = EventCategory.running}) async {
    print('PROV: 🏁 [DEBUG] startTracking triggered for event: $eventId, user: $userId');
    
    try {
      if (_isTracking && _activeEventId != null && _activeEventId != eventId) {
        print('PROV: 🔄 Switching active tracking from event $_activeEventId to $eventId. Stopping previous session.');
        await stopTracking();
      }
      _activeEventId = eventId;
      _isTracking = true;
      _isSosTriggered = false;
      _category = category;
      _movingSeconds = 0;
      _avgSpeed = 0.0;
      _maxSpeed = 0.0;
      _lastMovementTimestamp = null;
      _lastGpsPosition = null;
      _lastAltitude = -9999.0;
      _currentPosition = null;

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
        onPositionUpdate: (pos, {bool isPolling = false}) async {
          final newPos = DashlyLatLng(pos.latitude, pos.longitude);
          final double speedKmH = pos.speed * 3.6;

          // 1. FILTER: GPS Accuracy Filter (reject weak/drifted GPS samples > 15m)
          if (pos.accuracy > 0 && pos.accuracy > 15.0) {
            print('PROV: ⚠️ Skipping position update due to poor GPS accuracy (${pos.accuracy}m)');
            _currentPosition = newPos;
            _currentSpeed = speedKmH;
            notifyListeners();
            return;
          }
          
          // 2. DISTANCE DELTA CALCULATION
          if (_lastGpsPosition != null) {
            double distanceInMeters = Geolocator.distanceBetween(
              _lastGpsPosition!.latitude,
              _lastGpsPosition!.longitude,
              pos.latitude,
              pos.longitude,
            );

            // Filter out stationary noise (< 2.0m threshold OR speed < 0.5 km/h)
            // Also skip distance update on heartbeat polling if delta is tiny
            bool isMoving = speedKmH >= 0.5 || distanceInMeters >= 2.0;
            if (isMoving && (!isPolling || distanceInMeters >= 3.0)) {
              if (distanceInMeters >= 1.5) {
                _totalDistance += (distanceInMeters / 1000.0);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble(savedDistKey, _totalDistance);
              }
            }

            // Track active moving time
            if (isMoving) {
              if (_lastMovementTimestamp != null) {
                final int deltaSec = pos.timestamp.difference(_lastMovementTimestamp!).inSeconds;
                if (deltaSec > 0 && deltaSec < 30) {
                  _movingSeconds += deltaSec;
                }
              }
              _lastMovementTimestamp = pos.timestamp;
            }
          } else {
            _lastMovementTimestamp = pos.timestamp;
          }
          _lastGpsPosition = pos;

          // 3. AVG SPEED CALCULATION (Moving Time Based)
          if (_movingSeconds > 0 && _totalDistance > 0) {
            _avgSpeed = _totalDistance / (_movingSeconds / 3600.0);
          } else if (_totalDistance > 0 && speedKmH > 0) {
            _avgSpeed = speedKmH;
          }

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
          _currentSpeed = speedKmH;
          if (speedKmH > _maxSpeed) {
            _maxSpeed = speedKmH;
          }
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
    _activeEventId = null;
    _currentPosition = null;
    _isSosTriggered = false;
    _locationService.isFrozen = false;
    _mqttService.setTrackingActive(false);
    _locationService.stopTracking();
    _mqttService.publishStatus('OFFLINE');
    _lastGpsPosition = null;
    _lastAltitude = -9999.0;
    _movingSeconds = 0;
    _avgSpeed = 0.0;
    _maxSpeed = 0.0;
    _lastMovementTimestamp = null;
    
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
