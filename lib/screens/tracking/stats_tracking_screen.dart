import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/event_provider.dart';
import '../../theme/dashly_theme.dart';
import '../../widgets/altitude_chart_widget.dart';
import 'race_summary_screen.dart';
import '../../services/offline_storage_service.dart';
import '../../core/utils/geo_utils.dart';
import '../../models/event_model.dart';

/// ════════════════════════════════════════════════════════════════
/// StatsTrackingScreen — Standalone Battery Saver Mode (No Map)
/// ════════════════════════════════════════════════════════════════
/// Has 100% core logic & telemetry parity with TrackingScreen (with Map),
/// including automatic MQTT tracking, 6-metrics telemetry, altitude charts,
/// SOS hold trigger, and rank calculation, but optimized for zero MapLibre GPU load.
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
  bool _hasAutoFinished = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<EventProvider>().fetchEvent(widget.eventId);
      
      // Auto start tracking telemetry if not already running
      final tracker = context.read<TrackingProvider>();
      if (!tracker.isTracking) {
        final userId = context.read<AuthProvider>().currentUser?.id ?? 0;
        try {
          await tracker.startTracking(widget.eventId, userId);
          _stopwatch.start();
        } catch (e) {
          debugPrint('StatsTrackingScreen: Failed to auto start tracking: $e');
        }
      } else {
        _stopwatch.start();
      }
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

  // ignore: unused_element
  List<dynamic> _getEffectiveAltitudeProfile(EventProvider eventProvider) {
    dynamic event = eventProvider.currentEvent;

    // Instant Fallback: If currentEvent is null or lacks route data, use cached myEvents in eventProvider
    if (event == null || (event.altitudeProfile == null && event.routeGeojson == null)) {
      try {
        event = eventProvider.myEvents.firstWhere((e) => e.id == widget.eventId);
      } catch (_) {}
    }

    if (event?.altitudeProfile != null && (event.altitudeProfile as List).isNotEmpty) {
      return event.altitudeProfile!;
    }
    if (event?.routeGeojson != null) {
      try {
        final features = event.routeGeojson['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final geometry = features[0]['geometry'];
          final coords = geometry?['coordinates'] as List?;
          if (coords != null && coords.isNotEmpty) {
            double cumDist = 0;
            final List<Map<String, dynamic>> profile = [];
            for (int i = 0; i < coords.length; i++) {
              final pt = coords[i] as List;
              double elev = pt.length > 2 ? (pt[2] as num).toDouble() : 50.0;
              if (i > 0) {
                final prev = coords[i - 1] as List;
                cumDist += _haversineMeters(
                  (prev[1] as num).toDouble(),
                  (prev[0] as num).toDouble(),
                  (pt[1] as num).toDouble(),
                  (pt[0] as num).toDouble(),
                );
              }
              profile.add({'distance': cumDist, 'elevation': elev});
            }
            if (profile.isNotEmpty) return profile;
          }
        }
      } catch (_) {}
    }
    return [];
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  /// Extracts the finish point (last coordinate) from routeGeojson.
  DashlyLatLng? _extractFinishPoint(Map<String, dynamic>? routeGeojson) {
    if (routeGeojson == null) return null;
    try {
      final features = routeGeojson['features'] as List?;
      if (features == null || features.isEmpty) return null;
      final geometry = features[0]['geometry'];
      final coords = geometry?['coordinates'] as List?;
      if (coords == null || coords.isEmpty) return null;
      final lastPt = coords.last as List;
      return DashlyLatLng((lastPt[1] as num).toDouble(), (lastPt[0] as num).toDouble());
    } catch (_) {
      return null;
    }
  }

  /// Checks if participant has crossed the finish line and auto-stops tracking.
  void _checkAutoFinish(TrackingProvider tracker, Event? currentEvent) {
    if (_hasAutoFinished || !tracker.isTracking || tracker.currentPosition == null) return;
    if (currentEvent == null) return;

    final finishPoint = _extractFinishPoint(currentEvent.routeGeojson);
    if (finishPoint == null) return;

    final distToFinish = tracker.currentPosition!.distanceTo(finishPoint);
    final routeTotalKm = (currentEvent.totalDistanceMeters ?? 0) / 1000.0;
    final progressPct = routeTotalKm > 0 ? (tracker.totalDistance / routeTotalKm) * 100.0 : 0.0;

    if (distToFinish < 20.0 && progressPct >= 90.0) {
      _hasAutoFinished = true;
      _triggerAutoFinish(tracker);
    }
  }

  /// Triggers the auto-finish sequence: haptic, stop tracking, save stats, navigate.
  Future<void> _triggerAutoFinish(TrackingProvider tracker) async {
    HapticFeedback.heavyImpact();

    final elapsed = _stopwatch.elapsed;
    final dist = tracker.totalDistance;
    final avgSpd = tracker.avgSpeed;
    final maxSpd = tracker.maxSpeed;
    final elev = tracker.elevationGain;
    final rank = tracker.currentRank;
    final totalRunners = tracker.totalParticipants;

    tracker.stopTracking();
    _stopwatch.stop();

    await OfflineStorageService.saveRaceSummary(
      eventId: widget.eventId,
      eventName: widget.eventName,
      elapsedDuration: elapsed,
      totalDistanceKm: dist,
      avgSpeedKmh: avgSpd,
      maxSpeedKmh: maxSpd,
      elevationGainM: elev,
      finalRank: rank,
      totalParticipants: totalRunners,
    );

    if (mounted) {
      context.read<EventProvider>().finishParticipant(
        widget.eventId,
        stats: {
          'durationSeconds': elapsed.inSeconds,
          'totalDistanceMeters': (dist * 1000).toInt(),
          'avgSpeedKmh': avgSpd,
          'maxSpeedKmh': maxSpd,
          'elevationGainMeters': elev.toInt(),
        },
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RaceSummaryScreen(
            eventId: widget.eventId,
            eventName: widget.eventName,
            elapsedDuration: elapsed,
            totalDistanceKm: dist,
            avgSpeedKmh: avgSpd,
            maxSpeedKmh: maxSpd,
            elevationGainM: elev,
            finalRank: rank,
            totalParticipants: totalRunners,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackingProvider>();
    final eventProvider = context.watch<EventProvider>();
    final currentEvent = eventProvider.currentEvent;

    // Check for auto-finish on every rebuild (triggered by tracker position updates)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAutoFinish(tracker, currentEvent);
    });

    final double elapsedHours = _stopwatch.elapsed.inSeconds / 3600.0;
    final double avgSpeed = tracker.avgSpeed > 0
        ? tracker.avgSpeed
        : (elapsedHours > 0 ? (tracker.totalDistance / elapsedHours) : 0.0);
    final altitudeProfile = _getEffectiveAltitudeProfile(eventProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await _showExitConfirmation();
        if (confirm && context.mounted) {
          if (tracker.isTracking) {
            tracker.stopTracking();
            _stopwatch.stop();
          }
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
                _buildHeaderPill(tracker, currentEvent),
                const SizedBox(height: 12),

                // Battery Saver Mode Badge
                _buildBatterySaverBadge(),
                const SizedBox(height: 16),

                // Hero Speedometer & 3 Key Telemetry Metrics Card
                _buildHeroSpeedCard(tracker, avgSpeed),
                const SizedBox(height: 16),

                // Altitude Chart directly below Telemetry Metrics
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.dashlyColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: context.dashlyColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ALTITUDE PROFILE & LIVE ELEVATION",
                          style: TextStyle(
                            color: context.dashlyColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: altitudeProfile.isNotEmpty
                              ? AltitudeChartWidget(
                                  altitudeProfile: altitudeProfile,
                                  currentDistanceMeters: tracker.totalDistance * 1000,
                                  otherRunners: tracker.otherRunners,
                                )
                              : Center(
                                  child: Text(
                                    "No Altitude Profile Available",
                                    style: TextStyle(color: context.dashlyColors.textHint, fontSize: 11),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom Action Controls (Start Race when inactive)
                if (!tracker.isTracking) _buildBottomControls(tracker),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderPill(TrackingProvider tracker, dynamic currentEvent) {
    final String bibText = currentEvent?.bibNumber != null
        ? " • BIB #${currentEvent.bibNumber}"
        : "";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: context.dashlyColors.divider),
      ),
      child: Row(
        children: [
          // Back Button
          InkWell(
            onTap: () async {
              if (await _showExitConfirmation() && mounted) {
                Navigator.pop(context);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: context.dashlyColors.accent,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "${widget.eventName.toUpperCase()}$bibText",
              style: TextStyle(
                color: context.dashlyColors.textPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _buildConnectionBadge(tracker.isMqttConnected),
          if (tracker.isTracking) ...[
            const SizedBox(width: 8),
            _buildFloatingSosButton(tracker),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionBadge(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatterySaverBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 6),
          Text(
            "BATTERY SAVER MODE (NO MAP)",
            style: TextStyle(
              color: Colors.amber[300],
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSpeedCard(TrackingProvider tracker, double avgSpeed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        boxShadow: DashlyTheme.glowShadow(
          color: context.dashlyColors.accent.withValues(alpha: 0.08),
          blur: 24,
        ),
      ),
      child: Column(
        children: [
          Text(
            "LIVE SPEED",
            style: TextStyle(
              color: context.dashlyColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                tracker.currentSpeed.toStringAsFixed(1),
                style: TextStyle(
                  color: context.dashlyColors.accent,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "KM/H",
                style: TextStyle(
                  color: context.dashlyColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeroMetricItem("DURATION", _formatDuration(_stopwatch.elapsed), ""),
              _buildHeroMetricDivider(),
              _buildHeroMetricItem("DISTANCE", tracker.totalDistance.toStringAsFixed(2), "KM"),
              _buildHeroMetricDivider(),
              _buildHeroMetricItem("ELEV GAIN", tracker.elevationGain.toStringAsFixed(0), "M"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetricItem(String label, String value, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.dashlyColors.textHint,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: context.dashlyColors.accent,
                fontFamily: 'monospace',
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: context.dashlyColors.textHint,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHeroMetricDivider() {
    return Container(
      width: 1,
      height: 24,
      color: context.dashlyColors.divider.withValues(alpha: 0.5),
    );
  }

  Widget _buildFloatingSosButton(TrackingProvider tracker) {
    return GestureDetector(
      onLongPressStart: (_) => _startSosHold(tracker),
      onLongPressEnd: (_) => _cancelSosHold(),
      onLongPressCancel: () => _cancelSosHold(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tracker.isSosTriggered ? Colors.red : Colors.red.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tracker.isSosTriggered ? Icons.warning_rounded : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  tracker.isSosTriggered ? "SOS ACTIVE" : "SOS",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (_isSosLongPressing)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LinearProgressIndicator(
                  value: _sosProgress,
                  backgroundColor: Colors.transparent,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSosButton(TrackingProvider tracker) {
    return GestureDetector(
      onLongPressStart: (_) => _startSosHold(tracker),
      onLongPressEnd: (_) => _cancelSosHold(),
      onLongPressCancel: () => _cancelSosHold(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: tracker.isSosTriggered ? Colors.red : Colors.red.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  tracker.isSosTriggered ? Icons.warning_rounded : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  tracker.isSosTriggered ? "SOS ACTIVE" : "HOLD SOS (3S)",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (_isSosLongPressing)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LinearProgressIndicator(
                  value: _sosProgress,
                  backgroundColor: Colors.transparent,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(TrackingProvider tracker) {
    return Row(
      children: [
        if (tracker.isTracking)
          Expanded(child: _buildSosButton(tracker))
        else
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                final userId = context.read<AuthProvider>().currentUser?.id ?? 0;
                try {
                  await tracker.startTracking(widget.eventId, userId);
                  _stopwatch.start();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("⚠️ $e", style: const TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: context.dashlyColors.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.dashlyColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                "START RACE NOW",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ),
      ],
    );
  }
}
