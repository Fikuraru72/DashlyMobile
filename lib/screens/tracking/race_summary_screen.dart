import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../theme/dashly_theme.dart';
import 'live_map_widget.dart';

/// ════════════════════════════════════════════════════════════════
/// RaceSummaryScreen — Post-Race Cycling Summary Screen 🏆
/// ════════════════════════════════════════════════════════════════
/// Displays cycling post-race performance results including:
/// - 4 Hero Metrics: Total Ride Time, Distance (KM), Avg Speed (KM/H), Elev Gain (M)
/// - Performance Breakdown: Max Speed, Ranking, Min/Max Altitude
/// - Interactive Route Track Map & Altitude Profile Chart
/// ════════════════════════════════════════════════════════════════
class RaceSummaryScreen extends StatelessWidget {
  final int eventId;
  final String eventName;
  final Duration elapsedDuration;
  final double totalDistanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double elevationGainM;
  final int finalRank;
  final int totalParticipants;

  const RaceSummaryScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.elapsedDuration,
    required this.totalDistanceKm,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.elevationGainM,
    this.finalRank = 0,
    this.totalParticipants = 0,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final currentEvent = eventProvider.currentEvent;

    final String bibText = (currentEvent != null && currentEvent.bibNumber != null)
        ? " • BIB #${currentEvent.bibNumber}"
        : "";

    final rankDisplay = finalRank > 0
        ? "#$finalRank${totalParticipants > 0 ? ' / $totalParticipants' : ''}"
        : "-";

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: context.dashlyColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: context.dashlyColors.textHint),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "RACE SUMMARY",
            style: TextStyle(
              color: context.dashlyColors.accent,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              fontSize: 14,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                // 1. Celebration Trophy & Header Badge
                _buildCelebrationHeader(context, bibText),
                const SizedBox(height: 20),

                // 2. Hero 4 Metrics Grid (2x2)
                _buildHeroMetricsGrid(context),
                const SizedBox(height: 16),

                // 3. Performance Detail Card (Max Speed, Rank, Elev)
                _buildPerformanceDetailCard(context, rankDisplay),
                const SizedBox(height: 16),

                // 4. Interactive Route Map Preview if Available
                if (currentEvent?.routeGeojson != null) ...[
                  _buildSectionLabel(context, "CYCLING ROUTE TRACK"),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.dashlyColors.divider),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LiveMapWidget(
                        currentPosition: null,
                        routeGeojson: currentEvent?.routeGeojson,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 5. Back to My Events Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.dashlyColors.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 6,
                    ),
                    child: const Text(
                      "BACK TO MY EVENTS",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationHeader(BuildContext context, String bibText) {
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
        border: Border.all(color: context.dashlyColors.accent.withValues(alpha: 0.4)),
        boxShadow: DashlyTheme.glowShadow(
          color: context.dashlyColors.accent.withValues(alpha: 0.1),
          blur: 24,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.dashlyColors.accent.withValues(alpha: 0.15),
              border: Border.all(color: context.dashlyColors.accent, width: 2),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              size: 40,
              color: context.dashlyColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "CYCLING RACE COMPLETED 🏁",
            style: TextStyle(
              color: context.dashlyColors.accent,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${eventName.toUpperCase()}$bibText",
            style: TextStyle(
              color: context.dashlyColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetricsGrid(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.dashlyColors.divider),
      ),
      child: Column(
        children: [
          // Row 1: Duration & Distance
          Row(
            children: [
              Expanded(child: _buildHeroMetricItem(context, "RIDE TIME", _formatDuration(elapsedDuration), "", Icons.timer_outlined)),
              _buildDivider(context),
              Expanded(child: _buildHeroMetricItem(context, "DISTANCE", totalDistanceKm.toStringAsFixed(2), "KM", Icons.straighten_rounded)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Colors.white10),
          ),
          // Row 2: Avg Speed & Elevation Gain
          Row(
            children: [
              Expanded(child: _buildHeroMetricItem(context, "AVG SPEED", avgSpeedKmh.toStringAsFixed(1), "KM/H", Icons.directions_bike_rounded)),
              _buildDivider(context),
              Expanded(child: _buildHeroMetricItem(context, "ELEV GAIN", elevationGainM.toStringAsFixed(0), "M", Icons.landscape_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetricItem(BuildContext context, String label, String value, String unit, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: context.dashlyColors.textHint),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: context.dashlyColors.textHint,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: context.dashlyColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(
                unit,
                style: TextStyle(
                  color: context.dashlyColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceDetailCard(BuildContext context, String rankDisplay) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.dashlyColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDetailStat(context, "MAX SPEED", "${maxSpeedKmh.toStringAsFixed(1)} km/h", Icons.speed_rounded),
          _buildDivider(context),
          _buildDetailStat(context, "FINAL RANK", rankDisplay, Icons.military_tech_rounded),
        ],
      ),
    );
  }

  Widget _buildDetailStat(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: context.dashlyColors.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: context.dashlyColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: context.dashlyColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: context.dashlyColors.divider.withValues(alpha: 0.4),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          color: context.dashlyColors.textSecondary,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
