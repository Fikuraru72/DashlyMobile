import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/event_provider.dart';
import '../../theme/dashly_theme.dart';
import '../../widgets/altitude_chart_widget.dart';

/// ════════════════════════════════════════════════════════════════
/// Stats-Only Tracking Screen (Battery Saver Mode - No Map)
/// ════════════════════════════════════════════════════════════════
/// Dedicated standalone screen for tracking without MapLibre GL rendering.
/// Minimizes CPU/GPU consumption for maximum battery longevity on marathons.
/// ════════════════════════════════════════════════════════════════
class StatsTrackingScreen extends StatefulWidget {
  final int eventId;
  final String eventName;

  const StatsTrackingScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<StatsTrackingScreen> createState() => _StatsTrackingScreenState();
}

class _StatsTrackingScreenState extends State<StatsTrackingScreen> {
  late Stopwatch _stopwatch;
  late Timer _timer;
  bool _isSosLongPressing = false;
  double _sosProgress = 0.0;
  Timer? _sosTimer;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().fetchEvent(widget.eventId);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    _sosTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: context.dashlyColors.surface,
            title: const Text("STOP TRACKING?"),
            content: const Text(
              "Your race progress will be paused and telemetry will stop sending.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("CANCEL"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.dashlyColors.error,
                ),
                child: const Text("STOP NOW"),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _startSosHold(TrackingProvider tracker) {
    setState(() {
      _isSosLongPressing = true;
      _sosProgress = 0.0;
    });
    _sosTimer?.cancel();
    _sosTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      setState(() {
        _sosProgress += 0.1;
      });
      if (_sosProgress >= 1.0) {
        timer.cancel();
        setState(() {
          _isSosLongPressing = false;
          _sosProgress = 0.0;
        });
        await _triggerSosDirect(tracker);
      }
    });
  }

  void _cancelSosHold() {
    _sosTimer?.cancel();
    setState(() {
      _isSosLongPressing = false;
      _sosProgress = 0.0;
    });
  }

  Future<void> _triggerSosDirect(TrackingProvider tracker) async {
    final success = await tracker.triggerSos();
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🚨 SOS TRIGGERED! Race Control Notified."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to trigger SOS. No GPS fix or not tracking."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackingProvider>();
    final eventProvider = context.watch<EventProvider>();
    final currentEvent = eventProvider.currentEvent;

    final double speed = tracker.currentSpeed;
    final double avgSpeed = tracker.avgSpeed;
    final double distanceKm = tracker.totalDistance;
    final String bibText = (currentEvent != null && currentEvent.bibNumber != null)
        ? " • BIB #${currentEvent.bibNumber}"
        : "";

    final altitudeProfile = currentEvent?.altitudeProfile ?? [];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await _showExitConfirmation();
        if (confirm && context.mounted) {
          Navigator.pop(context, result);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF070B14),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                // Top Header Pill
                _buildTopHeader(tracker, currentEvent, bibText),
                const SizedBox(height: 16),

                // Battery Saver Mode Badge
                _buildBatterySaverBadge(),
                const SizedBox(height: 20),

                // Main Stats Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Giant Speedometer Display
                        _buildHeroSpeedCard(speed, distanceKm),
                        const SizedBox(height: 16),

                        // Time & Pace Row
                        _buildTimerPaceRow(avgSpeed),
                        const SizedBox(height: 16),

                        // Secondary Stats Grid
                        _buildSecondaryStatsGrid(tracker),
                        const SizedBox(height: 20),

                        // Altitude Chart Section if available
                        if (altitudeProfile.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "ALTITUDE PROFILE",
                              style: TextStyle(
                                color: context.dashlyColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 140,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.dashlyColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.dashlyColors.divider),
                            ),
                            child: AltitudeChartWidget(
                              altitudeProfile: altitudeProfile,
                              currentDistanceMeters: distanceKm * 1000,
                              otherRunners: tracker.otherRunners,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),

                // Bottom Action Buttons (SOS & Stop Tracking)
                _buildBottomControls(tracker),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(TrackingProvider tracker, dynamic currentEvent, String bibText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.dashlyColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "${widget.eventName.toUpperCase()}$bibText",
              style: TextStyle(
                color: context.dashlyColors.accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _buildConnectionBadge(tracker.isMqttConnected),
        ],
      ),
    );
  }

  Widget _buildConnectionBadge(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withValues(alpha: 0.15)
            : context.dashlyColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? Colors.green : context.dashlyColors.error,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : context.dashlyColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? "ONLINE" : "BUFFERING",
            style: TextStyle(
              color: isConnected ? Colors.green : context.dashlyColors.error,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatterySaverBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Text(
            "BATTERY SAVER (NO MAP) ACTIVE",
            style: TextStyle(
              color: Colors.amber[300],
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSpeedCard(double speed, double distanceKm) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.dashlyColors.surface,
            context.dashlyColors.surfaceLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.dashlyColors.accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: context.dashlyColors.accent.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            "CURRENT SPEED",
            style: TextStyle(
              color: context.dashlyColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                speed.toStringAsFixed(1),
                style: TextStyle(
                  color: context.dashlyColors.accent,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "KM/H",
                style: TextStyle(
                  color: context.dashlyColors.textSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.straighten_rounded, color: context.dashlyColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                "DISTANCE: ",
                style: TextStyle(color: context.dashlyColors.textSecondary, fontSize: 13),
              ),
              Text(
                "${distanceKm.toStringAsFixed(2)} km",
                style: TextStyle(
                  color: context.dashlyColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerPaceRow(double avgSpeed) {
    final String durationStr = _formatDuration(_stopwatch.elapsed);
    final String paceStr = avgSpeed > 0
        ? "${(60 / avgSpeed).floor()}:${((60 / avgSpeed % 1) * 60).round().toString().padLeft(2, '0')} /km"
        : "--:-- /km";

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            icon: Icons.timer_outlined,
            label: "ELAPSED TIME",
            value: durationStr,
            valueColor: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            icon: Icons.speed_rounded,
            label: "AVG PACE",
            value: paceStr,
            valueColor: context.dashlyColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryStatsGrid(TrackingProvider tracker) {
    final double avgSpeed = tracker.avgSpeed;
    final double elevationGain = tracker.elevationGain;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.dashlyColors.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSubStat("Average Speed", "${avgSpeed.toStringAsFixed(1)} km/h"),
              _buildSubStat("Elevation Gain", "${elevationGain.round()} m"),
            ],
          ),
          const Divider(height: 20, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSubStat("Tracking Mode", "Battery Saver"),
              _buildSubStat("GPS Telemetry", "ACTIVE"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.dashlyColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: context.dashlyColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.dashlyColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.dashlyColors.textHint),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: context.dashlyColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(TrackingProvider tracker) {
    return Row(
      children: [
        // SOS Button
        GestureDetector(
          onTapDown: (_) => _startSosHold(tracker),
          onTapUp: (_) => _cancelSosHold(),
          onTapCancel: () => _cancelSosHold(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 70,
            height: 56,
            decoration: BoxDecoration(
              color: _isSosLongPressing
                  ? Colors.red.withValues(alpha: 0.9)
                  : context.dashlyColors.error.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.dashlyColors.error,
                width: _isSosLongPressing ? 2.5 : 1.5,
              ),
            ),
            child: Center(
              child: _isSosLongPressing
                  ? CircularProgressIndicator(
                      value: _sosProgress,
                      color: Colors.white,
                      strokeWidth: 3,
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: context.dashlyColors.error, size: 20),
                        const Text("SOS", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Stop Tracking Button
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                final confirm = await _showExitConfirmation();
                if (confirm && mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.dashlyColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                "STOP TRACKING",
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
