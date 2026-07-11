import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/event_provider.dart';
import '../../theme/dashly_theme.dart';
import 'live_map_widget.dart';

class TrackingScreen extends StatefulWidget {
  final int eventId;
  final String eventName;

  const TrackingScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late Stopwatch _stopwatch;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });

    // Don't start tracking automatically on screen entry anymore.
    // The user will press the START button to begin.
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
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
            title: Text("STOP TRACKING?"),
            content: Text(
              "Your race progress will be paused and telemetry will stop sending.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("CANCEL"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.dashlyColors.error,
                ),
                child: Text("STOP NOW"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _triggerSos(TrackingProvider tracker) async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.dashlyColors.surface,
        title: const Text("TRIGGER SOS?"),
        content: const Text(
          "This will immediately notify race control and freeze your tracking status. Only use in real emergencies.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("TRIGGER SOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await tracker.triggerSos();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("SOS Triggered! Race control has been notified."),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Failed to trigger SOS. No GPS fix or not tracking."),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackingProvider>();

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
        body: Column(
          children: [
            // 1. Status Header
            _buildHeader(tracker),

            // 2. Map Placeholder (Neon Grid)
            Expanded(
              child: LiveMapWidget(
                currentPosition: tracker.currentPosition,
                routeGeojson: context.read<EventProvider>().currentEvent?.routeGeojson,
              ),
            ),

            // 3. Stats Dashboard
            _buildStatsDashboard(tracker),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(TrackingProvider tracker) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.eventName.toUpperCase(),
                      style: TextStyle(
                        color: context.dashlyColors.accent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(_stopwatch.elapsed),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: context.dashlyColors.textPrimary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildConnectionBadge(tracker.isMqttConnected),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBadge(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withValues(alpha: 0.1)
            : context.dashlyColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? Colors.green : context.dashlyColors.error,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : context.dashlyColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? "ONLINE" : "OFFLINE / BUFFERING",
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

  Widget _buildStatsDashboard(TrackingProvider tracker) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  "SPEED",
                  tracker.currentSpeed.toStringAsFixed(1),
                  "KM/H",
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: context.dashlyColors.divider,
              ),
              Expanded(
                child: _buildStatItem(
                  "DISTANCE",
                  tracker.totalDistance.toStringAsFixed(2),
                  "KM",
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: context.dashlyColors.divider,
              ),
              Expanded(
                child: _buildStatItem(
                  "RANK",
                  tracker.currentRank > 0 ? tracker.currentRank.toString() : "-",
                  "POSITION",
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar and Checkpoints
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "PROGRESS",
                style: TextStyle(
                  color: context.dashlyColors.textHint,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                "${tracker.progressPercentage.toStringAsFixed(1)}%",
                style: TextStyle(
                  color: context.dashlyColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: tracker.progressPercentage / 100,
              backgroundColor: context.dashlyColors.surfaceLight,
              color: context.dashlyColors.accent,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 14, color: context.dashlyColors.accent),
              const SizedBox(width: 6),
              Text(
                "CHECKPOINTS COMPLETED: ${tracker.checkpointsCompleted} / 3",
                style: TextStyle(
                  color: context.dashlyColors.textHint,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, size: 14, color: context.dashlyColors.accent),
              const SizedBox(width: 6),
              Text(
                tracker.currentPosition != null 
                  ? "${tracker.currentPosition!.latitude.toStringAsFixed(5)}, ${tracker.currentPosition!.longitude.toStringAsFixed(5)}" 
                  : "WAITING FOR GPS FIX...",
                style: TextStyle(
                  color: context.dashlyColors.textHint,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (tracker.isTracking) ...[
            if (tracker.isSosTriggered)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: context.dashlyColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.red, size: 28),
                    SizedBox(width: 8),
                    Text(
                      "SOS TRIGGERED",
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ],
                ),
              )
            else if (tracker.currentPosition == null)
              SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.5), width: 1),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)
                      ),
                      SizedBox(width: 12),
                      Text(
                        "ACQUIRING GPS LOCK...",
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _triggerSos(tracker),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        "SOS EMERGENCY",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
          if (!tracker.isTracking)
            ElevatedButton(
              onPressed: () async {
                print('UI: 🖱️ [DEBUG] START RACE NOW button pressed.');
                final userId =
                    context.read<AuthProvider>().currentUser?.id ?? 0;
                try {
                  await tracker.startTracking(widget.eventId, userId);
                  _stopwatch.start();
                } catch (e) {
                  print('UI: ❌ [DEBUG] Failed to start tracking: $e');
                  if (mounted) {
                    final errorStr = e.toString().toLowerCase();
                    String message = "FAILURE: $e";
                    
                    if (errorStr.contains('location services disabled') || 
                        errorStr.contains('location permissions')) {
                      message = "⚠️ Mohon aktifkan GPS / Lokasi Anda untuk memulai tracking.";
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message, style: TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: context.dashlyColors.error,
                        duration: const Duration(seconds: 4),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.dashlyColors.accent,
              ),
              child: Text(
                "START RACE NOW",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: () async {
                if (await _showExitConfirmation()) {
                  tracker.stopTracking();
                  _stopwatch.stop();
                  if (mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.dashlyColors.error,
              ),
              child: Text(
                "STOP TRACKING",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.dashlyColors.textHint,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: context.dashlyColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                fontSize: 10,
                color: context.dashlyColors.textHint,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
