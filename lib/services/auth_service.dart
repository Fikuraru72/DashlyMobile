import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/app_constants.dart';
import '../core/network/global_error_interceptor.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';

/// ════════════════════════════════════════════════════════════════
/// Phase 8 — AuthService (Real API + RBAC)
/// ════════════════════════════════════════════════════════════════
/// Connects to the NestJS backend.
/// SUPER_ADMIN and STAFF users are BLOCKED on mobile — only PARTICIPANT is allowed.
/// ════════════════════════════════════════════════════════════════
class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'auth_user';

  final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isGoogleInitialized = false;

  AuthService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(GlobalErrorInterceptor());
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final refreshToken = await getRefreshToken();
            if (refreshToken != null) {
              try {
                final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
                final refreshResponse = await refreshDio.post('/auth/refresh', data: {'refreshToken': refreshToken});
                
                final newAccess = refreshResponse.data['accessToken'];
                final newRefresh = refreshResponse.data['refreshToken'];
                
                await saveTokens(newAccess, newRefresh ?? refreshToken);

                // Retry original request
                e.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
                final retryResponse = await refreshDio.fetch(e.requestOptions);
                return handler.resolve(retryResponse);
              } catch (refreshError) {
                await clearToken();
                return handler.next(e);
              }
            } else {
              await clearToken();
            }
          }
          return handler.next(e);
        },
      ),
    );
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => debugPrint(o.toString()),
      ),
    );
  }

  // ─── Google Sign-In Initialization (v7+) ───────────────────────────

  Future<void> _ensureGoogleInitialized() async {
    if (_isGoogleInitialized) return;
    
    debugPrint('AuthService: Initializing GoogleSignIn with serverClientId...');
    try {
      // NOTE: In v7+, scopes are not passed to initialize(). 
      // They are requested during the authentication process if needed, 
      // or set globally if using the old constructor (which we aren't).
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConstants.googleWebClientId,
      );
      _isGoogleInitialized = true;
      debugPrint('AuthService: GoogleSignIn initialized successfully.');
    } catch (e) {
      debugPrint('AuthService: Failed to initialize GoogleSignIn: $e');
      rethrow;
    }
  }

  // ─── Token Management ───────────────────────────────────────────────

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(key: _tokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    
    // Also save to SharedPreferences as a fallback for EventService and MqttService
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<String?> getToken() async { 
    return await _secureStorage.read(key: _tokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    
    try {
      // Sign out from Google to allow selecting a different account next time
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ─── Google Sign-In (v7 flow) ───────────────────────────────────────

  /// Completely rewritten Google Sign-In logic with robust error handling.
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();

      debugPrint('AuthService: Starting Google authenticate()...');
      // authenticate() triggers the system-level account picker
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();

      if (googleUser == null) {
        debugPrint('AuthService: Google Sign-In cancelled by user.');
        return null;
      }

      debugPrint('AuthService: Google authenticate success: ${googleUser.email}');
      
      // Get auth details (idToken)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Failed to get Google ID Token. Ensure you used the "Web Application" Client ID in AppConstants.');
      }

      // Call our Backend
      debugPrint('AuthService: Sending ID Token to backend (/auth/google)...');
      final response = await _dio.post(
        '/auth/google',
        data: {
          'token': idToken,
          'email': googleUser.email,
          'name': googleUser.displayName ?? 'Runner',
          'googleId': googleUser.id,
          'avatar': googleUser.photoUrl,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;

      _enforceParticipantRole(user);

      await saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
      await saveUser(user);

      return data;
    } on PlatformException catch (e) {
      debugPrint('════════════════════════════════════════════════════════');
      debugPrint('CRITICAL GOOGLE SIGN-IN ERROR (PlatformException)');
      debugPrint('Code: ${e.code}');
      debugPrint('Message: ${e.message}');
      debugPrint('Details: ${e.details}');
      debugPrint('Stacktrace: ${e.stacktrace}');
      debugPrint('Tip: Code 12501 usually means SHA-1 mismatch or cancelled.');
      debugPrint('Tip: Code 10 or 7 usually means Client ID configuration error.');
      debugPrint('════════════════════════════════════════════════════════');
      rethrow;
    } catch (e) {
      debugPrint('AuthService: Unexpected error during Google Sign-In: $e');
      rethrow;
    }
  }

  // ─── RBAC Role Validation ───────────────────────────────────────────

  void _enforceParticipantRole(Map<String, dynamic> userData) {
    final role = userData['role'] as String?;
    if (role == 'SUPER_ADMIN' || role == 'STAFF') {
      throw Exception(
        'ACCESS DENIED: Administrators and Staff must use the Web Dashboard. '
        'This app is exclusively for participants.',
      );
    }
  }

  // ─── Auth Endpoints (Real API) ──────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );

    final data = response.data as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;

    _enforceParticipantRole(user);

    await saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
    await saveUser(user);

    return data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = response.data as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;

    _enforceParticipantRole(user);

    await saveTokens(data['accessToken'] as String, data['refreshToken'] as String);
    await saveUser(user);

    return data;
  }

  Future<Map<String, dynamic>> redeemToken(String code) async {
    final response = await _dio.post(
      '/tokens/redeem',
      data: {'code': code},
    );

    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeProfile({
    required String phone,
    required Map<String, dynamic> healthInfo,
  }) async {
    final response = await _dio.patch(
      '/users/me',
      data: {'phone': phone, 'healthInfo': healthInfo},
    );

    return response.data as Map<String, dynamic>;
  }
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
    String? password,
    String? avatar,
    Map<String, dynamic>? healthInfo,
  }) async {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (password != null && password.isNotEmpty) data['password'] = password;
    if (avatar != null) data['avatar'] = avatar;
    if (healthInfo != null) data['healthInfo'] = healthInfo;

    final response = await _dio.patch(
      '/users/me',
      data: data,
    );
    
    // Also update saved local user
    final currentUser = await getSavedUser();
    if (currentUser != null && response.data != null) {
      final updatedUser = Map<String, dynamic>.from(currentUser);
      updatedUser.addAll(response.data as Map<String, dynamic>);
      await saveUser(updatedUser);
    }

    return response.data as Map<String, dynamic>;
  }
}