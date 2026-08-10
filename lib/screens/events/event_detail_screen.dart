import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/event_model.dart';
import '../../providers/event_list_provider.dart';
import '../../providers/event_provider.dart';
import '../../theme/dashly_theme.dart';
import '../tracking/tracking_mode_dialog.dart';

class EventDetailScreen extends StatelessWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  Future<void> _openMaps(BuildContext context, double? lat, double? lng) async {
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Coordinates not available for this event'), backgroundColor: context.dashlyColors.error),
      );
      return;
    }
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw 'Could not launch Maps';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open Maps'), backgroundColor: context.dashlyColors.error),
        );
      }
    }
  }

  void _showJoinDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    bool isLoading = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: context.dashlyColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text("Join Event", style: TextStyle(color: context.dashlyColors.textPrimary, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Enter event token to join:", style: TextStyle(color: context.dashlyColors.textSecondary)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    style: TextStyle(color: context.dashlyColors.textPrimary),
                    decoration: DashlyTheme.inputDecoration(context, label: "Event Token", prefixIcon: Icons.vpn_key_rounded),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: Text("CANCEL", style: TextStyle(color: context.dashlyColors.textHint)),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    final token = controller.text.trim();
                    if (token.isEmpty) return;
                    
                    setState(() => isLoading = true);
                    final eventProv = dialogContext.read<EventProvider>();
                    final result = await eventProv.joinEventViaToken(token);
                    
                    if (!dialogContext.mounted) return;
                    setState(() => isLoading = false);
                    
                    if (result != null && result['success'] == true) {
                      Navigator.pop(dialogContext);
                      // Force refresh events list so it shows as joined across all screens
                      dialogContext.read<EventListProvider>().loadExploreEvents();
                      dialogContext.read<EventListProvider>().loadMyEventsForMerge();
                      dialogContext.read<EventProvider>().loadMyEvents();
                      // Show BIB number dialog
                      _showBibNumberDialog(dialogContext, result['bibNumber'] ?? 'N/A');
                    } else {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(eventProv.errorMessage ?? 'Failed to join'), backgroundColor: dialogContext.dashlyColors.error),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.dashlyColors.accent,
                    foregroundColor: Colors.black,
                  ),
                  child: isLoading 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text("JOIN", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showBibNumberDialog(BuildContext context, String bibNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: ctx.dashlyColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: ctx.dashlyColors.accent, size: 28),
              const SizedBox(width: 12),
              Text("Registered!", style: TextStyle(color: ctx.dashlyColors.textPrimary, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("You have successfully joined the event.", style: TextStyle(color: ctx.dashlyColors.textSecondary)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ctx.dashlyColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ctx.dashlyColors.divider),
                ),
                child: Column(
                  children: [
                    Text("YOUR BIB NUMBER", style: TextStyle(color: ctx.dashlyColors.accent, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text(bibNumber, style: TextStyle(color: ctx.dashlyColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 36, letterSpacing: 4)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text("Please remember your BIB number.\nYou will need it to enter the race.", textAlign: TextAlign.center, style: TextStyle(color: ctx.dashlyColors.textHint, fontSize: 12)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: ctx.dashlyColors.accent,
                foregroundColor: Colors.black,
              ),
              child: const Text("GOT IT", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventListProv = context.watch<EventListProvider>();
    final isJoined = eventListProv.isJoined(event.id);
    // Use enriched event data (with bibNumber/participantState) if available
    final enrichedEvent = eventListProv.getEventWithParticipantData(event.id) ?? event;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Hero Header
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: context.dashlyColors.cardGradient,
            ),
            child: Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                _buildBannerImage(context, event.bannerBase64),
                
                // Overlay for readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                
                Positioned(
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.dashlyColors.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.dashlyColors.accent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_alt_rounded, color: context.dashlyColors.accent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "${event.currentCount} / ${event.maxParticipants} PARTICIPANTS",
                          style: TextStyle(color: context.dashlyColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.dashlyColors.background,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getStatusText(event.status),
                          style: TextStyle(color: context.dashlyColors.accent, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12),
                        ),
                        Text(
                          "${event.dateEvent.day}/${event.dateEvent.month}/${event.dateEvent.year}",
                          style: TextStyle(color: context.dashlyColors.textHint, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      event.name,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: context.dashlyColors.textPrimary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "ABOUT THIS EVENT",
                      style: TextStyle(color: context.dashlyColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      event.description,
                      style: TextStyle(color: context.dashlyColors.textSecondary, height: 1.6, fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    
                    _buildRouteInfo(context, event),
                    
                    const SizedBox(height: 32),
                    
                    // Location Link
                    InkWell(
                      onTap: () => _openMaps(context, event.latitude, event.longitude),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, color: context.dashlyColors.accent, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Location", style: TextStyle(color: context.dashlyColors.textSecondary, fontSize: 14)),
                                  Text("Open in Google Maps", style: TextStyle(color: context.dashlyColors.accent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                ],
                              ),
                            ),
                            Icon(Icons.open_in_new_rounded, color: context.dashlyColors.accent, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 32, color: Colors.white10),
                    
                    // Show BIB number if user is joined
                    if (isJoined && enrichedEvent.bibNumber != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: context.dashlyColors.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.dashlyColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.badge_rounded, color: context.dashlyColors.accent, size: 28),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("YOUR BIB NUMBER", style: TextStyle(color: context.dashlyColors.accent, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 2)),
                                const SizedBox(height: 4),
                                Text(enrichedEvent.bibNumber!, style: TextStyle(color: context.dashlyColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 28, letterSpacing: 4)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    _buildInfoRow(context, Icons.timer_outlined, "Official Start", event.startTime != null ? "${event.startTime!.hour.toString().padLeft(2,'0')}:${event.startTime!.minute.toString().padLeft(2,'0')} WIB" : "TBD"),
                    _buildInfoRow(context, Icons.route_outlined, "Route Category", event.category == EventCategory.cycling ? "Cycling" : "Running"),
                  ],
                ),
              ),
            ),
          ),

          // Action Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: _buildActionButton(context, isJoined, enrichedEvent.status),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(EventStatus status) {
    switch (status) {
      case EventStatus.start: return "RACE IN PROGRESS";
      case EventStatus.finished: return "EVENT FINISHED";
      case EventStatus.idle: return "UPCOMING EVENT";
    }
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: context.dashlyColors.textHint, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: context.dashlyColors.textSecondary)),
          const Spacer(),
          Text(value, style: TextStyle(color: context.dashlyColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, bool isJoined, EventStatus status) {
    if (status == EventStatus.finished) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.dashlyColors.textHint),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text("DONE", style: TextStyle(color: context.dashlyColors.textHint, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16)),
      );
    }

    if (!isJoined) {
      return ElevatedButton(
        onPressed: () => _showJoinDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.dashlyColors.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text("JOIN EVENT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16)),
      );
    }

    // Already registered -> Enter Race
    return ElevatedButton(
      onPressed: () {
        showTrackingModeSelectionDialog(context, eventId: event.id, eventName: event.name);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: context.dashlyColors.accent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text("ENTER RACE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16)),
    );
  }

  Widget _buildRouteInfo(BuildContext context, Event event) {
    double totalDistanceKm = 0.0;
    if (event.totalDistanceMeters != null && event.totalDistanceMeters! > 0) {
      totalDistanceKm = event.totalDistanceMeters! / 1000.0;
    } else if (event.routeGeojson != null) {
      totalDistanceKm = _calculateGeojsonDistanceMeters(event.routeGeojson) / 1000.0;
    }

    double startElev = 0;
    double endElev = 0;
    double avgElev = 0;
    bool hasElevation = false;

    if (event.altitudeProfile != null && event.altitudeProfile!.isNotEmpty) {
      hasElevation = true;
      startElev = (event.altitudeProfile!.first['elevation'] as num).toDouble();
      endElev = (event.altitudeProfile!.last['elevation'] as num).toDouble();

      double sumElev = 0;
      for (var pt in event.altitudeProfile!) {
        sumElev += (pt['elevation'] as num).toDouble();
      }
      avgElev = sumElev / event.altitudeProfile!.length;
    } else {
      // Fallback: extract elevation from 3D coordinates in routeGeojson [lng, lat, ele]
      final elevations = _extractGeojsonElevations(event.routeGeojson);
      if (elevations.isNotEmpty) {
        hasElevation = true;
        startElev = elevations.first;
        endElev = elevations.last;
        avgElev = elevations.reduce((a, b) => a + b) / elevations.length;
      }
    }

    if (totalDistanceKm <= 0 && !hasElevation) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "ROUTE INFO",
          style: TextStyle(color: context.dashlyColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.dashlyColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.dashlyColors.divider),
          ),
          child: Column(
            children: [
              if (totalDistanceKm > 0)
                _buildRouteInfoRow(context, Icons.straighten, "Total Distance", "${totalDistanceKm.toStringAsFixed(2)} km"),
              if (totalDistanceKm > 0 && hasElevation)
                const Divider(height: 24, thickness: 1),
              if (hasElevation) ...[
                _buildRouteInfoRow(context, Icons.trending_up, "Start Elevation", "${startElev.round()} m"),
                const Divider(height: 24, thickness: 1),
                _buildRouteInfoRow(context, Icons.flag_outlined, "End Elevation", "${endElev.round()} m"),
                const Divider(height: 24, thickness: 1),
                _buildRouteInfoRow(context, Icons.bar_chart, "Avg Elevation", "${avgElev.round()} m"),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * (3.141592653589793 / 180.0);
    final dLon = (lon2 - lon1) * (3.141592653589793 / 180.0);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(lat1 * (3.141592653589793 / 180.0)) *
            cos(lat2 * (3.141592653589793 / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _calculateGeojsonDistanceMeters(Map<String, dynamic>? routeGeojson) {
    if (routeGeojson == null) return 0.0;
    List<dynamic> coords = [];
    try {
      if (routeGeojson['type'] == 'FeatureCollection' && routeGeojson['features'] != null) {
        for (var f in routeGeojson['features']) {
          final geom = f['geometry'];
          if (geom != null && geom['type'] == 'LineString' && geom['coordinates'] is List) {
            coords.addAll(geom['coordinates']);
          } else if (geom != null && geom['type'] == 'MultiLineString' && geom['coordinates'] is List) {
            for (var line in geom['coordinates']) {
              if (line is List) coords.addAll(line);
            }
          }
        }
      } else if (routeGeojson['type'] == 'LineString' && routeGeojson['coordinates'] is List) {
        coords = routeGeojson['coordinates'];
      }
    } catch (_) {}

    if (coords.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < coords.length - 1; i++) {
      final p1 = coords[i];
      final p2 = coords[i + 1];
      if (p1 is List && p2 is List && p1.length >= 2 && p2.length >= 2) {
        final lon1 = (p1[0] as num).toDouble();
        final lat1 = (p1[1] as num).toDouble();
        final lon2 = (p2[0] as num).toDouble();
        final lat2 = (p2[1] as num).toDouble();
        total += _haversineDistance(lat1, lon1, lat2, lon2);
      }
    }
    return total;
  }

  static List<double> _extractGeojsonElevations(Map<String, dynamic>? routeGeojson) {
    if (routeGeojson == null) return [];
    List<double> elevations = [];
    try {
      List<dynamic> coords = [];
      if (routeGeojson['type'] == 'FeatureCollection' && routeGeojson['features'] != null) {
        for (var f in routeGeojson['features']) {
          final geom = f['geometry'];
          if (geom != null && geom['type'] == 'LineString' && geom['coordinates'] is List) {
            coords.addAll(geom['coordinates']);
          }
        }
      } else if (routeGeojson['type'] == 'LineString' && routeGeojson['coordinates'] is List) {
        coords = routeGeojson['coordinates'];
      }

      for (var pt in coords) {
        if (pt is List && pt.length >= 3) {
          elevations.add((pt[2] as num).toDouble());
        }
      }
    } catch (_) {}
    return elevations;
  }

  Widget _buildRouteInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: context.dashlyColors.accent, size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: context.dashlyColors.textSecondary, fontSize: 14)),
        const Spacer(),
        Text(value, style: TextStyle(color: context.dashlyColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildBannerImage(BuildContext context, String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return Icon(Icons.map_rounded, color: context.dashlyColors.textHint.withOpacity(0.2), size: 120);
    }
    try {
      final cleanBase64 = base64String.split(',').last.replaceAll(RegExp(r'\s+'), '');
      final bytes = const Base64Decoder().convert(cleanBase64);
      return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } catch (e) {
      return Icon(Icons.broken_image_rounded, color: context.dashlyColors.error.withOpacity(0.5), size: 120);
    }
  }
}
