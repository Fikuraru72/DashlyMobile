import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/dashly_theme.dart';

/// ════════════════════════════════════════════════════════════════
/// GpsStatusBanner — Real-Time Device GPS Alert Card & Pop-Up ⚠️
/// ════════════════════════════════════════════════════════════════
/// Monitors device Location Service status. If GPS is disabled,
/// provides both a Pop-Up Dialog and a Banner Card with an "AKTIFKAN GPS"
/// button that directly opens Android/iOS Location Settings.
/// ════════════════════════════════════════════════════════════════
class GpsStatusBanner extends StatefulWidget {
  const GpsStatusBanner({super.key});

  /// Static helper to check and show GPS Pop-Up Dialog if Location Service is disabled
  static Future<void> checkAndShowPopup(BuildContext context) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: context.dashlyColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Colors.amber, width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.location_off_rounded, color: Colors.amber, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "GPS NONAKTIF",
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              "Layanan lokasi GPS pada HP Anda saat ini nonaktif. Silakan aktifkan GPS untuk dapat melacak rute gowes dan berpartisipasi dalam event balap sepeda secara real-time.",
              style: TextStyle(
                color: context.dashlyColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  "NANTI",
                  style: TextStyle(
                    color: context.dashlyColors.textHint,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await Geolocator.openLocationSettings();
                },
                icon: const Icon(Icons.settings_suggest_rounded, color: Colors.black, size: 18),
                label: const Text(
                  "AKTIFKAN GPS",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print("Error checking GPS for popup: $e");
    }
  }

  @override
  State<GpsStatusBanner> createState() => _GpsStatusBannerState();
}

class _GpsStatusBannerState extends State<GpsStatusBanner> {
  bool _isGpsEnabled = true;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  @override
  void initState() {
    super.initState();
    _checkGpsStatus();
    _listenGpsStatus();
  }

  Future<void> _checkGpsStatus() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (mounted) {
        setState(() => _isGpsEnabled = enabled);
      }
    } catch (e) {
      print("Error checking GPS status: $e");
    }
  }

  void _listenGpsStatus() {
    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((status) {
      if (mounted) {
        setState(() {
          _isGpsEnabled = (status == ServiceStatus.enabled);
        });
      }
    });
  }

  @override
  void dispose() {
    _serviceStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openGpsSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      print("Error opening location settings: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isGpsEnabled) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1B00), // Dark Amber backdrop
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_off_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "GPS LOCATION IS DISABLED",
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Please turn on device location services to enable real-time cycling tracking and join live events.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _openGpsSettings,
              icon: const Icon(Icons.settings_suggest_rounded, size: 16, color: Colors.black),
              label: const Text(
                "AKTIFKAN GPS",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
