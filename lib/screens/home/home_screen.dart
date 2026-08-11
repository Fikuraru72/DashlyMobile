import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../../theme/dashly_theme.dart';
import '../tracking/tracking_mode_dialog.dart';

import '../../components/gps_status_banner.dart';
import '../onboarding/permission_onboarding_dialog.dart';
import '../tracking/race_summary_screen.dart';
import '../../services/offline_storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PermissionOnboardingDialog.checkAndShow(context);
      if (!mounted) return;
      GpsStatusBanner.checkAndShowPopup(context);
      context.read<EventProvider>().loadMyEvents();
      context.read<DashboardProvider>().fetchDashboardData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dash = context.watch<DashboardProvider>();
    final eventProvider = context.watch<EventProvider>();
    final user = auth.currentUser;
    final stats = dash.stats;

    // Find active event (newest tracking, confirmed, or event status is START)
    final activeEvents = eventProvider.myEvents.where((e) => 
      e.status == EventStatus.start || 
      e.participantState == ParticipantState.tracking || 
      e.participantState == ParticipantState.confirmed
    ).toList()
      ..sort((a, b) => b.dateEvent.compareTo(a.dateEvent));

    final Event? activeEvent = activeEvents.isNotEmpty ? activeEvents.first : null;

    // Recent events (newest 3 finished)
    final recentEvents = (eventProvider.myEvents
        .where((e) => e.participantState == ParticipantState.finished)
        .toList()
        ..sort((a, b) => b.dateEvent.compareTo(a.dateEvent)))
        .take(3)
        .toList();

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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to explore screen
                          Navigator.pushNamed(context, '/main'); // MainNavigation defaults to home, maybe we just use bottom nav or a direct route
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.dashlyColors.accent,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text("EXPLORE EVENTS"),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Stats Grid
            Row(
              children: [
                Expanded(child: _buildSmallStat(context, "Registered Events", stats.totalEvents.toString(), Icons.emoji_events_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _buildSmallStat(context, "Total Distance", "${stats.totalDistance.toStringAsFixed(1)} KM", Icons.route_outlined)),
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

                        final Duration elapsed = summary != null
                            ? Duration(seconds: summary['elapsedDurationSeconds'] as int)
                            : const Duration(minutes: 45);

                        final double dist = summary != null
                            ? (summary['totalDistanceKm'] as num).toDouble()
                            : (event.totalDistanceMeters ?? 10000) / 1000.0;

                        final double avgSpd = summary != null
                            ? (summary['avgSpeedKmh'] as num).toDouble()
                            : 28.5;

                        final double maxSpd = summary != null
                            ? (summary['maxSpeedKmh'] as num).toDouble()
                            : 42.0;

                        final double elev = summary != null
                            ? (summary['elevationGainM'] as num).toDouble()
                            : (event.totalElevationMeters ?? 250).toDouble();

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
                                    "${event.dateEvent.day}/${event.dateEvent.month}/${event.dateEvent.year}",
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

  Widget _buildActiveEventCard(BuildContext context, Event event) {
    bool isTracking = event.participantState == ParticipantState.tracking;
    return GestureDetector(
      onTap: () {
        showTrackingModeSelectionDialog(context, eventId: event.id, eventName: event.name);
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
                    color: context.dashlyColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.dashlyColors.accent),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sensors_rounded, color: context.dashlyColors.accent, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        isTracking ? "LIVE TRACKING ACTIVE" : "READY TO TRACK",
                        style: TextStyle(color: context.dashlyColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
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
              "Tap to continue tracking",
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
