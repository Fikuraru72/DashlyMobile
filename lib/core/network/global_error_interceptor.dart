import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../main.dart'; // To access rootScaffoldMessengerKey

class GlobalErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    String errorMessage = _mapErrorToMessage(err);

    // Show Snackbar globally
    if (errorMessage.isNotEmpty && rootScaffoldMessengerKey.currentState != null) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }

    // Continue so specific catch blocks can still handle it if they want
    super.onError(err, handler);
  }

  String _mapErrorToMessage(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout || 
        err.type == DioExceptionType.sendTimeout || 
        err.type == DioExceptionType.receiveTimeout) {
      return "Koneksi ke server terlalu lama. Periksa koneksi internet Anda.";
    }

    if (err.type == DioExceptionType.connectionError || err.error is Exception) {
      return "Koneksi internet Anda terputus. Data akan disinkronkan saat Anda kembali online.";
    }

    if (err.response != null) {
      final statusCode = err.response?.statusCode;
      final data = err.response?.data;
      String backendMessage = '';

      if (data is Map && data['message'] != null) {
        backendMessage = data['message'].toString();
      }

      // If backend gave us a message from GlobalExceptionFilter, use it directly!
      if (backendMessage.isNotEmpty) {
        return backendMessage;
      }

      // Fallback mapping if backend didn't format it properly
      if (statusCode == 500) {
        return "Terjadi kesalahan pada server. Silakan coba beberapa saat lagi.";
      }
      if (statusCode == 504) {
        return "Koneksi ke server terlalu lama. Periksa koneksi internet Anda.";
      }
      return "Terjadi kesalahan ($statusCode). Silakan coba lagi.";
    }

    return "Terjadi kesalahan yang tidak terduga.";
  }
}
