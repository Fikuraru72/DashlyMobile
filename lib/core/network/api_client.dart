import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'global_error_interceptor.dart';

/// ════════════════════════════════════════════════════════════════
/// ApiClient — Centralized Dio client with auto token refresh
/// ════════════════════════════════════════════════════════════════
class ApiClient {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'auth_user';

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  final Dio dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isRefreshing = false;

  ApiClient._internal()
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            if (_isRefreshing) {
              return handler.next(e);
            }
            _isRefreshing = true;
            final refreshToken = await getRefreshToken();
            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                debugPrint('ApiClient: Access token expired. Refreshing token...');
                final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
                final refreshResponse = await refreshDio.post(
                  '/auth/refresh',
                  data: {'refreshToken': refreshToken},
                );

                final newAccess = refreshResponse.data['accessToken'] as String?;
                final newRefresh = refreshResponse.data['refreshToken'] as String?;

                if (newAccess != null) {
                  await saveTokens(newAccess, newRefresh ?? refreshToken);
                  _isRefreshing = false;

                  // Retry original request with new token
                  e.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
                  final retryResponse = await refreshDio.fetch(e.requestOptions);
                  return handler.resolve(retryResponse);
                }
              } catch (refreshError) {
                debugPrint('ApiClient: Refresh token failed or expired: $refreshError');
                await clearToken();
              } finally {
                _isRefreshing = false;
              }
            } else {
              await clearToken();
              _isRefreshing = false;
            }
          }
          return handler.next(e);
        },
      ),
    );
    dio.interceptors.add(GlobalErrorInterceptor());
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(key: _tokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<String?> getToken() async {
    String? token = await _secureStorage.read(key: _tokenKey);
    if (token == null || token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_tokenKey);
    }
    return token;
  }

  Future<String?> getRefreshToken() async {
    String? token = await _secureStorage.read(key: _refreshTokenKey);
    if (token == null || token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_refreshTokenKey);
    }
    return token;
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}
