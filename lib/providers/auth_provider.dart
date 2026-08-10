import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// ════════════════════════════════════════════════════════════════
/// Phase 8 — AuthProvider (RBAC-aware)
/// ════════════════════════════════════════════════════════════════
/// Manages authentication state. Catches ADMIN access denial
/// and surfaces it as a user-visible error.
/// ════════════════════════════════════════════════════════════════
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService}) 
      : _authService = authService ?? AuthService();

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? password,
    String? avatar,
    HealthInfo? healthInfo,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final updatedData = await _authService.updateProfile(
        name: name,
        phone: phone,
        password: password,
        avatar: avatar,
        healthInfo: healthInfo?.toJson(),
      );
      if (_currentUser != null) {
        _currentUser = User.fromJson({ ..._currentUser!.toJson(), ...updatedData });
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e);
      _setLoading(false);
      return false;
    }
  }

  // ─── Token Lifecycle ───────────────────────────────────────────────────────

  // ─── Getters ───────────────────────────────────────────────────────

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;

  // ─── Helpers ───────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Auth Actions ──────────────────────────────────────────────────

  /// Attempts login with email + password.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final data = await _authService.login(
        email: email,
        password: password,
      );
      _currentUser = User.fromJson(data['user'] as Map<String, dynamic>);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e);
      _setLoading(false);
      return false;
    }
  }

  /// Registers a new account.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final data = await _authService.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      _currentUser = User.fromJson(data['user'] as Map<String, dynamic>);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> completeProfile({
    String? phone,
    required HealthInfo healthInfo,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final updatedData = await _authService.completeProfile(
        phone: phone,
        healthInfo: healthInfo.toJson(),
      );

      if (_currentUser != null) {
        _currentUser = User.fromJson({ ..._currentUser!.toJson(), ...updatedData });
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e);
      _setLoading(false);
      return false;
    }
  }

  /// Google Sign-In flow using the updated AuthService.
  Future<bool> googleLogin() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final data = await _authService.signInWithGoogle();
      if (data == null) {
        _setLoading(false);
        return false; // User cancelled
      }
      _currentUser = User.fromJson(data['user'] as Map<String, dynamic>);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e);
      _setLoading(false);
      return false;
    }
  }

  /// Redeems a token to join an event.
  Future<Map<String, dynamic>?> redeemToken(String code) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final result = await _authService.redeemToken(code);
      _setLoading(false);
      return result;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e);
      _setLoading(false);
      return null;
    }
  }

  /// Clears user session and token.
  Future<void> logout() async {
    _setLoading(true);
    await _authService.clearToken();
    _currentUser = null;
    _errorMessage = null;
    _setLoading(false);
  }

  /// Tries to restore session from saved token/user.
  Future<bool> tryAutoLogin() async {
    final token = await _authService.getToken();
    if (token == null) return false;

    final savedUser = await _authService.getSavedUser();
    if (savedUser == null) return false;

    _currentUser = User.fromJson(savedUser);
    notifyListeners();
    return true;
  }

  /// Extracts a clean error message from exceptions.
  String _extractErrorMessage(Object e) {
    final msg = e.toString();
    // DioException wraps the message
    if (msg.contains('ACCESS DENIED')) {
      return msg.replaceAll('Exception: ', '');
    }
    
    // Check if it's a DioException by string because we might not import dio here
    // or we can import dio and do a type check. For now, let's parse the string 
    // or try to cast if we can. Actually, let's just use string manipulation 
    // or better, if the error contains response data.
    if (e.runtimeType.toString().contains('DioException')) {
      try {
        final dioError = e as dynamic;
        if (dioError.response != null && dioError.response?.data != null) {
          final data = dioError.response?.data;
          if (data is Map && data['message'] != null) {
            final backendMsg = data['message'];
            if (backendMsg is List) return backendMsg.join(', ');
            return backendMsg.toString();
          }
        }
      } catch (_) {}
      
      if (msg.contains('ECONNREFUSED') || msg.contains('connection refused') || msg.contains('SocketException')) {
        return 'Cannot reach the server. Please check your network connection.';
      }
      return 'Network error or Invalid credentials.';
    }
    return msg.replaceAll('Exception: ', '');
  }
}
