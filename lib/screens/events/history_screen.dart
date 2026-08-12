import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../../theme/dashly_theme.dart';
import '../tracking/tracking_mode_dialog.dart';
import '../tracking/race_summary_screen.dart';
import '../../services/offline_storage_service.dart';
import 'event_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  EventStatus _selectedFilter = EventStatus.start; // Default to Live

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadMyEvents();
    });
  }

  Future<void> _onRefresh() async {
    await context.read<EventProvider>().loadMyEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MY EVENT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<EventProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingMyEvents && provider.myEvents.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.myEventsError != null && provider.myEvents.isEmpty) {
            return Center(
              child: Text(
                provider.myEventsError!,
                style: TextStyle(color: context.dashlyColors.error),
              ),
            );
          }

          final events = provider.myEvents.where((e) {
            return e.status == _selectedFilter;
          }).toList()
            ..sort((a, b) => b.dateEvent.compareTo(a.dateEvent));

          return Column(
            children: [
              _buildFilterChips(context),
              Expanded(
                child: events.isEmpty 
                    ? RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: _buildEmptyState(context),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            return _buildMyEventCard(context, events[index]);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(context, "Live", EventStatus.start),
          const SizedBox(width: 8),
          _buildFilterChip(context, "Waiting", EventStatus.idle),
          const SizedBox(width: 8),
          _buildFilterChip(context, "Finished", EventStatus.finished),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, EventStatus status) {
    final isSelected = _selectedFilter == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.dashlyColors.accent : context.dashlyColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? context.dashlyColors.accent : context.dashlyColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : context.dashlyColors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 80, color: context.dashlyColors.textHint.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            "No events found",
            style: TextStyle(color: context.dashlyColors.textHint, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            "You haven't joined any events matching this filter.",
            textAlign: TextAlign.center,
            style: TextStyle(color: context.dashlyColors.textHint.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildMyEventCard(BuildContext context, Event event) {
    final bool isRunning = event.category == EventCategory.running;
    final IconData categoryIcon = isRunning ? Icons.directions_run_rounded : Icons.directions_bike_rounded;

    Color statusColor;
    String statusText;
    bool isLive = event.status == EventStatus.start;
    bool isFinished = event.status == EventStatus.finished || event.participantState == ParticipantState.finished;

    switch (event.status) {
      case EventStatus.start:
        statusColor = context.dashlyColors.accent;
        statusText = "LIVE";
        break;
      case EventStatus.finished:
        statusColor = context.dashlyColors.error;
        statusText = "FINISHED";
        break;
      case EventStatus.idle:
        statusColor = context.dashlyColors.textHint;
        statusText = "WAITING";
        break;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.dashlyColors.surface,
          borderRadius: DashlyTheme.radiusMd,
          border: Border.all(
            color: isLive ? context.dashlyColors.accent : context.dashlyColors.divider,
            width: isLive ? 2 : 1,
          ),
          boxShadow: isLive ? [BoxShadow(color: context.dashlyColors.accent.withValues(alpha: 0.1), blurRadius: 10)] : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.dashlyColors.surfaceLight,
                    borderRadius: DashlyTheme.radiusSm,
                  ),
                  child: Icon(categoryIcon, color: isLive ? context.dashlyColors.accent : context.dashlyColors.textHint),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: TextStyle(fontWeight: FontWeight.bold, color: context.dashlyColors.textPrimary, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${event.dateEvent.day}/${event.dateEvent.month}/${event.dateEvent.year}",
                        style: TextStyle(color: context.dashlyColors.textHint, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLive 
                          ? Icons.sensors_rounded 
                          : (event.status == EventStatus.finished ? Icons.flag_rounded : Icons.schedule_rounded), 
                        color: statusColor, 
                        size: 12
                      ),
                      const SizedBox(width: 4),
                      Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),

            // Show BIB number if available
            if (event.bibNumber != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.dashlyColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.dashlyColors.accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.badge_rounded, color: context.dashlyColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text("BIB: ", style: TextStyle(color: context.dashlyColors.textSecondary, fontSize: 12)),
                    Text(event.bibNumber!, style: TextStyle(color: context.dashlyColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
                  ],
                ),
              ),
            ],

            if (isLive) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  showTrackingModeSelectionDialog(context, eventId: event.id, eventName: event.name);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.dashlyColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded),
                    SizedBox(width: 8),
                    Text("ENTER RACE NOW", style: TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ] else if (isFinished) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final summary = await OfflineStorageService.getRaceSummary(event.id);
                    if (!context.mounted) return;

                    final Duration elapsed = (summary != null && summary['elapsedDurationSeconds'] != null)
                        ? Duration(seconds: summary['elapsedDurationSeconds'] as int)
                        : (event.durationSeconds != null ? Duration(seconds: event.durationSeconds!) : Duration.zero);

                    final double dist = (summary != null && summary['totalDistanceKm'] != null)
                        ? (summary['totalDistanceKm'] as num).toDouble()
                        : ((event.totalDistanceMeters ?? 0) / 1000.0);

                    final double avgSpd = (summary != null && summary['avgSpeedKmh'] != null)
                        ? (summary['avgSpeedKmh'] as num).toDouble()
                        : (event.avgSpeedKmh ?? 0.0);

                    final double maxSpd = (summary != null && summary['maxSpeedKmh'] != null)
                        ? (summary['maxSpeedKmh'] as num).toDouble()
                        : (event.maxSpeedKmh ?? 0.0);

                    final double elev = (summary != null && summary['elevationGainM'] != null)
                        ? (summary['elevationGainM'] as num).toDouble()
                        : (event.elevationGainMeters?.toDouble() ?? ((event.totalElevationMeters ?? 0).toDouble()));

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
                  icon: Icon(Icons.emoji_events_rounded, color: context.dashlyColors.accent, size: 18),
                  label: const Text("VIEW RIDE STATS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.dashlyColors.accent,
                    side: BorderSide(color: context.dashlyColors.accent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
