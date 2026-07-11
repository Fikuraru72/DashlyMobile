import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import '../models/event_model.dart';
import 'mqtt_service.dart';
import 'offline_storage_service.dart';
import 'package:ulid/ulid.dart';

class LocationService {
  final MqttService _mqttService;
  StreamSubscription<Position>? _positionStream;
  Timer? _heartbeatTimer;
  Position? _lastPosition;

  LocationService(this._mqttService);

  Stream<Position> _createPositionStream() {
    LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1, // Fix for some Android ROMs that ignore 0
        forceLocationManager: false, // Use Fused Location Provider for GPS + Wi-Fi + Gyroscope sensor fusion (reduces drift)
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Running Dashly tracking in the background",
          notificationTitle: "Dashly Live Tracking",
          enableWakeLock: true,
        ),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      );
    }
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  Future<void> startTracking({
    required int eventId, 
    required int userId,
    EventCategory category = EventCategory.running,
    required void Function(Position) onPositionUpdate,
  }) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services disabled.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('Location permissions denied.');
    }
    if (permission == LocationPermission.deniedForever) throw Exception('Location permissions permanently denied.');

    try {
      // Try to get a fast lock from the last known position to prevent
      // being stuck in 'ACQUIRING GPS LOCK' indoors or on emulators.
      try {
        Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          print('📍 FAST LOCK: Found last known position');
          _lastPosition = lastKnown;
          onPositionUpdate(lastKnown);
          _publish(lastKnown, eventId, userId);
        }
      } catch (e) {
        print('TRACKER: ⚠️ Failed to get last known position: $e');
      }

      // Start the continuous stream


      _positionStream = _createPositionStream().listen(
        (Position position) {
          print('📍 RAW GPS HIT: Lat: ${position.latitude}, Lng: ${position.longitude}, isMocked: ${position.isMocked}, speed: ${position.speed}');
          _lastPosition = position;
          onPositionUpdate(position);
          _publish(position, eventId, userId);
        },
        onError: (e) => print('TRACKER: ❌ STREAM ERROR -> $e'),
        cancelOnError: false,
      );
    } catch (e) {
      print('TRACKER: ⚠️ Failed to initialize stream. $e');
    }

    // ── Heartbeat Timer & Polling Fallback ──
    // Some devices suppress GPS stream when stationary, starving the backend StopDetector.
    // Also, some devices completely fail to emit stream events. This polling acts as a bulletproof fallback.
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      try {
        // Fetch explicit position to bypass frozen streams
        Position currentPos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 3));
        
        print('💓 HEARTBEAT/POLL: Fetched explicit position: Lat: ${currentPos.latitude}, Lng: ${currentPos.longitude}');
        _lastPosition = currentPos;
        onPositionUpdate(currentPos);
        _publish(currentPos, eventId, userId);
      } catch (e) {
        print('💓 HEARTBEAT/POLL: Failed to get current position, using last known. Error: $e');
        if (_lastPosition != null) {
          final simulatedPosition = Position(
            longitude: _lastPosition!.longitude,
            latitude: _lastPosition!.latitude,
            timestamp: DateTime.now(),
            accuracy: _lastPosition!.accuracy,
            altitude: _lastPosition!.altitude,
            altitudeAccuracy: _lastPosition!.altitudeAccuracy,
            heading: _lastPosition!.heading,
            headingAccuracy: _lastPosition!.headingAccuracy,
            speed: 0.0,
            speedAccuracy: _lastPosition!.speedAccuracy,
            isMocked: _lastPosition!.isMocked,
          );
          _publish(simulatedPosition, eventId, userId);
        }
      }
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _heartbeatTimer?.cancel();
    _lastPosition = null;
  }

  void _publish(Position p, int eventId, int userId) {
    final String msgId = Ulid().toString();
    final DateTime capturedAt = DateTime.now();
    
    if (_mqttService.isConnected) {
      _mqttService.publishLocation(
        eventId: eventId,
        userId: userId,
        lat: p.latitude,
        lng: p.longitude,
        speed: p.speed * 3.6,
        status: 'moving',
        isAnomaly: false,
        msgId: msgId,
        timestamp: capturedAt,
      );
      _mqttService.publishPocLocation(p.latitude, p.longitude);
    } else {
      OfflineStorageService.saveLocation(
        msgId: msgId,
        eventId: eventId,
        userId: userId,
        lat: p.latitude,
        lng: p.longitude,
        speed: p.speed * 3.6,
        status: 'moving',
        isAnomaly: false,
        timestamp: capturedAt,
      );
    }
  }
}
