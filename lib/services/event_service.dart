import 'package:dio/dio.dart';
import '../models/event_model.dart';
import '../core/network/api_client.dart';

/// ════════════════════════════════════════════════════════════════
/// EventService — Handles event API interactions using ApiClient
/// ════════════════════════════════════════════════════════════════
class EventService {
  final Dio _dio;

  EventService() : _dio = ApiClient().dio;

  /// Joins an event directly via POST /events/:eventId/join
  /// Returns event details for the interlock screen.
  Future<Map<String, dynamic>> joinEvent(int eventId) async {
    try {
      final response = await _dio.post('/events/$eventId/join');

      final responseData = response.data as Map<String, dynamic>;
      // Handle standardized { success, data } format
      final data = responseData['success'] == true
          ? (responseData['data'] as Map<String, dynamic>?) ?? responseData
          : responseData;

      return {
        'success': true,
        'eventId': data['eventId'],
        'eventName': data['eventName'],
        'category': data['category'],
        'status': data['status'],
        'startTime': data['startTime'],
        'endTime': data['endTime'],
        'monitoringStartOffset': data['monitoringStartOffset'],
        'monitoringEndOffset': data['monitoringEndOffset'],
        'monitoringWindow': data['monitoringWindow'],
        'bibNumber': data['bibNumber'],
        'message': data['message'] ?? 'Token redeemed successfully!',
      };
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Failed to join event';
      return {'success': false, 'message': message};
    }
  }

  Future<Map<String, dynamic>> verifyBib(int eventId, String bibNumber) async {
    try {
      final response = await _dio.post(
        '/events/$eventId/verify-bib',
        data: {'bibNumber': bibNumber},
      );

      final responseData = response.data as Map<String, dynamic>;
      return {
        'success': true,
        'message': responseData['message'] ?? 'BIB verified successfully',
      };
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Failed to verify BIB';
      print('EventService: Failed to verify BIB for event $eventId: $message');
      
      // If backend returns 409 Conflict or "already verified", treat as success
      if (e.response?.statusCode == 409 ||
          message.toString().toLowerCase().contains('already verified')) {
        return {'success': true, 'message': 'BIB is already verified'};
      }

      return {'success': false, 'message': message};
    }
  }

  /// Marks participant as FINISHED immediately for an event
  Future<bool> finishParticipant(int eventId, {Map<String, dynamic>? stats}) async {
    try {
      final response = await _dio.post(
        '/events/$eventId/finish-participant',
        data: stats,
      );
      final responseData = response.data as Map<String, dynamic>;
      return responseData['success'] == true;
    } on DioException catch (e) {
      print('EventService: Failed to finish participant for event $eventId: ${e.message}');
      return false;
    }
  }

  /// Joins an event via a 6-character token via POST /events/join-via-token
  Future<Map<String, dynamic>> joinEventViaToken(String tokenCode) async {
    try {
      final response = await _dio.post(
        '/events/join-via-token',
        data: {'token': tokenCode},
      );

      final responseData = response.data as Map<String, dynamic>;
      final data = responseData['success'] == true
          ? (responseData['data'] as Map<String, dynamic>?) ?? responseData
          : responseData;

      return {
        'success': true,
        'eventId': data['eventId'],
        'eventName': data['eventName'],
        'category': data['category'],
        'status': data['status'],
        'startTime': data['startTime'],
        'endTime': data['endTime'],
        'monitoringStartOffset': data['monitoringStartOffset'],
        'monitoringEndOffset': data['monitoringEndOffset'],
        'monitoringWindow': data['monitoringWindow'],
        'bibNumber': data['bibNumber'],
        'message': data['message'] ?? 'Token redeemed successfully!',
      };
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] ?? 'Failed to join event via token';
      return {'success': false, 'message': message};
    }
  }

  /// Fetches full event details by ID.
  /// Used for the race interlock screen to check status + monitoring window.
  Future<Event?> fetchEventDetails(int eventId) async {
    try {
      final response = await _dio.get('/events/$eventId');

      final responseData = response.data as Map<String, dynamic>;
      // Handle standardized { success, data } format
      final data = responseData['success'] == true
          ? (responseData['data'] as Map<String, dynamic>?) ?? responseData
          : responseData;

      return Event.fromJson(data);
    } on DioException catch (e) {
      print('EventService: Failed to fetch event $eventId: ${e.message}');
      return null;
    }
  }

  /// Polls event status — lightweight call for interlock screen.
  /// Returns the current event status and monitoring window info.
  Future<Map<String, dynamic>?> pollEventStatus(int eventId) async {
    try {
      final response = await _dio.get('/events/$eventId');

      final responseData = response.data as Map<String, dynamic>;
      final data = responseData['success'] == true
          ? (responseData['data'] as Map<String, dynamic>?) ?? responseData
          : responseData;

      return {
        'status': data['status'],
        'monitoringWindow': data['monitoringWindow'],
        'category': data['category'],
      };
    } on DioException catch (e) {
      print('EventService: Poll failed for event $eventId: ${e.message}');
      return null;
    }
  }

  /// Fetches events the user has joined.
  Future<List<Event>?> getMyEvents() async {
    try {
      final response = await _dio.get('/events/my-events');

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        final List<dynamic> data = responseData['data'] ?? [];
        return data.map((json) => Event.fromJson(json)).toList();
      }
      return null;
    } on DioException catch (e) {
      print('EventService: Failed to fetch my events: ${e.message}');
      return null;
    }
  }

  /// Fetches explore events (all public events)
  Future<List<Event>?> getExploreEvents() async {
    try {
      final response = await _dio.get('/events/explore');

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        final List<dynamic> data = responseData['data'] ?? [];
        return data.map((json) => Event.fromJson(json)).toList();
      }
      return null;
    } on DioException catch (e) {
      print('EventService: Failed to fetch explore events: ${e.message}');
      return null;
    }
  }

  /// Fetches user stats
  Future<Map<String, dynamic>?> getUserStats() async {
    try {
      final response = await _dio.get('/users/me/stats');

      // Since nestjs returns the object directly, not wrapped in success/data (based on controller)
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      print('EventService: Failed to fetch user stats: ${e.message}');
      return null;
    }
  }

  /// Fetches the participant's ticket (contains bibNumber, etc.)
  Future<Map<String, dynamic>?> getParticipantTicket(int eventId) async {
    try {
      final response = await _dio.get('/public-events/$eventId/ticket');

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        return responseData['data'] as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      print('EventService: Failed to fetch participant ticket: ${e.message}');
      return null;
    }
  }

  /// Gets live tracking stats for the current participant
  Future<Map<String, dynamic>?> getLiveStats(int eventId) async {
    try {
      final response = await _dio.get('/events/$eventId/participants/me/live-stats');

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        return responseData['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('EventService: Failed to fetch live stats: $e');
      return null;
    }
  }
}
