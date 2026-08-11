import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import '../../providers/auth_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/event_provider.dart';
import '../../theme/dashly_theme.dart';
import 'live_map_widget.dart';
import '../../widgets/altitude_chart_widget.dart';
import 'race_summary_screen.dart';
import '../../services/offline_storage_service.dart';

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
  MapLibreMapController? _mapController;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSosLongPressing = false;
  double _sosProgress = 0.0;
  Timer? _sosTimer;
  bool _isMetricsPanelCollapsed = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
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
    _pageController.dispose();
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

  List<dynamic> _getEffectiveAltitudeProfile(dynamic event) {
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

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackingProvider>();
    final eventProvider = context.watch<EventProvider>();
    final currentEvent = eventProvider.currentEvent;

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
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. FULL-SCREEN MAP
            Positioned.fill(
              child: LiveMapWidget(
                currentPosition: tracker.currentPosition,
                routeGeojson: currentEvent?.routeGeojson,
                onControllerCreated: (controller) {
                  _mapController = controller;
                },
              ),
            ),

            // 2. TOP HEADER (Translucent Pill with Event Name & BIB Number shown ONCE)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: _buildHeaderPill(tracker, currentEvent),
            ),

            // 3. DOCKED BOTTOM PANEL (STATISTIK - MENEMPEL DI BAWAH)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildDockedBottomPanel(tracker, currentEvent),
            ),

            // 4. MAP CONTROLS - LEFT SIDE (Reset North & Center Pointer)
            // Rendered AFTER bottom panel so they appear ON TOP (higher z-order)
            Positioned(
              left: 16,
              bottom: (_isMetricsPanelCollapsed ? 195 : 320) + MediaQuery.of(context).padding.bottom + 10,
              child: _buildMapActionButton(
                icon: Icons.my_location_rounded,
                tooltip: "Center Pointer",
                onTap: () {
                  _mapController?.updateMyLocationTrackingMode(MyLocationTrackingMode.trackingCompass);
                },
              ),
            ),

            // 5. MAP CONTROLS - RIGHT SIDE (Zoom In & Zoom Out)
            Positioned(
              right: 16,
              bottom: (_isMetricsPanelCollapsed ? 195 : 320) + MediaQuery.of(context).padding.bottom + 10,
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: context.dashlyColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: context.dashlyColors.divider.withValues(alpha: 0.5)),
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
        ),
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
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.dashlyColors.surface.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              border: Border.all(color: context.dashlyColors.divider.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: context.dashlyColors.accent, size: 20),
          ),
        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              mainAxisSize: MainAxisSize.min,
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

  Widget _buildDockedBottomPanel(TrackingProvider tracker, dynamic currentEvent) {
    final double elapsedHours = _stopwatch.elapsed.inSeconds / 3600.0;
    final double avgSpeed = tracker.avgSpeed > 0
        ? tracker.avgSpeed
        : (elapsedHours > 0 ? (tracker.totalDistance / elapsedHours) : 0.0);
    final altitudeProfile = _getEffectiveAltitudeProfile(currentEvent);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 14,
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
          // Header Row with Hide/Show Toggle Button
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
              InkWell(
                onTap: () {
                  setState(() {
                    _isMetricsPanelCollapsed = !_isMetricsPanelCollapsed;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: context.dashlyColors.divider.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isMetricsPanelCollapsed
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: context.dashlyColors.textPrimary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isMetricsPanelCollapsed ? "EXPAND" : "COMPACT",
                        style: TextStyle(
                          color: context.dashlyColors.textPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // If Expanded: Show PageView & Indicators
          if (!_isMetricsPanelCollapsed) ...[
            SizedBox(
              height: 145,
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                },
                children: [
                  // PAGE 1: 6 Metrik Utama (Grid)
                  _buildMetricsGrid(tracker, avgSpeed),

                  // PAGE 2: Altitude Chart (Multi-Participant)
                  if (altitudeProfile.isNotEmpty)
                    AltitudeChartWidget(
                      altitudeProfile: altitudeProfile,
                      currentDistanceMeters: tracker.totalDistance * 1000,
                      otherRunners: tracker.otherRunners,
                    )
                  else
                    const Center(
                      child: Text("No Altitude Profile Available", style: TextStyle(color: Colors.grey)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Page Indicator Dots & Slide Text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == 0 ? context.dashlyColors.accent : Colors.grey.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == 1 ? context.dashlyColors.accent : Colors.grey.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currentPage == 0 ? "SLIDE FOR CHART ➔" : "⬅ SLIDE FOR METRICS",
                  style: TextStyle(
                    color: context.dashlyColors.textHint,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
          ] else ...[
            // Compact 1-row metrics view when panel is shrunk (Mengecil)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: context.dashlyColors.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.dashlyColors.divider.withValues(alpha: 0.3),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCompactMetric("TIME", _formatDuration(_stopwatch.elapsed), ""),
                    _buildCompactDivider(),
                    _buildCompactMetric("DIST", tracker.totalDistance.toStringAsFixed(2), "km"),
                    _buildCompactDivider(),
                    _buildCompactMetric("SPD", tracker.currentSpeed.toStringAsFixed(1), "km/h"),
                    _buildCompactDivider(),
                    _buildCompactMetric("AVG", avgSpeed.toStringAsFixed(1), "km/h"),
                  ],
                ),
              ),
            ),
          ],

          // ACTION BUTTONS ROW (SOS & START/STOP RACE)
          Row(
            children: [
              if (tracker.isTracking) ...[
                // Clear, obvious SOS Button
                _buildSosButton(tracker),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: !tracker.isTracking
                    ? ElevatedButton(
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
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          if (await _showExitConfirmation()) {
                            final elapsed = _stopwatch.elapsed;
                            final dist = tracker.totalDistance;
                            final avgSpd = tracker.avgSpeed;
                            final maxSpd = tracker.maxSpeed;
                            final elev = tracker.elevationGain;
                            final rank = tracker.currentRank;
                            final totalRunners = tracker.totalParticipants;

                            tracker.stopTracking();
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
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.dashlyColors.error.withValues(alpha: 0.85),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          "STOP TRACKING",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(TrackingProvider tracker, double avgSpeed) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Row 1: Duration & Distance
        Row(
          children: [
            Expanded(child: _buildMetricItem("DURATION", _formatDuration(_stopwatch.elapsed), "")),
            _buildMetricDivider(),
            Expanded(child: _buildMetricItem("DISTANCE", tracker.totalDistance.toStringAsFixed(2), "KM")),
          ],
        ),
        const SizedBox(height: 16),
        // Row 2: Elevation Gain & Speed
        Row(
          children: [
            Expanded(child: _buildMetricItem("ELEV GAIN", tracker.elevationGain.toStringAsFixed(0), "M")),
            _buildMetricDivider(),
            Expanded(child: _buildMetricItem("SPEED", tracker.currentSpeed.toStringAsFixed(1), "KM/H")),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 32,
      color: context.dashlyColors.divider.withValues(alpha: 0.4),
    );
  }

  Widget _buildMetricItem(String label, String value, String unit) {
    return Column(
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
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: context.dashlyColors.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 9,
                  color: context.dashlyColors.textHint,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCompactMetric(String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.dashlyColors.textHint,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: context.dashlyColors.textPrimary,
                  fontFamily: 'monospace',
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 8,
                    color: context.dashlyColors.textHint,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDivider() {
    return Container(
      width: 1,
      height: 28,
      color: context.dashlyColors.divider.withValues(alpha: 0.3),
    );
  }
}
