import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../models/event_model.dart';
import '../../theme/dashly_theme.dart';
import '../tracking/tracking_mode_dialog.dart';

import '../../components/gps_status_banner.dart';
import '../onboarding/permission_onboarding_dialog.dart';
import '../tracking/race_summary_screen.dart';
import '../../services/offline_storage_service.dart';
import '../main_navigation.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/event_list_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Map<int, Map<String, dynamic>> _summariesMap = {};
  bool _isLoadingSummaries = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PermissionOnboardingDialog.checkAndShow(context);
      if (!mounted) return;
      GpsStatusBanner.checkAndShowPopup(context);
      await context.read<EventProvider>().loadMyEvents();
      if (!mounted) return;
      _loadLocalSummaries(context.read<EventProvider>().myEvents);
      context.read<DashboardProvider>().fetchDashboardData();
    });
  }

  Future<void> _loadLocalSummaries(List<Event> myEvents) async {
    if (_isLoadingSummaries || myEvents.isEmpty) return;
    _isLoadingSummaries = true;
    final Map<int, Map<String, dynamic>> temp = {};
    for (var ev in myEvents) {
      final summary = await OfflineStorageService.getRaceSummary(ev.id);
      if (summary != null) {
        temp[ev.id] = summary;
      }
    }
    _isLoadingSummaries = false;
    if (mounted) {
      setState(() {
        _summariesMap = temp;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final eventProvider = context.watch<EventProvider>();
    final user = auth.currentUser;

    // Find active event (events where organizer status is not finished)
    final activeEvents = eventProvider.myEvents.where((e) => 
      e.status != EventStatus.finished
    ).toList()
      ..sort((a, b) => b.dateEvent.compareTo(a.dateEvent));

    final Event? activeEvent = activeEvents.isNotEmpty ? activeEvents.first : null;

    // Recent events (tracked or finished events, newest summary first)
    final recentEvents = (eventProvider.myEvents.where((e) {
      return e.participantState == ParticipantState.finished ||
          _summariesMap.containsKey(e.id) ||
          e.durationSeconds != null;
    }).toList()
      ..sort((a, b) {
        final summaryA = _summariesMap[a.id];
        final summaryB = _summariesMap[b.id];
        final String? timeAStr = summaryA?['updatedAt'] as String?;
        final String? timeBStr = summaryB?['updatedAt'] as String?;
        final DateTime timeA = timeAStr != null
            ? DateTime.tryParse(timeAStr) ?? a.dateEvent
            : a.dateEvent;
        final DateTime timeB = timeBStr != null
            ? DateTime.tryParse(timeBStr) ?? b.dateEvent
            : b.dateEvent;
        return timeB.compareTo(timeA);
      }))
      .take(3)
      .toList();

    // Actual participant registered events & total distance
    final int registeredCount = eventProvider.myEvents.length;
    double totalDistanceSum = 0.0;
    for (var ev in eventProvider.myEvents) {
      final summary = _summariesMap[ev.id];
      if (summary != null && summary['totalDistanceKm'] != null) {
        totalDistanceSum += (summary['totalDistanceKm'] as num).toDouble();
      } else if (ev.durationSeconds != null && ev.avgSpeedKmh != null) {
        totalDistanceSum += (ev.avgSpeedKmh! * (ev.durationSeconds! / 3600.0));
      }
    }

    return Scaffold(
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.dashlyColors.accent, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: context.dashlyColors.surfaceLight,
                          backgroundImage: user?.avatar != null && user!.avatar!.isNotEmpty
                              ? MemoryImage(
                                  const Base64Decoder().convert(user.avatar!.split(',').last),
                                )
                              : null,
                          child: user?.avatar == null || user!.avatar!.isEmpty
                              ? Icon(Icons.person_rounded, color: context.dashlyColors.accent)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hello, ${user?.name.split(' ').first ?? 'Athlete'}",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: context.dashlyColors.textPrimary,
                                ),
                          ),
                          Text(
                            "Ready For a Race Today?",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.dashlyColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.dashlyColors.surfaceLight,
                      borderRadius: DashlyTheme.radiusMd,
                    ),
                  child: Badge(
                    label: Text("2"),
                    child: Icon(Icons.notifications_none_rounded, color: context.dashlyColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),


            if (activeEvent != null) ...[
              _buildActiveEventCard(context, activeEvent),
              const SizedBox(height: 24),
            ] else ...[
              // Ready to Race CTA
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: context.dashlyColors.cardGradient,
                  borderRadius: DashlyTheme.radiusLg,
                  border: Border.all(color: context.dashlyColors.accent.withValues(alpha: 0.3)),
                  boxShadow: DashlyTheme.glowShadow(color: context.dashlyColors.accent.withValues(alpha: 0.1), blur: 30),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "NO ACTIVE RACES",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: context.dashlyColors.accent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Ready to join a new event?",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: context.dashlyColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (MainNavigation.isExploreEnabled) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/main');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.dashlyColors.accent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("EXPLORE EVENTS"),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Stats Grid
            Row(
              children: [
                Expanded(child: _buildSmallStat(context, "Registered Events", registeredCount.toString(), Icons.emoji_events_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _buildSmallStat(context, "Total Distance", "${totalDistanceSum.toStringAsFixed(1)} KM", Icons.route_outlined)),
              ],
            ),
            const SizedBox(height: 32),

            // Recent Activity
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "RECENT ACTIVITIES",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.dashlyColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (recentEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    "No completed races yet.",
                    style: TextStyle(color: context.dashlyColors.textHint),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentEvents.length,
                itemBuilder: (context, index) {
                  final event = recentEvents[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () async {
                        final summary = await OfflineStorageService.getRaceSummary(event.id);
                        if (!context.mounted) return;

                        final Duration elapsed = (summary != null && summary['elapsedDurationSeconds'] != null)
                            ? Duration(seconds: summary['elapsedDurationSeconds'] as int)
                            : (event.durationSeconds != null ? Duration(seconds: event.durationSeconds!) : Duration.zero);

                        final double dist = (summary != null && summary['totalDistanceKm'] != null)
                            ? (summary['totalDistanceKm'] as num).toDouble()
                            : 0.0;

                        final double avgSpd = (summary != null && summary['avgSpeedKmh'] != null)
                            ? (summary['avgSpeedKmh'] as num).toDouble()
                            : (event.avgSpeedKmh ?? 0.0);

                        final double maxSpd = (summary != null && summary['maxSpeedKmh'] != null)
                            ? (summary['maxSpeedKmh'] as num).toDouble()
                            : (event.maxSpeedKmh ?? 0.0);

                        final double elev = (summary != null && summary['elevationGainM'] != null)
                            ? (summary['elevationGainM'] as num).toDouble()
                            : (event.elevationGainMeters?.toDouble() ?? 0.0);

                        final int rank = summary != null ? (summary['finalRank'] as int? ?? 0) : 0;
                        final int totalRunners = summary != null ? (summary['totalParticipants'] as int? ?? 0) : 0;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RaceSummaryScreen(
                              eventId: event.id,
                              eventName: event.name,
                              elapsedDuration: elapsed,
                              totalDistanceKm: dist,
                              avgSpeedKmh: avgSpd,
                              maxSpeedKmh: maxSpd,
                              elevationGainM: elev,
                              finalRank: rank,
                              totalParticipants: totalRunners,
                              routeGeojson: event.routeGeojson,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.dashlyColors.surface,
                          borderRadius: DashlyTheme.radiusMd,
                          border: Border.all(color: context.dashlyColors.divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.dashlyColors.surfaceLight,
                                borderRadius: DashlyTheme.radiusSm,
                              ),
                              child: Icon(
                                event.category == EventCategory.running ? Icons.directions_run_rounded : Icons.directions_bike_rounded,
                                color: context.dashlyColors.accent
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.name,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: context.dashlyColors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _summariesMap.containsKey(event.id) && _summariesMap[event.id]!['totalDistanceKm'] != null
                                        ? "${(_summariesMap[event.id]!['totalDistanceKm'] as num).toDouble().toStringAsFixed(2)} KM • ${(_summariesMap[event.id]!['avgSpeedKmh'] as num).toDouble().toStringAsFixed(1)} KM/H"
                                        : "${event.dateEvent.day}/${event.dateEvent.month}/${event.dateEvent.year}",
                                    style: TextStyle(color: context.dashlyColors.textHint, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: context.dashlyColors.accent),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 80), // Padding for bottom nav
          ],
        ),
      ),
    );
  }

  Future<void> _handleStartTrackingFlow(BuildContext context, Event event) async {
    // 1. Check if event tracking is open (Req 2)
    if (!event.canStartTracking) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.dashlyColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: context.dashlyColors.accent.withValues(alpha: 0.5)),
          ),
          title: Row(
            children: [
              Icon(Icons.schedule_rounded, color: context.dashlyColors.accent, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "RACE NOT STARTED YET",
                  style: TextStyle(
                    color: context.dashlyColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            "Tracking for \"${event.name}\" has not been opened by the event organizer yet. Please wait until the official race start window begins.",
            style: TextStyle(
              color: context.dashlyColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "OK",
                style: TextStyle(
                  color: context.dashlyColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Check if GPS is enabled (Req 4)
    bool gpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!gpsEnabled && context.mounted) {
      await GpsStatusBanner.checkAndShowPopup(context);
      return;
    }

    // 3. Prompt for BIB number verification (Pre-filled if previously assigned)
    if (!context.mounted) return;
    final TextEditingController bibController = TextEditingController(text: event.bibNumber ?? '');

    bool? isBibVerified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isSubmitting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: context.dashlyColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: context.dashlyColors.accent, width: 1.5),
              ),
              title: Row(
                children: [
                  Icon(Icons.badge_rounded, color: context.dashlyColors.accent, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "ENTER YOUR BIB NUMBER",
                      style: TextStyle(
                        color: context.dashlyColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Please enter your assigned BIB number to verify your entry for \"${event.name}\":",
                    style: TextStyle(
                      color: context.dashlyColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bibController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: context.dashlyColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: "e.g., 001",
                      hintStyle: TextStyle(
                        color: context.dashlyColors.textHint,
                        letterSpacing: 0,
                      ),
                      errorText: errorText,
                      filled: true,
                      fillColor: context.dashlyColors.surfaceLight,
                      prefixIcon: Icon(Icons.numbers_rounded, color: context.dashlyColors.accent),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.dashlyColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.dashlyColors.accent, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx, false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: context.dashlyColors.divider),
                        ),
                        child: const Text("CANCEL"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final inputBib = bibController.text.trim();
                                if (inputBib.isEmpty) {
                                  setDialogState(() {
                                    errorText = "BIB number is required";
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  isSubmitting = true;
                                  errorText = null;
                                });

                                try {
                                  final res = await context
                                      .read<EventListProvider>()
                                      .verifyBib(event.id, inputBib);

                                  if (res['success'] == true) {
                                    if (context.mounted) {
                                      Navigator.pop(dialogCtx, true);
                                    }
                                  } else {
                                    setDialogState(() {
                                      isSubmitting = false;
                                      errorText = res['message'] ?? "Invalid BIB number";
                                    });
                                  }
                                } catch (e) {
                                  setDialogState(() {
                                    isSubmitting = false;
                                    errorText = "Verification failed: $e";
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.dashlyColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text("VERIFY"),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (isBibVerified == true && context.mounted) {
      showTrackingModeSelectionDialog(context, eventId: event.id, eventName: event.name);
    }
  }

  Widget _buildActiveEventCard(BuildContext context, Event event) {
    final tracker = context.watch<TrackingProvider>();
    bool isTracking = tracker.isTracking && tracker.activeEventId == event.id;

    String statusBadgeText = isTracking ? "LIVE TRACKING ACTIVE" : "READY TO TRACK";
    Color badgeColor = context.dashlyColors.accent;
    String subtitleText = isTracking ? "Tap to continue tracking" : "Tap to enter race tracking";

    return GestureDetector(
      onTap: () {
        if (isTracking) {
          showTrackingModeSelectionDialog(context, eventId: event.id, eventName: event.name);
        } else {
          _handleStartTrackingFlow(context, event);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.dashlyColors.surface,
          borderRadius: DashlyTheme.radiusLg,
          border: Border.all(color: context.dashlyColors.accent, width: 2),
          boxShadow: DashlyTheme.glowShadow(color: context.dashlyColors.accent.withValues(alpha: 0.3), blur: 20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isTracking ? Icons.sensors_rounded : Icons.directions_bike_rounded,
                        color: badgeColor,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusBadgeText,
                        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: context.dashlyColors.accent, size: 14),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              event.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.dashlyColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitleText,
              style: TextStyle(color: context.dashlyColors.textHint, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStat(BuildContext context, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: DashlyTheme.radiusMd,
        border: Border.all(color: context.dashlyColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: context.dashlyColors.accent, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: context.dashlyColors.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: context.dashlyColors.textHint, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
