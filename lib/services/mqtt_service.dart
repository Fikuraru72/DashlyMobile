import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/app_constants.dart';
import 'offline_storage_service.dart';
import 'package:battery_plus/battery_plus.dart';

/// ════════════════════════════════════════════════════════════════
/// Dashly Phase 7 — MQTT Service (TCP on port 1883)
/// ════════════════════════════════════════════════════════════════
/// Connects to the Aedes broker via raw TCP (NOT WebSocket).
/// WebSocket is only used by the web dashboard.
/// ════════════════════════════════════════════════════════════════
class MqttService {
  late MqttServerClient _client;
  final Battery _battery = Battery();
  bool _isConnected = false;
  Timer? _reconnectTimer;

  bool get isConnected => _isConnected;

  int? _currentEventId;
  int? _currentUserId;

  bool _isTrackingActive = false;
  void setTrackingActive(bool isActive) {
    _isTrackingActive = isActive;
  }

  MqttService() {
    _initClient();
  }

  void _initClient() {
    _client = MqttServerClient.withPort(
      AppConstants.mqttHost,
      'dashly_mobile_${DateTime.now().millisecondsSinceEpoch}',
      AppConstants.mqttPort,
    );

    _client.logging(on: false);
    _client.keepAlivePeriod = 0; // 0 disables the keep-alive timeout completely
    _client.autoReconnect = true;
    _client.resubscribeOnAutoReconnect = true;

    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    _client.onAutoReconnect = _onAutoReconnect;
    _client.onAutoReconnected = _onAutoReconnected;
  }

  /// Connect to the MQTT broker with retry logic.
  Future<bool> connect(int eventId, int userId) async {
    // If switching to a different event while connected, cleanly disconnect previous event session first
    if (_isConnected && _currentEventId != null && _currentEventId != eventId) {
      print('MQTT: 🔄 Switching event from $_currentEventId to $eventId. Disconnecting previous session...');
      publishStatus('OFFLINE');
      disconnect();
      await Future.delayed(const Duration(milliseconds: 300));
      _initClient();
    }

    _currentEventId = eventId;
    _currentUserId = userId;
    
    if (_isConnected) return true;

    // Load JWT token for MQTT broker authentication
    const secureStorage = FlutterSecureStorage();
    String? jwtToken = await secureStorage.read(key: 'auth_token');
    if (jwtToken == null || jwtToken.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      jwtToken = prefs.getString('auth_token');
    }
    jwtToken = jwtToken ?? '';

    // Configure Last Will and Testament (LWT) before connecting
    final String willTopic = 'dashly/events/$eventId/p/$userId/status';
    final String willMessage = jsonEncode({'status': 'OFFLINE', 'isOffline': true});
    
    final connMessage = MqttConnectMessage()
        .withClientIdentifier('dashly_mobile_${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .withWillTopic(willTopic)
        .withWillMessage(willMessage)
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain()
        .authenticateAs(userId.toString(), jwtToken);
    _client.connectionMessage = connMessage;

    try {
      print('MQTT: Connecting to ${AppConstants.mqttHost}:${AppConstants.mqttPort} (TCP)...');
      await _client.connect();
      return _isConnected;
    } on NoConnectionException catch (e) {
      print('MQTT: NoConnectionException - Broker unreachable. Check IP/Firewall. $e');
      _client.disconnect();
      _scheduleReconnect();
      return false;
    } on SocketException catch (e) {
      print('MQTT: SocketException - $e');
      _client.disconnect();
      _scheduleReconnect();
      return false;
    } catch (e) {
      print('MQTT: Unknown error - $e');
      _client.disconnect();
      _scheduleReconnect();
      return false;
    }
  }

  bool _isManualDisconnect = false;

  void disconnect() {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnected = false;
    try {
      _client.disconnect();
    } catch (_) {}
  }

  // ── Callbacks ─────────────────────────────────────────────

  void Function(Map<String, dynamic>)? onDistancesReceived;

  void _onConnected() {
    _isConnected = true;
    _isManualDisconnect = false;
    _reconnectTimer?.cancel();
    print('MQTT: ✅ Connected Successfully to ${AppConstants.mqttHost}:${AppConstants.mqttPort}');

    if (_currentEventId != null && _currentUserId != null) {
      final distanceTopic = 'dashly/events/$_currentEventId/p/$_currentUserId/distances';
      _client.subscribe(distanceTopic, MqttQos.atMostOnce);
      print('MQTT: 📥 Subscribed to broadcast topic: $distanceTopic');

      _client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        for (var msg in messages) {
          final recMsg = msg.payload as MqttPublishMessage;
          final payloadStr = MqttPublishPayload.bytesToStringAsString(recMsg.payload.message);
          try {
            final data = jsonDecode(payloadStr) as Map<String, dynamic>;
            onDistancesReceived?.call(data);
          } catch (e) {
            print('MQTT: Failed to parse broadcast payload: $e');
          }
        }
      });
    }
    
    if (_isTrackingActive) {
      publishStatus('ONLINE');
    } else {
      print('MQTT: ⚠️ Suppressed ONLINE status ping because tracking is not active yet.');
    }
    _syncOfflineData();
  }

  void _onDisconnected() {
    _isConnected = false;
    print('MQTT: ❌ Disconnected');
    if (!_isManualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _onAutoReconnect() {
    print('MQTT: 🔄 Auto-reconnecting...');
  }

  void _onAutoReconnected() {
    _isConnected = true;
    print('MQTT: ✅ Auto-reconnected!');
    if (_isTrackingActive) {
      publishStatus('ONLINE');
    } else {
      print('MQTT: ⚠️ Suppressed ONLINE status ping because tracking is not active yet.');
    }
    _syncOfflineData();
  }

  Future<void> _syncOfflineData() async {
    if (_currentEventId == null || _currentUserId == null) return;
    
    final offlineData = await OfflineStorageService.getOfflineLocations();
    if (offlineData.isEmpty) return;

    print('MQTT: 📦 Found ${offlineData.length} offline locations. Syncing...');
    
    final topic = 'dashly/events/$_currentEventId/p/$_currentUserId/sync';
    
    // Batch all points into a JSON array
    final payload = jsonEncode(offlineData);
    
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    
    // Publish with QoS 1 and capture the message identifier
    final msgId = _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    
    print('MQTT: 📤 [SYNC] Published batch (msgId: $msgId) to $topic. Waiting for ACK...');
    
    // Wait for the broker to acknowledge the message (PUBACK)
    // The mqtt_client library emits published messages on this stream for QoS 1
    try {
      await _client.published!
          .where((MqttPublishMessage msg) => msg.variableHeader!.messageIdentifier == msgId)
          .first
          .timeout(const Duration(seconds: 10));
      
      // ACK received — now safe to delete
      await OfflineStorageService.clearOfflineLocations();
      print('MQTT: ✅ [SYNC] PUBACK received. Local offline data cleared.');
    } on TimeoutException {
      print('MQTT: ⚠️ [SYNC] PUBACK timeout. Keeping local data for retry.');
      // Data remains in sqflite and will be retried on next reconnect
    } catch (e) {
      print('MQTT: ❌ [SYNC] Error waiting for PUBACK: $e. Keeping local data.');
    }
  }

  /// Schedule a reconnect attempt after 5 seconds.
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && _currentEventId != null && _currentUserId != null) {
        print('MQTT: ♻️ Attempting manual reconnect...');
        connect(_currentEventId!, _currentUserId!);
      }
    });
  }

  // ── Publishing ────────────────────────────────────────────

  /// Publish a generic status (e.g., OFFLINE for manual disconnect)
  void publishStatus(String status) {
    if (!_isConnected || _currentEventId == null || _currentUserId == null) return;
    
    final String topic = 'dashly/events/$_currentEventId/p/$_currentUserId/status';
    final String payload = jsonEncode({'status': status, 'isOffline': status == 'OFFLINE'});
    
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    
    // Retain so new subscribers (dashboard refresh) immediately see offline state
    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!, retain: true);
    print('MQTT: 📤 Published status $status to $topic');
  }

  /// Publishes location data for the Visual PoC (dashly/location topic).
  void publishPocLocation(double lat, double lng) {
    if (!_isConnected) {
      print('MQTT: ⚠️ Cannot publish — not connected.');
      return;
    }

    const String topic = 'dashly/location';
    final String payload = jsonEncode({'lat': lat, 'lng': lng});

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    _client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    print('MQTT: 📍 Published to $topic → $payload');
  }

  void publishSos(double lat, double lng) {
    if (!_isConnected || _currentEventId == null || _currentUserId == null) return;
    
    try {
      final topic = 'dashly/events/$_currentEventId/p/$_currentUserId/sos';
      final payload = jsonEncode({
        'lat': lat,
        'lng': lng,
        'timestamp': DateTime.now().toIso8601String(),
      });
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      print('MQTT: 🚨 Published SOS to $topic');
    } catch (e) {
      print('MQTT: Failed to publish SOS: $e');
    }
  }

  /// Official method to publish tracking data to the backend.
  /// Used by LocationService for real-time and buffered sync.
  Future<void> publishLocation({
    required int eventId,
    required int userId,
    required double lat,
    required double lng,
    required double speed,
    required double altitude,
    required String status,
    required bool isAnomaly,
    required String msgId,
    required DateTime timestamp,
    bool isOffline = false,
  }) async {
    if (!_isConnected) {
      print('MQTT: ⚠️ [DEBUG] Cannot publish location — not connected.');
      return;
    }

    final String topic = 'dashly/events/$eventId/p/$userId/loc';
    
    int? batteryLevel;
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (e) {
      print('MQTT: Failed to get battery level: $e');
    }

    final Map<String, dynamic> data = {
      'msg_id': msgId,
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'altitude': altitude,
      'status': status,
      'isAnomaly': isAnomaly,
      'captured_at': timestamp.toIso8601String(),
      'isOffline': isOffline,
      if (batteryLevel != null) 'battery': batteryLevel,
    };

    final String payload = jsonEncode(data);
    print('MQTT: 📤 [DEBUG] Preparing to publish...');
    print('MQTT: 📍 [DEBUG] Topic: $topic');
    print('MQTT: 📝 [DEBUG] Payload: $payload');

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    print('MQTT: ✅ [DEBUG] publishMessage executed successfully.');

    if (isOffline) {
      print('MQTT: 📦 [Sync] Published buffered point to $topic');
    } else {
      print('MQTT: 📍 [Live] Published to $topic → $payload');
    }
  }
}
