import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import '../core/network/global_error_interceptor.dart';

/// Response model for the /health/sync endpoint.
class SyncResponse {
  final String status;
  final bool dbConnected;
  final int userCount;
  final int eventCount;
  final String serverTime;

  const SyncResponse({
    required this.status,
    required this.dbConnected,
    required this.userCount,
    required this.eventCount,
    required this.serverTime,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) => SyncResponse(
        status: json['status'] as String,
        dbConnected: json['dbConnected'] as bool,
        userCount: json['userCount'] as int,
        eventCount: json['eventCount'] as int,
        serverTime: json['serverTime'] as String,
      );

  @override
  String toString() => const JsonEncoder.withIndent('  ').convert({
        'status': status,
        'dbConnected': dbConnected,
        'userCount': userCount,
        'eventCount': eventCount,
        'serverTime': serverTime,
      });
}

/// Service for communicating with the Dashly NestJS backend.
class DashlyApiService {
  /// Base URL configured in AppConstants.
  static const String _baseUrl = AppConstants.apiBaseUrl;

  final Dio _dio;

  DashlyApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(GlobalErrorInterceptor());
  }

  /// Pings GET /health/sync and returns a [SyncResponse].
  /// Throws a [DioException] or [Exception] on failure.
  Future<SyncResponse> checkSync() async {
    final response = await _dio.get<Map<String, dynamic>>('/health/sync');
    if (response.data == null) {
      throw Exception('Empty response from server');
    }
    return SyncResponse.fromJson(response.data!);
  }
}
