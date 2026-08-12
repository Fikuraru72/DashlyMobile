import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/dashly_theme.dart';

/// ════════════════════════════════════════════════════════════════
/// PermissionOnboardingDialog — Startup Permission Flow 🛡️
/// ════════════════════════════════════════════════════════════════
/// Requests all required permissions on app startup:
/// - Location (Always & Foreground)
/// - Camera (QR Scanner)
/// - Storage / Photos (Gallery Save)
/// - Notifications (Event alerts)
/// ════════════════════════════════════════════════════════════════
class PermissionOnboardingDialog extends StatefulWidget {
  const PermissionOnboardingDialog({super.key});

  /// Static helper to check and show onboarding if permissions are missing.
  static Future<void> checkAndShow(BuildContext context) async {
    final locationWhenInUse = await Permission.locationWhenInUse.status;
    final camera = await Permission.camera.status;

    // Show onboarding if any critical permission is not granted yet
    if (!locationWhenInUse.isGranted || !camera.isGranted) {
      if (!context.mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.8),
        builder: (_) => const PermissionOnboardingDialog(),
      );
    }
  }

  @override
  State<PermissionOnboardingDialog> createState() => _PermissionOnboardingDialogState();
}

class _PermissionOnboardingDialogState extends State<PermissionOnboardingDialog> {
  bool _isProcessing = false;

  Future<void> _requestAllPermissions() async {
    setState(() => _isProcessing = true);

    try {
      // 1. Location (When In Use / When Open App)
      await Permission.locationWhenInUse.request();

      // 2. Camera (for QR Code scanner & photo capture)
      await Permission.camera.request();

      // 3. Storage / Photos (for saving cards to gallery)
      if (Platform.isAndroid) {
        await Permission.photos.request();
        await Permission.storage.request();
      }

      // 4. Notifications (for race alerts & countdowns)
      await Permission.notification.request();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: context.dashlyColors.accent),
                const SizedBox(width: 8),
                const Text("Permissions updated! Ready to ride 🚴‍♂️"),
              ],
            ),
            backgroundColor: context.dashlyColors.surface,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print("Error requesting permissions: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: context.dashlyColors.accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle Indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.dashlyColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.dashlyColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.shield_rounded, color: context.dashlyColors.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "APP PERMISSIONS",
                      style: TextStyle(
                        color: context.dashlyColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Required for Cycling Tracking",
                      style: TextStyle(
                        color: context.dashlyColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            "To deliver precise real-time GPS tracking and seamless race sharing, Dashly needs the following permissions:",
            style: TextStyle(
              color: context.dashlyColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Permission Items List
          _buildPermissionItem(
            context,
            icon: Icons.location_on_rounded,
            title: "Location Access (When Using App)",
            subtitle: "Real-time GPS route tracking while using Dashly during cycling events.",
          ),
          const SizedBox(height: 12),
          _buildPermissionItem(
            context,
            icon: Icons.camera_alt_rounded,
            title: "Camera & Scanner",
            subtitle: "Scan event QR codes at checkpoints and capture race photos.",
          ),
          const SizedBox(height: 12),
          _buildPermissionItem(
            context,
            icon: Icons.photo_library_rounded,
            title: "Photos & Gallery Storage",
            subtitle: "Save Strava-style activity share cards directly to your phone gallery.",
          ),
          const SizedBox(height: 12),
          _buildPermissionItem(
            context,
            icon: Icons.notifications_active_rounded,
            title: "Notifications",
            subtitle: "Receive race countdown alerts and live organizer updates.",
          ),
          const SizedBox(height: 24),

          // Primary Action Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _requestAllPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.dashlyColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "ALLOW PERMISSIONS",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.dashlyColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.dashlyColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.dashlyColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.dashlyColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.dashlyColors.textHint,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
