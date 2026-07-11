import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dashly_mobile/providers/tracking_provider.dart';
import 'package:dashly_mobile/services/mqtt_service.dart';
import 'package:dashly_mobile/services/location_service.dart';
import 'package:dashly_mobile/models/event_model.dart';
import 'package:dashly_mobile/core/utils/geo_utils.dart';

class MockMqttService extends Mock implements MqttService {}
class MockLocationService extends Mock implements LocationService {}

void main() {
  late MockMqttService mockMqttService;
  late MockLocationService mockLocationService;
  late TrackingProvider trackingProvider;

  setUp(() {
    mockMqttService = MockMqttService();
    mockLocationService = MockLocationService();

    // Setup default mock behaviors
    when(() => mockMqttService.isConnected).thenReturn(false);

    trackingProvider = TrackingProvider(
      mqttService: mockMqttService,
      locationService: mockLocationService,
    );
  });

  group('TrackingProvider Tests', () {
    test('initial state is correct', () {
      expect(trackingProvider.isTracking, isFalse);
      expect(trackingProvider.isSosTriggered, isFalse);
      expect(trackingProvider.currentSpeed, 0.0);
      expect(trackingProvider.totalDistance, 0.0);
      expect(trackingProvider.currentPosition, isNull);
    });

    test('startTracking initializes services correctly', () async {
      // Arrange
      when(() => mockMqttService.connect(1, 2)).thenAnswer((_) async => true);
      when(() => mockMqttService.setTrackingActive(true)).thenReturn(null);
      when(() => mockMqttService.publishStatus('ONLINE')).thenReturn(null);
      
      when(() => mockLocationService.startTracking(
            eventId: 1,
            userId: 2,
            category: EventCategory.running,
            onPositionUpdate: any(named: 'onPositionUpdate'),
          )).thenAnswer((_) async {});

      // Act
      await trackingProvider.startTracking(1, 2, category: EventCategory.running);

      // Assert
      expect(trackingProvider.isTracking, isTrue);
      expect(trackingProvider.category, EventCategory.running);
      verify(() => mockMqttService.connect(1, 2)).called(1);
      verify(() => mockMqttService.publishStatus('ONLINE')).called(1);
      verify(() => mockLocationService.startTracking(
            eventId: 1,
            userId: 2,
            category: EventCategory.running,
            onPositionUpdate: any(named: 'onPositionUpdate'),
          )).called(1);
    });

    test('stopTracking cleans up services correctly', () async {
      // Arrange
      when(() => mockMqttService.setTrackingActive(false)).thenReturn(null);
      when(() => mockLocationService.stopTracking()).thenAnswer((_) async {});
      when(() => mockMqttService.publishStatus('OFFLINE')).thenReturn(null);
      when(() => mockMqttService.disconnect()).thenReturn(null);

      // Act
      await trackingProvider.stopTracking();

      // Assert
      expect(trackingProvider.isTracking, isFalse);
      expect(trackingProvider.isSosTriggered, isFalse);
      verify(() => mockLocationService.stopTracking()).called(1);
      verify(() => mockMqttService.publishStatus('OFFLINE')).called(1);
      verify(() => mockMqttService.disconnect()).called(1);
    });

    test('triggerSos publishes SOS if tracking is active and position is set', () async {
      // Arrange
      // First, simulate starting tracking and receiving a position
      when(() => mockMqttService.connect(1, 2)).thenAnswer((_) async => true);
      when(() => mockMqttService.setTrackingActive(true)).thenReturn(null);
      when(() => mockMqttService.publishStatus('ONLINE')).thenReturn(null);
      
      Function? capturedCallback;
      when(() => mockLocationService.startTracking(
            eventId: 1,
            userId: 2,
            category: EventCategory.running,
            onPositionUpdate: any(named: 'onPositionUpdate'),
          )).thenAnswer((invocation) async {
        capturedCallback = invocation.namedArguments[#onPositionUpdate];
      });

      await trackingProvider.startTracking(1, 2, category: EventCategory.running);
      
      // Simulate position update
      final position = Position(
        latitude: -6.200000,
        longitude: 106.816666,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 5.0,
        speedAccuracy: 1.0,
      );
      capturedCallback!(position);

      when(() => mockMqttService.publishSos(-6.200000, 106.816666)).thenReturn(null);

      // Act
      await trackingProvider.triggerSos();

      // Assert
      expect(trackingProvider.isSosTriggered, isTrue);
      verify(() => mockMqttService.publishSos(-6.200000, 106.816666)).called(1);
    });
  });
}
