import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/event_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/global_error_interceptor.dart';

/// ════════════════════════════════════════════════════════════════
/// EventService — Handles event API interactions
/// ════════════════════════════════════════════════════════════════
class EventService {
  final Dio _dio;

  EventService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(GlobalErrorInterceptor());
  }

  Future<String?> _getToken() async {
    const secureStorage = FlutterSecureStorage();
    String? token = await secureStorage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');
    }
    return token;
  }

  /// Joins an event directly via POST /events/:eventId/join
  /// Returns event details for the interlock screen.
  Future<Map<String, dynamic>> joinEvent(int eventId) async {
    final token = await _getToken();
    try {
      final response = await _dio.post(
        '/events/$eventId/join',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

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
    final token = await _getToken();
    try {
      final response = await _dio.post(
        '/events/$eventId/verify-bib',
        data: {'bibNumber': bibNumber},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data as Map<String, dynamic>;
      return {
        'success': true,
        'message': responseData['message'] ?? 'BIB verified successfully',
      };
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Failed to verify BIB';
      print('EventService: Failed to verify BIB for event $eventId: $message');
      return {'success': false, 'message': message};
    }
  }

  /// Joins an event via a 6-character token via POST /events/join-via-token
  Future<Map<String, dynamic>> joinEventViaToken(String tokenCode) async {
    final token = await _getToken();
    try {
      final response = await _dio.post(
        '/events/join-via-token',
        data: {'token': tokenCode},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
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
    final token = await _getToken();
    try {
      final response = await _dio.get(
        '/events/$eventId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

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
    final token = await _getToken();
    try {
      final response = await _dio.get(
        '/events/$eventId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

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
    final token = await _getToken();
    try {
      final response = await _dio.get(
        '/events/my-events',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

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
    final token = await _getToken();
    try {
      final response = await _dio.get(
        '/events/explore',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

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
    final token = await _getToken();
    try {
      final response = await _dio.get(
        '/users/me/stats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      // Since nestjs returns the object directly, not wrapped in success/data (based on controller)
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      print('EventService: Failed to fetch user stats: ${e.message}');
      return null;
    }
  }

  /// Fetches the participant's ticket (contains bibNumber, etc.)
  Future<Map<String, dynamic>?> getParticipantTicket(int eventId) async {
    final token = await _getToken();
    try {
      final response = await _dio.get(
        '/public-events/$eventId/ticket',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

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
    final token = await _getToken();
    try {
      final response = await _dio.get(
        '/events/$eventId/participants/me/live-stats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

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
