import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/event_provider.dart';
import '../../theme/dashly_theme.dart';
import 'live_map_widget.dart';
import '../../widgets/altitude_chart_widget.dart';
import 'race_summary_screen.dart';
import '../../services/offline_storage_service.dart';
import '../../core/utils/geo_utils.dart';
import '../../models/event_model.dart';

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
  late final ValueNotifier<Duration> _elapsedNotifier;
  late Timer _timer;
  MapLibreMapController? _mapController;
  bool _isSosLongPressing = false;
  double _sosProgress = 0.0;
  Timer? _sosTimer;
  bool _isMetricsPanelCollapsed = false;
  bool _hasAutoFinished = false;

  @override
  void initState() {
    super.initState();
    _elapsedNotifier = ValueNotifier(Duration.zero);
    _stopwatch = Stopwatch();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _stopwatch.isRunning) {
        _elapsedNotifier.value = _stopwatch.elapsed;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<EventProvider>().fetchEvent(widget.eventId);
      
      final tracker = context.read<TrackingProvider>();
      if (!tracker.isTracking) {
        final userId = context.read<AuthProvider>().currentUser?.id ?? 0;
        try {
          await tracker.startTracking(widget.eventId, userId);
          _stopwatch.start();
        } catch (e) {
          debugPrint('TrackingScreen: Failed to auto start tracking: $e');
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
    _elapsedNotifier.dispose();
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

  List<dynamic> _getEffectiveAltitudeProfile(EventProvider eventProvider) {
    dynamic event = eventProvider.currentEvent ?? eventProvider.getCachedEvent(widget.eventId);

    // Instant Fallback: If currentEvent is null or lacks route data, check myEvents in eventProvider
    if (event == null || (event.altitudeProfile == null && event.routeGeojson == null)) {
      try {
        event = eventProvider.myEvents.firstWhere((e) => e.id == widget.eventId);
      } catch (_) {}
    }

    if (event?.altitudeProfile != null && (event.altitudeProfile as List).isNotEmpty) {
      return event.altitudeProfile!;
    }
    // Fallback: Build altitude profile from routeGeojson coordinates if available
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
    const r = 6371000.0; // Earth radius in meters
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
      // GeoJSON format: [lng, lat, (elev)]
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

    // Calculate distance from current GPS position to the finish point
    final distToFinish = tracker.currentPosition!.distanceTo(finishPoint);

    // Calculate approximate progress percentage based on distance covered vs route total
    final routeTotalKm = (currentEvent.totalDistanceMeters ?? 0) / 1000.0;
    final progressPct = routeTotalKm > 0 ? (tracker.totalDistance / routeTotalKm) * 100.0 : 0.0;

    // Auto-finish conditions: within 20m of finish AND covered ≥ 90% of route
    if (distToFinish < 20.0 && progressPct >= 90.0) {
      _hasAutoFinished = true;
      _triggerAutoFinish(tracker);
    }
  }

  /// Triggers the auto-finish sequence: haptic, stop tracking, save stats, navigate.
  Future<void> _triggerAutoFinish(TrackingProvider tracker) async {
    // Haptic feedback
    HapticFeedback.heavyImpact();

    final elapsed = _stopwatch.elapsed;
    final dist = tracker.totalDistance;
    final avgSpd = tracker.avgSpeed;
    final maxSpd = tracker.maxSpeed;
    final elev = tracker.elevationGain;
    final rank = tracker.currentRank;
    final totalRunners = tracker.totalParticipants;

    await tracker.stopTracking();
    _stopwatch.stop();

    // Save race summary locally into SQLite
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
      final nav = Navigator.of(context);
      final eventProv = context.read<EventProvider>();
      eventProv.finishParticipant(
        widget.eventId,
        stats: {
          'durationSeconds': elapsed.inSeconds,
          'totalDistanceMeters': (dist * 1000).toInt(),
          'avgSpeedKmh': avgSpd,
          'maxSpeedKmh': maxSpd,
          'elevationGainMeters': elev.toInt(),
        },
      );
      eventProv.clearCurrentEvent();
      nav.pushReplacement(
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
    final altitudeProfile = _getEffectiveAltitudeProfile(eventProvider);

    double totalRouteKm = 0.0;
    if (currentEvent?.totalDistanceMeters != null && currentEvent!.totalDistanceMeters! > 0) {
      totalRouteKm = currentEvent.totalDistanceMeters! / 1000.0;
    } else if (altitudeProfile.isNotEmpty) {
      final lastPt = altitudeProfile.last;
      if (lastPt is Map && lastPt['distance'] != null) {
        totalRouteKm = (lastPt['distance'] as num).toDouble() / 1000.0;
      }
    }

    final double remainingKm = totalRouteKm > tracker.totalDistance
        ? (totalRouteKm - tracker.totalDistance)
        : 0.0;

    // Check for auto-finish on every rebuild (triggered by tracker position updates)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAutoFinish(tracker, currentEvent);
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await _showExitConfirmation();
        if (confirm && context.mounted) {
          final nav = Navigator.of(context);
          final eventProv = context.read<EventProvider>();
          await context.read<TrackingProvider>().stopTracking();
          eventProv.clearCurrentEvent();
          nav.pop(result);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. LIVE MAP LAYER (Full screen)
            Positioned.fill(
              child: RepaintBoundary(
                child: LiveMapWidget(
                  currentPosition: tracker.currentPosition,
                  routeGeojson: currentEvent?.routeGeojson,
                  onControllerCreated: (controller) {
                    _mapController = controller;
                  },
                ),
              ),
            ),

            // 2. TOP HEADER (Translucent Pill with Back Button & Event Name)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: _buildHeaderPill(tracker, currentEvent),
            ),

            // 3. TOP LEFT TO DESTINATION BADGE
            Positioned(
              top: MediaQuery.of(context).padding.top + 65,
              left: 16,
              child: _buildToDestinationBadge(remainingKm),
            ),

            // 4. FLOATING CIRCULAR SOS BUTTON (Top Right below Header Pill)
            if (tracker.isTracking)
              Positioned(
                top: MediaQuery.of(context).padding.top + 65,
                right: 16,
                child: _buildFloatingSosButton(tracker),
              ),

            // 4. DOCKED BOTTOM PANEL (STATISTIK - MENEMPEL DI BAWAH)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildDockedBottomPanel(tracker, eventProvider),
            ),

            // 5. MAP CONTROLS - LEFT SIDE (Center Pointer 3D)
            Positioned(
              left: 16,
              bottom: _isMetricsPanelCollapsed
                  ? (115 + MediaQuery.of(context).padding.bottom)
                  : ((_getEffectiveAltitudeProfile(eventProvider).isNotEmpty ? 305 : 155) +
                      MediaQuery.of(context).padding.bottom),
              child: _buildMapActionButton(
                icon: Icons.my_location_rounded,
                tooltip: "Center Pointer 3D",
                onTap: () {
                  final pos = tracker.currentPosition;
                  if (pos != null && _mapController != null) {
                    try {
                      _mapController?.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: LatLng(pos.latitude, pos.longitude),
                            zoom: 18.0,
                            tilt: 55.0,
                            bearing: pos.heading > 0 ? pos.heading : 0.0,
                          ),
                        ),
                      );
                    } catch (_) {}
                  }
                },
              ),
            ),

            // 6. MAP CONTROLS - RIGHT SIDE (Zoom In, Zoom Out, Expand/Compact Toggle)
            Positioned(
              right: 16,
              bottom: _isMetricsPanelCollapsed
                  ? (115 + MediaQuery.of(context).padding.bottom)
                  : ((_getEffectiveAltitudeProfile(eventProvider).isNotEmpty ? 305 : 155) +
                      MediaQuery.of(context).padding.bottom),
              child: Column(
                children: [
                  _buildMapActionButton(
                    icon: Icons.add_rounded,
                    tooltip: "Zoom In",
                    onTap: () {
                      _mapController?.animateCamera(CameraUpdate.zoomIn());
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildMapActionButton(
                    icon: Icons.remove_rounded,
                    tooltip: "Zoom Out",
                    onTap: () {
                      _mapController?.animateCamera(CameraUpdate.zoomOut());
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildMapActionButton(
                    icon: _isMetricsPanelCollapsed
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    tooltip: _isMetricsPanelCollapsed ? "Expand Chart" : "Compact Chart",
                    onTap: () {
                      setState(() {
                        _isMetricsPanelCollapsed = !_isMetricsPanelCollapsed;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
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
        color: context.dashlyColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: context.dashlyColors.divider.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          InkWell(
            onTap: () async {
              if (await _showExitConfirmation() && mounted) {
                final nav = Navigator.of(context);
                final eventProv = context.read<EventProvider>();
                await context.read<TrackingProvider>().stopTracking();
                eventProv.clearCurrentEvent();
                nav.pop();
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
        ],
      ),
    );
  }

  Widget _buildToDestinationBadge(double remainingKm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.dashlyColors.accent.withValues(alpha: 0.7), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag_rounded,
                color: context.dashlyColors.accent,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                "TO DESTINATION",
                style: TextStyle(
                  color: context.dashlyColors.textHint,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            "${remainingKm.toStringAsFixed(2)} KM",
            style: TextStyle(
              color: context.dashlyColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
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

  Widget _buildMapActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.dashlyColors.surface.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(color: context.dashlyColors.divider.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: context.dashlyColors.accent, size: 20),
      ),
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: tracker.isSosTriggered ? Colors.red : Colors.red.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  tracker.isSosTriggered ? Icons.warning_rounded : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const Text(
                  "SOS",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 8,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (_isSosLongPressing)
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: _sosProgress,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDockedBottomPanel(TrackingProvider tracker, EventProvider eventProvider) {
    final altitudeProfile = _getEffectiveAltitudeProfile(eventProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isMetricsPanelCollapsed ? "RACE TELEMETRY (COMPACT)" : "RACE TELEMETRY",
                style: TextStyle(
                  color: context.dashlyColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 3 HERO METRICS ROW: DURATION | DISTANCE | ELEV GAIN
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ValueListenableBuilder<Duration>(
                valueListenable: _elapsedNotifier,
                builder: (context, elapsed, _) {
                  return _buildHeroMetricItem("DURATION", _formatDuration(elapsed), "");
                },
              ),
              _buildHeroMetricDivider(),
              _buildHeroMetricItem("DISTANCE", tracker.totalDistance.toStringAsFixed(2), "KM"),
              _buildHeroMetricDivider(),
              _buildHeroMetricItem("ELEV GAIN", tracker.elevationGain.toStringAsFixed(0), "M"),
            ],
          ),

          if (!_isMetricsPanelCollapsed) ...[
            const SizedBox(height: 12),
            if (altitudeProfile.isNotEmpty)
              RepaintBoundary(
                child: AltitudeChartWidget(
                  altitudeProfile: altitudeProfile,
                  currentDistanceMeters: tracker.totalDistance * 1000,
                  otherRunners: tracker.otherRunners,
                ),
              )
            else
              Container(
                height: 50,
                alignment: Alignment.center,
                child: Text(
                  "No Altitude Profile Available",
                  style: TextStyle(color: context.dashlyColors.textHint, fontSize: 11),
                ),
              ),
          ],
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
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
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
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: context.dashlyColors.accent,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
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
      height: 28,
      color: context.dashlyColors.divider.withValues(alpha: 0.5),
    );
  }
}
